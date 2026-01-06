local pipedream = import '../../../../libs/pipedream.libsonnet';

// Test to demonstrate stage-level properties behavior
// Within a region grouping, stage properties come from the FIRST region that defines that stage

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['de', 'us', 'customer-1', 'customer-2', 'customer-4', 'customer-7'],
};

// This pipeline_fn returns stages with different properties per region
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
        // Stage-level properties that differ by region
        fetch_materials: if region == 's4s' then true else false,
        approval: if region == 's4s' then { type: 'manual' } else { type: 'success' },
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
