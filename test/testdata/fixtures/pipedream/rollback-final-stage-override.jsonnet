local pipedream = import '../../../../libs/pipedream.libsonnet';

// Used by symbolicator and super-big-consumers to point the rollback
// material at deploy-primary instead of the default pipeline-complete.

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  rollback: {
    material_name: 'example_repo',
    stage: 'deploy',
    elastic_profile_id: 'example',
    final_stage: 'deploy',
  },
};

local sample = {
  pipeline(region):: {
    materials: {
      example_repo: {
        git: 'git@github.com:getsentry/example.git',
        branch: 'master',
        destination: 'example',
      },
    },
    stages: [
      {
        deploy: {
          jobs: {
            deploy: {
              elastic_profile_id: 'example',
              tasks: [
                { script: './deploy.sh --region=' + region },
              ],
            },
          },
        },
      },
    ],
  },
};

pipedream.render(pipedream_config, sample.pipeline)
