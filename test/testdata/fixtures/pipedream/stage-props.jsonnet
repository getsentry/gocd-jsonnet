local pipedream = import '../../../../libs/pipedream.libsonnet';

// Test that stage-level properties (approval, fetch_materials) are correctly
// preserved when aggregating jobs from multiple regions in a group.

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['de', 'us'],
};

// All regions use the same stage properties — no conflict.
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
        fetch_materials: true,
        approval: { type: 'manual' },
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
