local pipedream = import '../../../../libs/pipedream.libsonnet';

// This fixture should FAIL at build time because a stage object has
// multiple keys, indicating a missing comma between stage definitions.

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
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
      // Two stages accidentally merged into one object (missing comma)
      deploy: {
        jobs: {
          deploy: {
            tasks: [{ script: './deploy.sh --region=' + region }],
          },
        },
      },
      verify: {
        jobs: {
          verify: {
            tasks: [{ script: './verify.sh --region=' + region }],
          },
        },
      },
    },
  ],
};

pipedream.render(pipedream_config, pipeline_fn)
