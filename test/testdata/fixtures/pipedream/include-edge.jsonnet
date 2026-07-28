// The edge regions are default-excluded, so a service reaches them only by
// naming them in include_regions. This fixture opts into `edge` itself plus two
// PoP pseudo-regions, and should render a single `deploy-example-edge` pipeline
// with one job per included region -- and no jobs for the 13 PoPs left out.
local pipedream = import '../../../../libs/pipedream.libsonnet';

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  include_regions: ['edge', 'edge-pop-au', 'edge-pop-va'],
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
