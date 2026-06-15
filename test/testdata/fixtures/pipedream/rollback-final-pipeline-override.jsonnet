local pipedream = import '../../../../libs/pipedream.libsonnet';

// Anchor the rollback material on the `us` group instead of the default last
// group (`st`). A SHA becomes rollback-eligible once `us` reaches its final
// stage, so a flaky tail group no longer starves the rollback target pool.

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  rollback: {
    material_name: 'example_repo',
    stage: 'deploy',
    elastic_profile_id: 'example',
    final_pipeline: 'us',
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
