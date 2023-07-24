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
local gocd_stages = import './gocd-stages.libsonnet';
local gocd_tasks = import './gocd-tasks.libsonnet';

local REGIONS = [
  's4s',
  'us',
  'customer-1',
];
local FINAL_STAGE_NAME = 'pipeline-complete';

local pipeline_name(name, region=null) =
  if region != null then 'deploy-' + name + '-' + region else 'deploy-' + name;

local is_autodeploy(pipedream_config) =
  !std.objectHas(pipedream_config, 'auto_deploy') || pipedream_config.auto_deploy == true;

// The "trigger pipeline" is a pipeline that doesn't do anything special,
// but it serves as a nice way to start the pipedream for end users.
local pipedream_trigger_pipeline(pipedream_config) =
  local name = pipedream_config.name;
  local materials = pipedream_config.materials;
  local autodeploy = is_autodeploy(pipedream_config);
  local approval_type = if autodeploy == false then
    'manual' else null;

  {
    [if autodeploy == true then null else name + '.yaml']: {
      format_version: 10,
      pipelines: {
        [pipeline_name(name)]: {
          group: name,
          display_order: 0,
          materials: materials,
          lock_behavior: 'unlockWhenFinished',
          stages: [
            gocd_stages.basic(FINAL_STAGE_NAME, [gocd_tasks.noop], { approval: approval_type }),
          ],
        },
      },
    },
  };

local pipedream_rollback_pipeline(pipedream_config) =
  if std.objectHas(pipedream_config, 'rollback') then
    local name = pipedream_config.name;
    local region_pipeline_names = std.map(function(r) pipeline_name(name, r), REGIONS);
    local region_pipeline_flags = std.join(' ', std.map(function(p) '--pipeline=' + p, region_pipeline_names));
    local all_pipeline_flags = region_pipeline_flags + ' --pipeline=' + pipeline_name(name);
    local final_pipeline = pipeline_name(name, REGIONS[std.length(REGIONS) - 1]);

    {
      ['rollback-' + name + '.yaml']: {
        format_version: 10,
        pipelines: {
          ['rollback-' + name]: {
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
              [final_pipeline + '-' + FINAL_STAGE_NAME]: {
                pipeline: final_pipeline,
                stage: FINAL_STAGE_NAME,
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
            ],
          },
        },
      },
    }
  else
    {};

// generate_pipeline will call the pipeline callback function, and then
// name the pipeline, add an upstream material, and append a final stage.
local generate_pipeline(pipedream_config, region, weight, pipeline_fn) =
  // Get previous region's pipeline name
  local service_name = pipedream_config.name;
  local index = std.find(region, REGIONS)[0];
  local upstream_pipeline = if index == 0 then
    if is_autodeploy(pipedream_config) then
      null
    else
      pipeline_name(service_name)
  else
    pipeline_name(service_name, REGIONS[index - 1]);

  local service_pipeline = {
    format_version: 10,
    pipelines: {
      [pipeline_name(service_name, region)]: pipeline_fn(
        region,
      ),
    },
  };

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
  local stages = service_pipeline.pipelines[pipeline_name(service_name, region)].stages;
  service_pipeline {
    pipelines+: {
      [pipeline_name(service_name, region)]+: {
        group: service_name,
        display_order: weight,
        materials+: {
          [if upstream_pipeline == null then null else upstream_pipeline + '-' + FINAL_STAGE_NAME]: {
            pipeline: upstream_pipeline,
            stage: FINAL_STAGE_NAME,
          },
        },
        stages: prepend_stages + stages + [
          gocd_stages.basic(FINAL_STAGE_NAME, [gocd_tasks.noop], { approval: 'success' }),
        ],
      },
    },
  };

// get_service_pipelines iterates over each region and generates the pipeline
// for each region.
local get_service_pipelines(pipedream_config, pipeline_fn) =
  {
    // The weight is i + 2 to account for the trigger pipeline and rollback pipeline
    [pipedream_config.name + '-' + REGIONS[i] + '.yaml']: generate_pipeline(pipedream_config, REGIONS[i], i + 2, pipeline_fn)
    for i in std.range(0, std.length(REGIONS) - 1)
  };

{
  // render will generate the trigger pipeline and all the region pipelines.
  render(pipedream_config, pipeline_fn)::
    local trigger_pipeline = pipedream_trigger_pipeline(pipedream_config);
    local service_pipelines = get_service_pipelines(pipedream_config, pipeline_fn);
    local rollback_pipeline = pipedream_rollback_pipeline(pipedream_config);
    trigger_pipeline + rollback_pipeline + service_pipelines,
}
