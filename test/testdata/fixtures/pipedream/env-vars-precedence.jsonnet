local pipedream = import '../../../../libs/pipedream.libsonnet';

// Test to demonstrate environment_variables precedence: job > stage > pipeline
// Uses st group (multi-region) to show separate values per region

local pipedream_config = {
  name: 'example',
  auto_deploy: true,
  exclude_regions: ['de', 'us'],
};

local pipeline_fn(region) = {
  // Pipeline-level env vars
  environment_variables: {
    PIPELINE_VAR: 'pipeline-' + region,  // Should cascade down to becoming a job level var
    SHARED_VAR_JOB: 'from-pipeline',  // Should be overwritten by stage, then job
    SHARED_VAR_STAGE: 'from-pipeline',  // This should win
  },
  materials: {
    example_repo: {
      git: 'git@github.com:getsentry/example.git',
      branch: 'master',
    },
  },
  stages: [
    {
      deploy: {
        // Stage-level env vars
        environment_variables: {
          STAGE_VAR: 'stage-' + region,  // Should cascade down to becoming a job level var
          SHARED_VAR_JOB: 'from-stage',  // Should be overwritten by job
          SHARED_VAR_STAGE: 'from-stage',  // Should be overwritten by stage
        },
        jobs: {
          deploy: {
            // Job-level env vars - highest precedence
            environment_variables: {
              JOB_VAR: 'job-' + region,
              SHARED_VAR_JOB: 'from-job',  // This should win
            },
            tasks: [{ script: './deploy.sh --region=' + region }],
          },
        },
      },
    },
  ],
};

pipedream.render(pipedream_config, pipeline_fn)
