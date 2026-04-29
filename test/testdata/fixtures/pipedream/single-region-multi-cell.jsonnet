local pipedream = import '../../../../libs/pipedream.libsonnet';

// Exercises the pattern used by ops/gocd/templates/pipelines/uptime-checker-k8s
// and vector-uc-k8s, where pipeline_fn is called once per single-region group
// (e.g. region='de') but expands internally to multiple cells (e.g.
// 'de-west-de', 'de-west-nl'). Jobs are keyed by cell name, and downstream
// stages fetch artifacts using those cell-keyed names. Without the
// single-region skip, transform_stage would append the group region
// (e.g. 'diff-de-west-nl-de') and break the cell-keyed fetch references.
local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['us', 's4s2', 'customer-1', 'customer-2', 'customer-4', 'customer-7'],
};

local cells_for(region) = {
  de: ['de-west-de', 'de-west-nl'],
}[region];

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
            ['diff-' + cell]: {
              elastic_profile_id: 'example',
              tasks: [
                { script: './diff.sh --cell=' + cell },
              ],
              artifacts: [
                { build: { source: 'result', destination: 'output' } },
              ],
            }
            for cell in cells_for(region)
          },
        },
      },
      {
        apply: {
          jobs: {
            ['apply-' + cell]: {
              elastic_profile_id: 'example',
              tasks: [
                {
                  fetch: {
                    stage: 'diff',
                    job: 'diff-' + cell,
                    source: 'output',
                    destination: 'artifacts',
                  },
                },
                { script: './apply.sh --cell=' + cell },
              ],
            }
            for cell in cells_for(region)
          },
        },
      },
    ],
  },
};

pipedream.render(pipedream_config, sample.pipeline)
