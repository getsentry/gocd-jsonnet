local pipedream = import '../../../../libs/pipedream.libsonnet';

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  rollback: {
    material_name: 'example_repo',
    stage: 'example_stage',
    // NOTE: This should only be used during a transition where the final stage
    // of a pipeline is will impact rollbacks
    final_stage: 'this-stage-does-not-exist',
    elastic_profile_id: 'example_profile',
  },
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
      {
        other_stage: {},
      },
    ],
  },
};

pipedream.render(pipedream_config, sample.pipeline)
