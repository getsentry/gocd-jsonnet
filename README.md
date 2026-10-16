# gocd-jsonnet

Jsonnet libraries that generate GoCD pipelines for getsentry services.

## Install

You need go-jsonnet, jsonnet-bundler, and yq to use these libraries in Sentry repos:

```sh
brew install go-jsonnet jsonnet-bundler yq
```

Install the libraries with [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler).
Replace `v3.0.10` with the latest tag from [the releases page](https://github.com/getsentry/gocd-jsonnet/releases):

```sh
jb init
jb install https://github.com/getsentry/gocd-jsonnet.git/libs@v3.0.10
```

To upgrade, change the `version` in your `jsonnetfile.json`, then run `jb update`.

## Render pipelines

`pipedream.render()` reads the external variable `output-files`, so you must pass it on every build:

```sh
--ext-code output-files=<true|false>
```

With `output-files=true`, the output has one file per pipeline:

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

Use it with the jsonnet `-m` flag to write one file per pipeline, which is easier to review:

```sh
jsonnet --ext-code output-files=true -m ./generated-pipelines ./example.jsonnet
```

The GoCD jsonnet plugin cannot write multiple files.
GoCD is configured with `--ext-code output-files=false`, which outputs all pipelines in one object:

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

A pipedream is the deployment process for a Sentry service that deploys to multiple regions.
`pipedream.render(config, pipeline_fn, parallel=false)` generates its pipelines.
`pipeline_fn(region)` returns a GoCD pipeline definition for one region.

### Generated pipelines

Regions are organized into groups in `libs/getsentry.libsonnet`.
The groups deploy in this order: `s4s2`, `de`, `us`, `control`, `snty-tools`, `st`.
`render()` generates these pipelines:

- `deploy-<name>`: a trigger pipeline with one manual-approval stage. `render()` adds it only when `auto_deploy` is `false`.
- `deploy-<name>-<group>`: one pipeline per group. Each region in the group runs as a parallel job.
- `rollback-<name>`: generated only when you set `rollback`.

`render()` skips a group when all of its regions are excluded.
Group pipelines run one after the other by default.
With `parallel=true`, every group pipeline starts from the trigger pipeline instead.

Each group pipeline ends with a `pipeline-complete` stage.
The stage stops a rollback from re-triggering the downstream pipelines.

### Configuration

| Key                         | Required | Description                                                                                                   |
| --------------------------- | -------- | ------------------------------------------------------------------------------------------------------------- |
| `name`                      | Yes      | Service name, used in every pipeline name and as the GoCD pipeline group.                                     |
| `materials`                 | No       | Materials for the trigger pipeline. Required when `auto_deploy` is `false`.                                   |
| `auto_deploy`               | No       | Defaults to `true`. Set to `false` to add the `deploy-<name>` trigger pipeline.                               |
| `auto_pipeline_progression` | No       | Defaults to `true`. Set to `false` to add `ready` and `wait` stages, so each group waits for manual approval. |
| `exclude_regions`           | No       | Regions to leave out of the pipedream.                                                                        |
| `include_regions`           | No       | Regions that are excluded by default to opt in to. `control` and `snty-tools` are excluded by default.        |
| `rollback`                  | No       | Adds the `rollback-<name>` pipeline. See [Rollback](#rollback).                                               |

### Rules for `pipeline_fn`

`render()` fails the build when the pipelines from `pipeline_fn` break these rules within a group:

- Each stage object has exactly one key. A missing comma between two stages merges them into one object.
- Pipeline attributes other than `stages` and `environment_variables` are the same for every region.
- Stage attributes other than `jobs` and `environment_variables` are the same for every region.

In groups with more than one region, `render()` appends `-<region>` to each job name.
It skips the suffix when the job name already ends with `-<region>`.

### Environment variables

You can set `environment_variables` at the pipeline, stage, or job level in `pipeline_fn`.
A variable with the same value in every region of a group stays at its original level.
`render()` moves a region-specific variable down to the job level.
GoCD resolves precedence as job, then stage, then pipeline.

### Deploy to a subset of regions

Each group pipeline has a `PIPEDREAM_GROUP_REGIONS` variable that lists the group's regions.
To deploy to a subset, override `PIPEDREAM_GROUP_REGIONS` on the Environment Variables tab of "Trigger with options" in GoCD.
For example, `deploy-example-st` defaults to `customer-1,customer-2,customer-7`:

| Override value          | Result                                |
| ----------------------- | ------------------------------------- |
| (no override)           | All three regions deploy              |
| `customer-1`            | Only customer-1 deploys               |
| `customer-1,customer-2` | Only customer-1 and customer-2 deploy |

The override works only when these conditions hold:

- The group has more than one region.
- The job's tasks are `script` tasks.
- The job sets `SENTRY_REGION` to its region. `render()` does not set `SENTRY_REGION` for you.

If the override matches none of the group's regions, every job skips and the pipeline succeeds without deploying.
Trigger the pipeline again with a valid value.

### Rollback

| Key                  | Required | Description                                                                                                     |
| -------------------- | -------- | --------------------------------------------------------------------------------------------------------------- |
| `material_name`      | Yes      | The material name that every region pipeline uses, for example `getsentry_repo`.                                |
| `stage`              | Yes      | The deploy stage that the rollback re-runs.                                                                     |
| `elastic_profile_id` | Yes      | The elastic agent profile that runs the rollback jobs.                                                          |
| `final_pipeline`     | No       | The group whose pipeline decides which revisions you can roll back to. Defaults to the last group.              |
| `final_stage`        | No       | The stage on that pipeline that the rollback material watches. Defaults to its last stage, `pipeline-complete`. |

`render()` fails the build when `stage` or `final_stage` does not exist on the final pipeline, or when `final_pipeline` names no generated group.

Set `final_stage` to an earlier stage, for example `deploy-primary`, so a revision becomes eligible before the trailing `pipeline-complete` stage runs.
Set `final_pipeline` to an earlier group, for example `us`, when a flaky last group leaves few revisions to roll back to.
A revision from an earlier group may not have deployed to the later groups that the rollback then deploys it to.

The rollback pipeline has three stages:

1. `pause_pipelines` waits for manual approval, then pauses and cancels every pipeline in the pipedream.
1. `start_rollback` deploys the chosen revision by re-running `stage` on each group pipeline.
1. `incident_resolved` waits for manual approval, then unpauses and unlocks the pipelines.

### Example

```jsonnet
local pipedream = import 'github.com/getsentry/gocd-jsonnet/libs/pipedream.libsonnet';

local pipedream_config = {
  name: 'example',
  materials: {
    init_repo: {
      git: 'git@github.com:getsentry/init.git',
      shallow_clone: true,
      branch: 'master',
      destination: 'init',
    },
  },
  rollback: {
    material_name: 'example_repo',
    stage: 'example_stage',
    elastic_profile_id: 'example_profile',
  },
  auto_deploy: false,
  auto_pipeline_progression: false,
  exclude_regions: [],
};

local sample = {
  pipeline(region):: {
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
        example_stage: {
          jobs: {
            deploy: {
              elastic_profile_id: 'example_profile',
              environment_variables: { SENTRY_REGION: region },
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
```

## `gocd-tasks.libsonnet`

```jsonnet
local gocdtasks = import 'github.com/getsentry/gocd-jsonnet/libs/gocd-tasks.libsonnet';

local tasks = [
  // A task that does nothing. GoCD requires at least one task per job.
  gocdtasks.noop,

  // A script task: { script: "echo 'hello world'" }
  gocdtasks.script("echo 'hello world'"),

  // A script task from a file
  gocdtasks.script(importstr './bash/example.sh'),
];
```

`gocdtasks.script()` doubles a `#` at the start of each line, because GoCD treats a single `#` as a parameter reference.

## `gocd-stages.libsonnet`

`gocdstages.basic(name, tasks, opts={})` returns a stage with one job.
The stage and the job both use `name`.

```jsonnet
local gocdstages = import 'github.com/getsentry/gocd-jsonnet/libs/gocd-stages.libsonnet';
local gocdtasks = import 'github.com/getsentry/gocd-jsonnet/libs/gocd-tasks.libsonnet';

[
  gocdstages.basic('example-stage', [gocdtasks.noop]),
  // Waits for manual approval
  gocdstages.basic('example-stage', [gocdtasks.noop], { approval: 'manual' }),
  // Runs only when the previous stage succeeded
  gocdstages.basic('example-stage', [gocdtasks.noop], { approval: 'success' }),
  // Skips fetching materials
  gocdstages.basic('example-stage', [gocdtasks.noop], { fetch_materials: false }),
]
```

## Contributing

See [AGENTS.md](AGENTS.md) for the build and test commands, and [docs/releasing.md](docs/releasing.md) to release a new version.
