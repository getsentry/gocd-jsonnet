# AGENTS.md

Jsonnet libraries in `libs/` that generate GoCD pipelines for getsentry services. Consumers install `libs/` with jsonnet-bundler.

## Commands

- `npm install`: install the test and lint dependencies.
- `make`: format with `jsonnetfmt`, lint with `jsonnet-lint`, and run the ava tests. Needs go-jsonnet on `PATH`.
- `npm run lint`: eslint and prettier checks. CI runs it, `make` does not.

## Invariants

- Rendered output must match the goldens in `test/testdata/goldens/` byte for byte.
- `libs/bash/` scripts are embedded in rendered pipelines. Editing them changes the rollback goldens.
- Pipeline names (`deploy-<name>`, `deploy-<name>-<group>`, `rollback-<name>`) are the GoCD identity of every consumer's pipelines. Renaming one replaces those pipelines.

## Docs

- Library usage and `render()` configuration: [README.md](README.md)
- Tests, goldens, and testing on GoCD: [docs/testing.md](docs/testing.md)
- Releases and rollout to services: [docs/releasing.md](docs/releasing.md)
