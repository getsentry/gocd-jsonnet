local gocd_tasks = import './gocd-tasks.libsonnet';

local REGIONS = ['monitor', 'us'];
local FINAL_STAGE_NAME = 'pipeline-complete';

local pipeline_name(name, region=null) =
  local suffix = if region != null then '-' + region else '';
  'deploy-' + name + suffix;

local pipedream_trigger_pipeline(pipedream_config) =
  local name = pipedream_config.name;
  local materials = pipedream_config.materials;
  local approval = if !pipedream_config.auto_deploy then
    {
      type: 'manual',
    }
  else
    {};

  {
    [name + '.yaml']: {
      format_version: 10,
      pipelines: {
        [pipeline_name(name)]: {
          group: name,
          materials: materials,
          lock_behavior: 'unlockWhenFinished',
          stages: [
            {
              [FINAL_STAGE_NAME]: {
                approval: approval,
                jobs: {
                  start: {
                    tasks: [
                      gocd_tasks.noop,
                    ],
                  },
                },
              },
            },
          ],
        },
      },
    },
  };

local generate_pipeline(service_name, region, pipeline_fn) =
  // Get previous region's pipeline name
  local index = std.find(region, REGIONS)[0];
  local upstream_pipeline = if index == 0 then
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

  // Add the upstream pipeline material and append the final stage
  service_pipeline {
    pipelines+: {
      [pipeline_name(service_name, region)]+: {
        materials+: {
          upstream_pipeline: {
            pipeline: upstream_pipeline,
            stage: FINAL_STAGE_NAME,
          },
        },
        stages+: [
          {
            [FINAL_STAGE_NAME]: {
              approval: {
                type: 'success',
                allow_only_on_success: true,
              },
              jobs: {
                continue: {
                  tasks: [
                    gocd_tasks.noop,
                  ],
                },
              },
            },
          },
        ],
      },
    },
  };

local get_service_pipelines(name, pipeline_fn) =
  {
    [name + '-' + region + '.yaml']: generate_pipeline(name, region, pipeline_fn)
    for region in REGIONS
  };

{
  render(pipedream_config, pipeline_fn)::
    local trigger_pipeline = pipedream_trigger_pipeline(pipedream_config);
    local service_pipelines = get_service_pipelines(pipedream_config.name, pipeline_fn);
    trigger_pipeline + service_pipelines,
}
