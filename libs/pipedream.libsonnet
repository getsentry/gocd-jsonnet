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
local gocd_pipelines = import './gocd-pipelines.libsonnet';
local gocd_stages = import './gocd-stages.libsonnet';
local gocd_tasks = import './gocd-tasks.libsonnet';

local REGIONS = [
  's4s',
  'us',
  'customer-1',
  'customer-2',
  'customer-3',
  'customer-4',
];
// Test regions will deploy in parallel to the regions above
local TEST_REGIONS = [
  'customer-5',
  'customer-6',
];

local pipeline_name(name, region=null) =
  if region != null then 'deploy-' + name + '-' + region else 'deploy-' + name;

local is_autodeploy(pipedream_config) =
  !std.objectHas(pipedream_config, 'auto_deploy') || pipedream_config.auto_deploy == true;

// This function returns a "trigger pipeline", if configured for manual deploys.
// The pipeline doesn't do anything special, but it serves as a nice way to
// start the pipedream for end users.
local pipedream_trigger_pipeline(pipedream_config) =
  local name = pipedream_config.name;
  local materials = pipedream_config.materials;
  local autodeploy = is_autodeploy(pipedream_config);
  local approval_type = if autodeploy == false then
    'manual' else null;

  if autodeploy == true then
    null
  else
    {
      name: pipeline_name(name),
      pipeline: {
        group: name,
        display_order: 0,
        materials: materials,
        lock_behavior: 'unlockWhenFinished',
        stages: [
          gocd_stages.basic('pipeline-complete', [gocd_tasks.noop], { approval: approval_type }),
        ],
      },
    };

local pipedream_rollback_pipeline(pipedream_config, service_pipelines, trigger_pipeline) =
  if std.objectHas(pipedream_config, 'rollback') then
    local name = pipedream_config.name;
    local final_pipeline = service_pipelines[std.length(service_pipelines) - 1];
    local region_pipeline_flags = std.join(' ', std.map(function(p) '--pipeline=' + p.name, service_pipelines));
    local all_pipeline_flags = if trigger_pipeline == null then
      region_pipeline_flags
    else
      region_pipeline_flags + ' --pipeline=' + trigger_pipeline.name;

    local final_stage = gocd_pipelines.final_stage_name(final_pipeline);

    {
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
                    gocd_tasks.script(importstr './bash/unpause-pipelines.sh'),
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
local generate_region_pipeline(pipedream_config, region, weight, pipeline_fn) =
  // Get previous region's pipeline name
  local service_name = pipedream_config.name;

  local service_pipeline = pipeline_fn(
    region,
  );

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
    display_order: weight,
    stages: prepend_stages + stages + [
      // This stage is added to ensure a rollback doesn't cause
      // a deployment train.
      //
      // i.e. During a rollback, s4s and us re-runs the final stage
      // The s4s final stage completes and causes us pipeline to
      // re-run. Pipeline-complete being the final stage isn't
      // re-run by rollback, so this domino effect doesn't occur.
      gocd_stages.basic('pipeline-complete', [gocd_tasks.noop]),
    ],
  };

// get_service_pipelines iterates over each region and generates the pipeline
// for each region.
local get_service_pipelines(pipedream_config, pipeline_fn, regions, display_offset) =
  [
    {
      name: pipeline_name(pipedream_config.name, regions[i]),
      pipeline: generate_region_pipeline(pipedream_config, regions[i], display_offset + i, pipeline_fn),
    }
    for i in std.range(0, std.length(regions) - 1)
  ];

local pipeline_to_array(pipeline) =
  if pipeline == null then [] else [pipeline];

local add_trigger_material(should_add, trigger_pipeline) =
  if trigger_pipeline != null && should_add then {
    pipeline+: {
      materials+: {
        [trigger_pipeline.name + '-' + gocd_pipelines.final_stage_name(trigger_pipeline)]: {
          pipeline: trigger_pipeline.name,
          stage: gocd_pipelines.final_stage_name(trigger_pipeline),
        },
      },
    },
  } else {};

{
  // render will generate the trigger pipeline and all the region pipelines.
  render(pipedream_config, pipeline_fn)::
    local regions_to_render = std.filter(
      function(r) !std.objectHas(pipedream_config, 'exclude_regions') || std.length(std.find(r, pipedream_config.exclude_regions)) == 0,
      REGIONS,
    );
    local test_regions_to_render = std.filter(
      function(r) !std.objectHas(pipedream_config, 'exclude_regions') || std.length(std.find(r, pipedream_config.exclude_regions)) == 0,
      TEST_REGIONS,
    );
    local trigger_pipeline = pipedream_trigger_pipeline(pipedream_config);
    local unchained_pipelines = get_service_pipelines(pipedream_config, pipeline_fn, regions_to_render, 2);
    local service_pipelines = gocd_pipelines.chain_pipelines(unchained_pipelines);
    local test_pipelines = get_service_pipelines(pipedream_config, pipeline_fn, test_regions_to_render, std.length(regions_to_render) + 2);
    local rollback_pipeline = pipedream_rollback_pipeline(pipedream_config, service_pipelines, trigger_pipeline);


    local all_pipelines = pipeline_to_array(trigger_pipeline) +
                          pipeline_to_array(rollback_pipeline) +
                          std.mapWithIndex(function(i, v) v + add_trigger_material(i == 0, trigger_pipeline), service_pipelines) +
                          std.mapWithIndex(function(i, v) v + add_trigger_material(true, trigger_pipeline), test_pipelines);

    if std.extVar('output-files') then
      gocd_pipelines.pipelines_to_files_object(all_pipelines)
    else
      gocd_pipelines.pipelines_to_object(all_pipelines),
}
