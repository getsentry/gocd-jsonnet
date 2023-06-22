local gocd_tasks = import './gocd-tasks.libsonnet';

local FINAL_STAGE_NAME = 'pipeline-complete';

local pipeline_name(name) = 'deploy-' + name;

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

{
  render(pipedream_config, pipeline_fn)::
    local trigger_pipeline = pipedream_trigger_pipeline(pipedream_config);
    trigger_pipeline,
}
