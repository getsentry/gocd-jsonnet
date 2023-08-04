# gocd-jsonnet

Jsonnet libraries used to help structure GoCD pipelines for getsentry

## Install

You'll need jsonnet-bundler to install these libraries:

```sh
jb install https://github.com/getsentry/gocd-jsonnet.git/libs@v1.4.1
```

## Build

When using this library, you'll need to build with the following external
variable:

```bash
--ext-code output-files=<true|false>
```

This variable will change the output of pipedream library.

When `output-files=true` it'll output pipelines in the format:

```json
{
  "example.yaml": {
    "format_version": 10,
    "pipelines": {
      "deploy-example": {...}
    }
  },
  "example-us.yaml": {
    "format_version": 10,
    "pipelines": {
      "deploy-example-us": {...}
    }
  }
}
```

This is useful when you build using the `-m` flag in jsonnet as it'll
output multiple files which makes reviewing pipeliens easier.

```bash
jsonnet --ext-code output-files=true -m ./generated-pipelines ./example.jsonnet
```

The GoCD plugin that can process jsonnet files directly doesn't support
outputting multiple files, so GoCD is configured to have
`--ext-code output-filaes=false` which will output the pipelines in a
flattened format:

```json
{
  "format_version": 10,
  "pipelines": {
    "deploy-example": {...},
    "deploy-example-us": {...}
  }
}
```

## `pipedream.libsonnet`

This libraries main purpose is to generate a set of pipelines that constitute
a pipedream.

"pipedream" is what we're calling the overall deployment process for a service
at sentry, where that service is expected to be deployed to multiple regions.

The entry point for this library is the `render()` function which takes
some configuration and a callback function. The callback function is expected
to return a pipeline definition for a given region.

Pipedream will name the returned pipeline, add an upstream pipeline material
and a final stage. The upstream material and final stage is needed to make GoCD
chain the pipelines together.

The end result will be a pipeline `deploy-<service name>` that starts the
run of each pipeline, and a pipeline for each region.

### Example Usage

```jsonnet
local pipedream = import 'github.com/getsentry/gocd-jsonnet/libs/pipedream.libsonnet';

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

  # To add a rollback pipeline, add the rollback parameter
  rollback: {
    # The material name used in all pipelines (i.e. getsentry_repo)
    material_name: 'example_repo',
    # The deployment stage that the rollback should run
    stage: 'example_stage',
    # The elastic agent profile to run the rollback pipeline as
    elastic_profile_id: 'example_profile',
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

## `gocd-tasks.libsonnet`

The tasks library is a simple helper to simplify common tasks:

```
local gocdtasks = import 'github.com/getsentry/gocd-jsonnet/libs/gocd-tasks.libsonnet';


local tasks = [
  # A noop task
  gocdtasks.noop,

  # A script task (i.e. { script: "echo ...." })
  gocdtasks.script("echo 'hello world'"),
  # Import a file, escape comments and output a script task
  gocdtasks.script(importstr "./bash/example.sh"),
];
```

## `gocd-stages.libsonnet`

The stages library provides helper methods to define a stage.

```
local gocdstages = import 'github.com/getsentry/gocd-jsonnet/libs/gocd-stages.libsonnet';

# A single job stage, with a noop task
gocdstages.basic('example-stage', [gocdtasks.noop])
# A single job stage, with a noop task and manual approval
gocdstages.basic('example-stage', [gocdtasks.noop], {approval: 'manual'})
# A single job stage, with a noop task and allow only on success approval
gocdstages.basic('example-stage', [gocdtasks.noop], {approval: 'success'})
```

## Development

Run formatting, lint and tests using make:

```shell
make
```
