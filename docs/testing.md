# Testing

See [AGENTS.md](../AGENTS.md) for the commands that run the tests.

## Tooling

Use Node.js 24.12 or newer on the 24.x line, matching CI.
The other supported Node.js versions are listed in `package.json`.
Run `npm ci` to install the locked dependencies.

`npm test` runs the AVA tests and requires `jsonnet` on `PATH`.
`make` also formats and lints Jsonnet with `jsonnetfmt` and `jsonnet-lint`.

`npm run lint` runs Oxlint for JavaScript and Oxfmt for supported source,
configuration, and documentation files. `npm run lint:fix` fixes lint issues
and formatting. Oxfmt leaves Jsonnet formatting to `jsonnetfmt`, and golden
files are explicitly excluded from formatting.

## Fixtures and goldens

Each jsonnet file in `test/testdata/fixtures/<library>/` is a test case.
The test renders the fixture and compares the output with its golden file in `test/testdata/goldens/<library>/`.
`get_fixtures()` in `test/utils/testdata.js` collects the fixtures.

When a golden file does not exist, the test writes it from the current output.
To update a golden, delete it and run the tests again.
Review the new golden before you commit it.

A fixture named `*.failing.jsonnet` is expected to fail to render.
`get_fixtures()` skips these fixtures.
Write a test that expects the error, like the ones in `test/pipedream.js`.

## Test a change on GoCD

1. Create a pipedream pipeline in a dev GoCD config repo.
1. Set the gocd-jsonnet `version` in that repo's `jsonnetfile.json` to your branch name.
1. Refresh the config repo in the GoCD UI, or wait for GoCD to poll it.

GoCD picks up each push to your branch on the next refresh.

## Preview a change in a service

1. Set the gocd-jsonnet `version` in the service's `jsonnetfile.json` to your branch name.
1. Run `make gocd` in the service repo to render its pipelines locally.
1. Review the generated pipeline files.
