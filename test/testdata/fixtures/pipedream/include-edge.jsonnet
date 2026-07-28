// The edge regions are default-excluded, so a service reaches them only by
// naming them in include_regions.
//
// This fixture opts into all 16 and should render three chained pipelines:
// `edge` (the primary cluster, an ordinary single-region group), then
// `edge-pop-canary` holding only pop-rr, then `edge-pop` holding the remaining
// 14 as parallel jobs. The canary group deploys before the rest and gates them.
local getsentry = import '../../../../libs/getsentry.libsonnet';
local pipedream = import '../../../../libs/pipedream.libsonnet';

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  include_regions: getsentry.edge_regions,
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
        deploy: {
          jobs: {
            ['deploy-' + region]: {
              elastic_profile_id: 'example',
              tasks: [
                { script: './deploy.sh --region=' + region },
              ],
            },
          },
        },
      },
    ],
  },
};

pipedream.render(pipedream_config, sample.pipeline)
