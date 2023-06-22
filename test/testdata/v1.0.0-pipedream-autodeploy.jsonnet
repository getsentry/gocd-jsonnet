local pipedream = import '../../v1.0.0/pipedream.libsonnet';

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  materials: {
    init_repo: {
      git: 'git@github.com:getsentry/init.git',
      shallow_clone: true,
      branch: 'master',
      destination: 'init',
    },
  },
};

local sample = {
  pipeline(region, config):: {
    region: region,
    config: config,
    materials: {
      example_repo: {
        git: 'git@github.com:getsentry/example.git',
        shallow_clone: true,
        branch: 'master',
        destination: 'example',
      },
    },
    stages: [
      {
        example_stage: {},
      },
    ],
  },
};

pipedream.render(pipedream_config, sample.pipeline)
