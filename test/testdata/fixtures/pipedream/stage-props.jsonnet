local pipedream = import '../../../../libs/pipedream.libsonnet';

// Test to demonstrate stage-level properties behavior
// Within a region grouping, stage properties come from the FIRST region that defines that stage

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['de', 'us', 's4s2'],
};

// This pipeline_fn returns stages with different properties per region.
// customer-1 (first in st group) defines different props than the rest.
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
