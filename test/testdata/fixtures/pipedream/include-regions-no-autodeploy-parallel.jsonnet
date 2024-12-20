local pipedream = import '../../../../libs/pipedream.libsonnet';

local pipedream_config = {
  name: 'example',
  auto_deploy: false,
  include_regions: ['control'],
  exclude_regions: ['s4s', 'us'],
  materials: {
    init_repo: {
      git: 'git@github.com:getsentry/init.git',
      branch: 'master',
      destination: 'init',
    },
  },
  rollback: {
    material_name: 'example_repo',
    stage: 'example_stage',
    elastic_profile_id: 'example_profile',
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

pipedream.render(pipedream_config, sample.pipeline, parallel=true)
