local pipedream = import '../../../../libs/pipedream.libsonnet';

// Exercises the pattern used by ops/gocd/templates/libs/k8s.libsonnet, where
// pipeline_fn outputs job names already containing the region (e.g.
// `'diff-' + region`) and downstream stages reference those names via fetch
// tasks. Without the dedup, transform_stage would double-suffix the names
// (e.g. `diff-customer-1-customer-1`) and break the fetch references.
local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['de', 'us'],
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
        diff: {
          jobs: {
            ['diff-' + region]: {
              elastic_profile_id: 'example',
              tasks: [
                { script: './diff.sh --region=' + region },
              ],
              artifacts: [
                { build: { source: 'result', destination: 'output' } },
              ],
            },
          },
        },
      },
      {
        apply: {
          jobs: {
            ['apply-' + region]: {
              elastic_profile_id: 'example',
              tasks: [
                {
                  fetch: {
                    stage: 'diff',
                    job: 'diff-' + region,
                    source: 'output',
                    destination: 'artifacts',
                  },
                },
                { script: './apply.sh --region=' + region },
              ],
            },
          },
        },
      },
    ],
  },
};

pipedream.render(pipedream_config, sample.pipeline)
