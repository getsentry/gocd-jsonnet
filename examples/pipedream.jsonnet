local pipedream = import 'github.com/getsentry/gocd-jsonnet/libs/pipedream.libsonnet';

local pipedream_config = {
  // Name of your service
  name: 'example',

  // The materials you'd like the pipelines to watch for changes
  materials: {
    init_repo: {
      git: 'git@github.com:getsentry/init.git',
      shallow_clone: true,
      branch: 'master',
      destination: 'init',
    },
  },

  // To add a rollback pipeline, add the rollback parameter
  rollback: {
    // The material name used in all pipelines (i.e. getsentry_repo)
    material_name: 'example_repo',
    // The deployment stage that the rollback should run
    stage: 'example_stage',
    // The elastic agent profile to run the rollback pipeline as
    elastic_profile_id: 'example_profile',
  },

  // Set to true to auto-deploy changes (defaults to true)
  auto_deploy: false,
  // Set to true if you want each pipeline to require manual approval
  auto_pipeline_progression: false,

  // If there is ever a situation where you need to remove a region from
  // a pipedream, add the region name to this array.
  exclude_regions: [],
};

// You'll need to define a jsonnet function that describes your pipeline
local sample = {
  pipeline(region):: {
    region: region,
    materials: {
      example_repo: {
        git: 'git@github.com:getsentry/example.git',
        shallow_clone: true,
        branch: 'master',
        destination: 'example',
      },
    },
    stages: [
      {
        example_stage: {},
      },
    ],
  },
};

// Then call pipedream.render() to generate the set of pipelines for
// a getsentry "pipedream".
pipedream.render(pipedream_config, sample.pipeline)
