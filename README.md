# gocd-jsonnet

Jsonnet libraries used to help structure GoCD pipelines for getsentry

## Dependencies

This will use homebrew to ensure you have everything you need installed.

```sh
make devenv
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

This is useful when you build using the `-m` flag in jsonnet as it'll output
multiple files which makes reviewing pipelines easier.

```bash
jsonnet \
  --ext-code output-files=true \
  -m ./generated-pipelines \
  ./example.jsonnet \
;
```

The GoCD plugin that can process jsonnet files directly doesn't support
outputting multiple files, so GoCD is configured to have
`--ext-code output-files=false` which will output the pipelines in a flattened
format:

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

This library's main purpose is to generate a set of pipelines that constitute a
pipedream.

"pipedream" is what we're calling the overall deployment process for a service
at sentry, where that service is expected to be deployed to multiple regions.

The entry point for this library is the `render()` function which takes some
configuration and a callback function. The callback function is expected to
return a pipeline definition for a given region.

Pipedream will name the returned pipeline, add an upstream pipeline material and
a final stage. The upstream material and final stage is needed to make GoCD
chain the pipelines together.

The end result will be a pipeline `deploy-<service name>` that starts the run of
each pipeline, and a pipeline for each region.

### Example Usage

See [examples/pipedream.jsonnet].

## `gocd-tasks.libsonnet`

The tasks library is a simple helper to simplify common tasks:

[examples/gocd-tasks.jsonnet]

## `gocd-stages.libsonnet`

The stages library provides helper methods to define a stage.

[examples/gocd-tasks.jsonnet]

## Development

Run formatting, lint and tests using make:

```shell
make
```

## Testing

You can run this repo's tests with:

```shell
make test
```

Most tests use fixtures and goldens to check functionality.

Adding a jsonnet file to `test/testdata/fixtures/` will result in a new test
case which will build the jsonnet file and create a "golden" in
`test/testdata/goldens/`. (See the `get_fixtures()` method and how it's used to
see how these tests are created).

You can easily update the "golden" file by deleting it and re-running the test,
it'll automatically create a golden.

Some tests have the name `*.failing.jsonnet`. These tests are intended for
jsonnet files that we expect to raise an error and will not be run
automatically - you have to manually create a test case.

If you want to test changes on GoCD, the best option is to create a pipedream
pipeline for a dev environment. You can see
[an example dev pipedream here](https://github.com/getsentry/dicd-mattgaunt-3-saas/blob/main/gocd/templates/example.jsonnet)
, notice the version in the `jsonnetfile.json` is set to a branch in in this
repo, for example
[main is used in the previous example](https://github.com/getsentry/dicd-mattgaunt-3-saas/blob/4e408f20452ab4e93864b1d24c0a0d42c023c5e4/gocd/templates/jsonnetfile.json#L11).
This makes it easy to iterate on changes on the gocd-jsonnet repo and updates
are reflected on GoCD by refreshing the config repo (either waiting for GoCD
poll or by manually refreshing in the UI).

Lastly, to see what your changes do to a services pipeline, change the version
in a services `jsonnetfile.json` to your branch name and run `make gocd`. This
should generate the pipeline yaml locally which you can then look over.

## Release Process

Creating a new release typically looks like:

1. Make the changes to the gocd-jsonnet (this repo)
1. Create a release on GitHub when ready:
   https://github.com/getsentry/gocd-jsonnet/releases

To roll out your changes:

1. Update the version in projects `jsonnetfile.json` (which is typically in
   `gocd/templates/`, see
   [example here](https://github.com/getsentry/snuba/blob/f4a99cb98a4784311fc198a14f7bcd8def961f94/gocd/templates/jsonnetfile.json#L11))
1. Run `make gocd` to update the lock file and check the generated pipelines
   (see
   [example Makefile here](https://github.com/getsentry/snuba/blob/f4a99cb98a4784311fc198a14f7bcd8def961f94/Makefile#L97))
