local pipedream = import '../../../../libs/pipedream.libsonnet';

// Mirrors the uptime-checker-k8s / vector-uc-k8s shape: a single-region group
// whose pipeline_fn fans out to multiple cell-keyed jobs that override
// SENTRY_REGION per cell. Validates that pipedream skips both the suffix and
// the gate for single-region groups.
local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['us', 'us2', 's4s2', 'customer-1', 'customer-2', 'customer-4', 'customer-7'],
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
              environment_variables: { SENTRY_REGION: cell },
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
              environment_variables: { SENTRY_REGION: cell },
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
