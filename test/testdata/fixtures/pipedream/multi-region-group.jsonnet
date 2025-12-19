local pipedream = import '../../../../libs/pipedream.libsonnet';

// Only render s4s and st to focus on multi-region groups
local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['de', 'us'],
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
