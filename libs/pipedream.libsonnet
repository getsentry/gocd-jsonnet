/**

This libraries main purpose is to generate a set of pipelines that constitute
a pipedream.

"pipedream" is what we're calling the overall deployment process for a service
at sentry, where that service is expected to be deployed to multiple regions.

The entry point for this library is the `render()` function which takes
some configuration and a callback function. The callback function is expected
to return a pipeline definition for a given region.

Pipedream will name the returned pipeline, add an upstream pipeline material
and a final stage. The upstream material and final stage is to make GoCD
chain the pipelines together.

*/
local getsentry = import './getsentry.libsonnet';
local gocd_pipelines = import './gocd-pipelines.libsonnet';
local gocd_stages = import './gocd-stages.libsonnet';
local gocd_tasks = import './gocd-tasks.libsonnet';

local pipeline_name(name, region=null) =
  if region != null then 'deploy-' + name + '-' + region else 'deploy-' + name;

local is_autodeploy(pipedream_config) =
  !std.objectHas(pipedream_config, 'auto_deploy') || pipedream_config.auto_deploy == true;

// This function returns a "trigger pipeline", if configured for manual deploys.
// This pipeline is used so users don't need to know what the first pipedream
// region is, instead they just look for the `deploy-<service name>` pipeline.
// For autodeploy pipedreams we don't need a trigger so null is returned.
local pipedream_trigger_pipeline(pipedream_config) =
  if is_autodeploy(pipedream_config) == true then
    null
  else
    local name = pipedream_config.name;
    local materials = pipedream_config.materials;

    {
      name: pipeline_name(name),
      pipeline: {
        group: name,
        display_order: 0,
        materials: materials,
        lock_behavior: 'unlockWhenFinished',
        stages: [
          gocd_stages.basic('pipeline-complete', [gocd_tasks.noop], { approval: 'manual' }),
        ],
      },
    };

// pipedream_rollback_pipeline creates a pipeline that will rollback a
// pipedream deployment to a previous deployment.
//
// pipedream_config:  The configuration passed into the render() function
// service_pipelines: The user facing deploys in pipedream
// trigger_pipeline:  The `deploy-<service name>` pipeline if the pipedream is
//                    a manual deploy.
local pipedream_rollback_pipeline(pipedream_config, service_pipelines, trigger_pipeline) =
  if std.objectHas(pipedream_config, 'rollback') then
    local name = pipedream_config.name;
    local final_pipeline = service_pipelines[std.length(service_pipelines) - 1];

    // Rollbacks work by calling two devinfra-deployment-infra scripts:
    //    gocd-pause-and-cancel-pipelines
    //    gocd-emergency-deploy
    // Both of these scripts tag `--pipeline=<pipeline name>` flags to determine
    // which pipelines to operate on.
    //
    // We want to pause and cancel the manual trigger pipeline, if it exists,
    // and all of the deployment pipelines. => all_pipeline_flags
    // Then we want to re-run the primary deploy stages on JUST the deployment
    // pipelines (i.e. not the manual trigger) => region_pipeline_flags
    local region_pipeline_flags = std.join(' ', std.map(function(p) '--pipeline=' + p.name, service_pipelines));
    local all_pipeline_flags = if trigger_pipeline == null then
      region_pipeline_flags
    else
      region_pipeline_flags + ' --pipeline=' + trigger_pipeline.name;

    // If we ever change the final stage in pipedream (i.e. add or remove a
    // final stage) we may want the material for the rollback pipeline to look
    // an existing stage, for example allow rollbacks to deploys with a
    // `deploy-primary` instead of `pipeline-complete` where no existing
    // deploys have a `pipeline-complete` stage.
    local final_stage = if std.objectHas(pipedream_config.rollback, 'final_stage') then
      pipedream_config.rollback.final_stage
    else
      gocd_pipelines.final_stage_name(final_pipeline);

    {
      // Check that the defined stage name exists on the final pipeline,
      // otherwise this won't be discovered as an issue until GoCD tries to
      // load the config repo.
      assert gocd_pipelines.check_stage_exists(final_pipeline, pipedream_config.rollback.stage),
      assert gocd_pipelines.check_stage_exists(final_pipeline, final_stage),

      name: 'rollback-' + name,
      pipeline: {
        group: name,
        display_order: 1,
        environment_variables: {
          GOCD_ACCESS_TOKEN: '{{SECRET:[devinfra][gocd_access_token]}}',
          ROLLBACK_MATERIAL_NAME: pipedream_config.rollback.material_name,
          ROLLBACK_STAGE: pipedream_config.rollback.stage,
          REGION_PIPELINE_FLAGS: region_pipeline_flags,
          ALL_PIPELINE_FLAGS: all_pipeline_flags,
          TRIGGERED_BY: '',
        },
        materials: {
          [final_pipeline.name + '-' + final_stage]: {
            pipeline: final_pipeline.name,
            stage: final_stage,
          },
        },
        lock_behavior: 'unlockWhenFinished',
        stages: [
          {
            pause_pipelines: {
              approval: {
                type: 'manual',
              },
              jobs: {
                rollback: {
                  elastic_profile_id: pipedream_config.rollback.elastic_profile_id,
                  tasks: [
                    gocd_tasks.script(importstr './bash/pause-pipelines.sh'),
                  ],
                },
              },
            },
          },
          {
            start_rollback: {
              jobs: {
                rollback: {
                  elastic_profile_id: pipedream_config.rollback.elastic_profile_id,
                  tasks: [
                    gocd_tasks.script(importstr './bash/rollback.sh'),
                  ],
                },
              },
            },
          },
          {
            incident_resolved: {
              approval: {
                type: 'manual',
              },
              jobs: {
                rollback: {
                  elastic_profile_id: pipedream_config.rollback.elastic_profile_id,
                  tasks: [
                    gocd_tasks.script(importstr './bash/unpause-and-unlock-pipelines.sh'),
                  ],
                },
              },
            },
          },
        ],
      },
    }
  else
    null;

// generate_region_pipeline will call the pipeline callback function, and then
// name the pipeline, add an upstream material, and append a final stage.
// pipedream_config: The configuration passed into the render() function
// pipeline_fn:      The callback function passed in to render() function.
//                   This function is from users of the library and should
//                   take in a region and return a GoCD pipeline.
// region:           The region to create pipelines for
// display_order:    The order of the pipeline in GoCD UI
local generate_region_pipeline(pipedream_config, pipeline_fn, region, display_order) =
  local service_name = pipedream_config.name;
  local service_pipeline = pipeline_fn(region);

  // `auto_pipeline_progression` was added as a utility for folks new to
  // pipedream. When this is false, each region will need manual approval
  // before doing any of the deployment stages.
  // We add ready + wait stages to improve the GoCD UI since it will start
  // the regions pipeline, show a green check and then a manual approval arrow.
  // If the first stage had manual approval, GoCD assumes the pipeline itself
  // needs manual approval and expects the user to manually trigger the
  // pipeline through the play+ icon, which isn't clear where in a pipedream
  // deployment we are waiting for a manual approval.
  local prepend_stages = if std.objectHas(pipedream_config, 'auto_pipeline_progression') && pipedream_config.auto_pipeline_progression == false then
    [
      // Ready runs when the upstream pipeline is complete, indicating that
      // the pipedream has progressed to the next stage.
      gocd_stages.basic('ready', [gocd_tasks.noop]),

      // The wait stage is used to wait for manual approval before continuing/
      // running the actual pipeline.
      gocd_stages.basic('wait', [gocd_tasks.noop], { approval: 'manual' }),
    ]
  else
    [];

  // Add the upstream pipeline material and append the final stage
  local stages = service_pipeline.stages;
  service_pipeline {
    group: service_name,
    display_order: display_order,
    stages: prepend_stages + stages + [
      // This stage is added to ensure a rollback doesn't cause
      // a deployment train.
      //
      // i.e. During a rollback, s4s and US re-runs the final stage
      // The s4s final stage completes and causes the US pipeline to
      // re-run. With `pipeline-complete` as the final stage, it isn't
      // re-run by a rollback, preventing this domino effect.
      gocd_stages.basic('pipeline-complete', [gocd_tasks.noop]),
    ],
  };

// get_service_pipelines iterates over each region and generates the pipeline
// for each region.
//
// pipedream_config: The configuration passed into the render() function
// pipeline_fn:      The callback function passed in to render() function.
//                   This function is from users of the library and should
//                   take in a region and return a GoCD pipeline.
// regions:          The regions to create pipelines for
// display_offset:   Used to offset the display order (i.e. test regions are
//                   display order => trigger + rollback + user regions length)
local get_service_pipelines(pipedream_config, pipeline_fn, regions, display_offset) =
  [
    {
      name: pipeline_name(pipedream_config.name, regions[i]),
      pipeline: generate_region_pipeline(pipedream_config, pipeline_fn, regions[i], display_offset + i),
    }
    for i in std.range(0, std.length(regions) - 1)
  ];

// This is a helper function that handles pipelines that may be null
// (i.e. pipedreams that do not have a rollback pipeline configured)
local pipeline_to_array(pipeline) =
  if pipeline == null then [] else [pipeline];

{
  // render will generate the trigger pipeline and all the region pipelines.
  render(pipedream_config, pipeline_fn, parallel=false)::
    // Regions that are excluded by default and must be explicitly included
    local default_excluded_regions = ['control', 'snty-tools'];

    local is_excluded_region = function(region, config)
      std.objectHas(config, 'exclude_regions') && std.length(std.find(region, config.exclude_regions)) > 0;

    local is_included_region = function(region, config)
      std.objectHas(config, 'include_regions') && std.length(std.find(region, config.include_regions)) > 0;

    local is_default_excluded_region = function(region)
      std.length(std.find(region, default_excluded_regions)) > 0;

    local should_include_region = function(region, config)
      !is_excluded_region(region, config) && (!is_default_excluded_region(region) || is_included_region(region, config));

    // Filter out any regions that are listed in the `exclude_regions` attribute.
    local regions_to_render = std.filter(
      function(region) should_include_region(region, pipedream_config),
      getsentry.prod_regions,
    );
    local test_regions_to_render = std.filter(
      function(region) should_include_region(region, pipedream_config),
      getsentry.test_regions,
    );

    local trigger_pipeline = pipedream_trigger_pipeline(pipedream_config);
    local service_pipelines = get_service_pipelines(pipedream_config, pipeline_fn, regions_to_render, 2);
    local test_pipelines = get_service_pipelines(pipedream_config, pipeline_fn, test_regions_to_render, std.length(regions_to_render) + 2);
    local rollback_pipeline = pipedream_rollback_pipeline(pipedream_config, service_pipelines, trigger_pipeline);

    local all_pipelines = if parallel then pipeline_to_array(rollback_pipeline) +
                                           pipeline_to_array(trigger_pipeline) +
                                           // Chain the service pipelines together with
                                           // the trigger pipeline
                                           std.map(function(p) gocd_pipelines.chain_materials(p, trigger_pipeline), service_pipelines)
                                           +
                                           // Chain each test region to the trigger pipeline
                                           std.map(function(p) gocd_pipelines.chain_materials(p, trigger_pipeline), test_pipelines)
    else pipeline_to_array(rollback_pipeline) +
         // Chain the service pipelines together with
         // the trigger pipeline
         gocd_pipelines.chain_pipelines(
           pipeline_to_array(trigger_pipeline) + service_pipelines,
         ) +
         // Chain each test region to the trigger pipeline
         std.map(function(p) gocd_pipelines.chain_materials(p, trigger_pipeline), test_pipelines);


    // If --ext-var=output-files=true we want to return:
    //     {<file name>: <pipeline>, <file name>: <pipeline>},
    // Otherwise we want to return:
    //     { pipelines: [ <pipeline>, <pipeline> ] },
    // This toggle is useful for a few reasons:
    //     1. Multiple files (output-files=true) is helpful when reviewing
    //        the pipelines locally (i.e. you can quickly look up the customer-1
    //        pipeline file).
    //     2. The jsonnet plugin for GoCD and the GitHub validation action work
    //        best with a single file containing all pipelines.
    if std.extVar('output-files') then
      gocd_pipelines.pipelines_to_files_object(all_pipelines)
    else
      gocd_pipelines.pipelines_to_object(all_pipelines),
}
