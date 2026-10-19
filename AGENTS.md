# AGENTS.md

Jsonnet libraries in `libs/` that generate GoCD pipelines for getsentry services. Consumers install `libs/` with jsonnet-bundler.

## Commands

- `npm ci`: install the locked test and lint dependencies (Node.js 24.x recommended; see `package.json` for supported versions).
- `make`: format with `jsonnetfmt`, lint with `jsonnet-lint`, and run the Vitest tests. Needs go-jsonnet on `PATH`.
- `npm run lint`: Oxlint and Oxfmt checks. CI runs it, `make` does not.
- `npm run lint:fix`: apply Oxlint fixes and Oxfmt formatting.

## Invariants

- Rendered output must match the goldens in `test/testdata/goldens/` byte for byte.
- `libs/bash/` scripts are embedded in rendered pipelines. Editing them changes the rollback goldens.
- Pipeline names (`deploy-<name>`, `deploy-<name>-<group>`, `rollback-<name>`) are the GoCD identity of every consumer's pipelines. Renaming one replaces those pipelines.

## Docs

- Library usage and `render()` configuration: [README.md](README.md)
- Tests, goldens, and testing on GoCD: [docs/testing.md](docs/testing.md)
- Releases and rollout to services: [docs/releasing.md](docs/releasing.md)
