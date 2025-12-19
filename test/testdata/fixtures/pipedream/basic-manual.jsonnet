local pipedream = import '../../../../libs/pipedream.libsonnet';

local pipedream_config = {
  name: 'example',
  auto_deploy: false,
  materials: {
    init_repo: {
      git: 'git@github.com:getsentry/init.git',
      branch: 'master',
      destination: 'init',
    },
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
