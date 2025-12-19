local pipedream = import '../../../../libs/pipedream.libsonnet';

local config = {
  name: 'example',
  materials: {
    init_repo: {
      git: 'git@github.com:getsentry/example.git',
      branch: 'main',
    },
  },
};

// This pipeline_fn returns DIFFERENT stages depending on region
local pipeline_fn(region) = {
  materials: config.materials,
  stages: if region == 's4s' then [
    // s4s only has deploy stage
    {
      deploy: {
        jobs: {
          deploy: { tasks: [{ exec: { command: 'echo', arguments: ['deploy ' + region] } }] },
        },
      },
    },
  ] else [
    // s4s2 has deploy AND verify stages
    {
      deploy: {
        jobs: {
          deploy: { tasks: [{ exec: { command: 'echo', arguments: ['deploy ' + region] } }] },
        },
      },
    },
    {
      verify: {
        jobs: {
          verify: { tasks: [{ exec: { command: 'echo', arguments: ['verify ' + region] } }] },
        },
      },
    },
  ],
};

pipedream.render(config, pipeline_fn)
