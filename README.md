# gocd-jsonnet

Jsonnet libraries used to help structure GoCD pipelines for getsentry

## Install

You'll need jsonnet-bundler to install these libraries:

```sh
jb install https://github.com/getsentry/gocd-jsonnet.git/v1.0.0@main
```

## `pipedream.libsonnet`

```jsonnet
local pipedream = import 'github.com/getsentry/gocd-jsonnet/v1.0.0/pipedream.libsonnet';

local pipedream_config = {
  # Name of your service
  name: 'example',

  # The materials you'd like the pipelines to watch for changes
  materials: {
    init_repo: {
      git: 'git@github.com:getsentry/init.git',
      shallow_clone: true,
      branch: 'master',
      destination: 'init',
    },
  },

  # Set to true to auto-deploy changes (defaults to true)
  auto_deploy: false,
  # Set to true if you want each pipeline to require manual approval
  auto_pipeline_progression: false,
};

# You'll need to define a jsonnet function that describes your pipeline
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

# Then call pipedream.render() to generate the set of pipelines for
# a getsentry "pipedream".
pipedream.render(pipedream_config, sample.pipeline)
```

## gocd-tasks

The tasks library is a simple helper to simplify common tasks:

```
local gocdtasks = import 'github.com/getsentry/gocd-jsonnet/v1.0.0/gocd-tasks.libsonnet';


local tasks = [
  # A noop task
  gocdtasks.noop,

  # A script task (i.e. { script: "echo ...." })
  gocdtasks.script("echo 'hello world'"),
  # Import a file, escape comments and output a script task
  gocdtasks.script(importstr "./bash/example.sh"),
];
```

## gocd-stages

The stages library provides helper methods to define a stage.

```
local gocdstages = import 'github.com/getsentry/gocd-jsonnet/v1.0.0/gocd-stages.libsonnet';

# A single job stage, with a noop task
gocdstages.basic('example-stage', [gocdtasks.noop])
# A single job stage, with a noop task and manual approval
gocdstages.basic('example-stage', [gocdtasks.noop], {approval: 'manual'})
# A single job stage, with a noop task and allow only on success approval
gocdstages.basic('example-stage', [gocdtasks.noop], {approval: 'success'})
```
