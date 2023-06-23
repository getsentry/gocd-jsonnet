local gocd_stages = import './gocd-stages.libsonnet';
local gocd_tasks = import './gocd-tasks.libsonnet';

local REGIONS = ['us', 'monitor'];
local FINAL_STAGE_NAME = 'pipeline-complete';

local pipeline_name(name, region=null) =
  if region != null then 'region-deploy-' + name + '-' + region else 'deploy-' + name;

local pipedream_trigger_pipeline(pipedream_config) =
  local name = pipedream_config.name;
  local materials = pipedream_config.materials;
  local approval_type = if std.objectHas(pipedream_config, 'auto_deploy') && pipedream_config.auto_deploy == false then
    'manual' else null;

  {
    [name + '.yaml']: {
      format_version: 10,
      pipelines: {
        [pipeline_name(name)]: {
          group: name,
          materials: materials,
          lock_behavior: 'unlockWhenFinished',
          stages: [
            gocd_stages.basic(FINAL_STAGE_NAME, [gocd_tasks.noop], { approval: approval_type }),
          ],
        },
      },
    },
  };

local generate_pipeline(pipedream_config, region, pipeline_fn) =
  // Get previous region's pipeline name
  local service_name = pipedream_config.name;
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
        group: service_name + '-region-deployments',
        materials+: {
          upstream_pipeline: {
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

local get_service_pipelines(pipedream_config, pipeline_fn) =
  {
    [pipedream_config.name + '-' + region + '.yaml']: generate_pipeline(pipedream_config, region, pipeline_fn)
    for region in REGIONS
  };

{
  render(pipedream_config, pipeline_fn)::
    local trigger_pipeline = pipedream_trigger_pipeline(pipedream_config);
    local service_pipelines = get_service_pipelines(pipedream_config, pipeline_fn);
    trigger_pipeline + service_pipelines,
}
