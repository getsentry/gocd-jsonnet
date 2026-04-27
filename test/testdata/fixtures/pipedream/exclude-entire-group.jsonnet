local pipedream = import '../../../../libs/pipedream.libsonnet';

// Exclude all customer regions → st group is skipped entirely
local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['customer-1', 'customer-2', 'customer-4', 'customer-7'],
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
