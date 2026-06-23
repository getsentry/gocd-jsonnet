local pipedream = import '../../../../libs/pipedream.libsonnet';

// final_pipeline names a group that doesn't exist -> should error at compile
// time rather than producing a rollback pipeline with a dangling material.

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  rollback: {
    material_name: 'example_repo',
    stage: 'deploy',
    elastic_profile_id: 'example',
    final_pipeline: 'this-group-does-not-exist',
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
