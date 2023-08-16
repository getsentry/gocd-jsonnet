local pipedream = import '../../../../libs/pipedream.libsonnet';

local pipedream_config = {
  name: 'example',
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
    region: region,
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
