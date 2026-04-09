local pipedream = import '../../../../libs/pipedream.libsonnet';

// This fixture should FAIL at build time because regions in the st group
// define conflicting stage properties (different approval types).

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['de', 'us'],
};

local pipeline_fn(region) = {
  materials: {
    example_repo: {
      git: 'git@github.com:getsentry/example.git',
      branch: 'master',
    },
  },
  stages: [
    {
      deploy: {
        fetch_materials: if region == 'customer-1' then true else false,
        approval: if region == 'customer-1' then { type: 'manual' } else { type: 'success' },
        jobs: {
          deploy: {
            tasks: [{ script: './deploy.sh --region=' + region }],
          },
        },
      },
    },
  ],
};

pipedream.render(pipedream_config, pipeline_fn)
