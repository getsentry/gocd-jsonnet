# Pipedream Use Cases Across getsentry

> Inventory of all real-world Pipedream usage, for validating test coverage.

## Service Repos (15 repos, 18 templates)

| Service | auto_deploy | exclude_regions | include_regions | parallel | rollback | rollback.final_stage |
|---------|-------------|-----------------|-----------------|----------|----------|----------------------|
| getsentry-backend | true (default) | `[]` | `['control']` | no | yes | no |
| relay-pop | false | `['de','us','s4s2','customer-1/2/4']` | — | no | yes | no |
| relay-processing | false | — | — | no | yes | no |
| snuba-py | true | — | — | no | yes | no |
| snuba-rs | true | — | — | no | yes | no |
| symbolicator | false | — | — | no | yes | **yes** (`deploy-primary`) |
| chartcuterie | true | `['customer-6']` | — | no | yes | no |
| taskbroker | true | — | — | no | yes | no |
| conduit | true | `['us','de','customer-1/2/4/7']` | — | no | yes | no |
| vroom | true (default) | — | — | no | yes | no |
| uptime-checker | true | `['customer-1/2/3/4/6/7']` | — | no | yes | no |
| super-big-consumers | false | — | — | no | yes | **yes** (`deploy-primary`) |
| seer | true | `['customer-3/6']` | — | no | yes | no |
| seer-gpu | true | `['customer-3/6']` | — | no | yes | no |
| launchpad | true | `['customer-1/2/3/4/7']` | — | no | yes | no |
| objectstore | false | `['customer-1/2/4/7']` | — | no | yes | no |
| tempest | true (default) | `['customer-1/2/3/4/6/7']` | — | no | yes | no |
| sentry-scripts | true | — | `['snty-tools']` | **yes** | **no** | — |

## Ops K8s Templates (50+ templates)

- 8 with custom pipeline_fn (getsentry-k8s, relay-k8s, snuba-k8s, relay-pop-k8s, symbolicator-k8s, taskbroker-k8s, uptime-checker-k8s, sbc-k8s)
- 41+ using shared `gocd.pipedream_config()` helper
- All ops templates use `auto_deploy: false`
- objectstore-k8s uses `parallel=true`
- workflow-engine-k8s and script-runner-k8s use `include_regions: ['snty-tools']`

## Pipeline Function Patterns

### Pattern 1: Pipeline-level `environment_variables` (ALL services)
Every service sets at minimum `SENTRY_REGION` at pipeline level. Many also set `GITHUB_TOKEN`, `GOCD_ACCESS_TOKEN`, `SKIP_CANARY_CHECKS`, `SENTRY_ORG`, `SENTRY_PROJECT`, Datadog keys.

**Test coverage:** `env-vars-precedence.jsonnet` covers pipeline/stage/job env vars.

### Pattern 2: Region-conditional stages (common)
- Canary stages only for US/DE (snuba, symbolicator, chartcuterie, taskbroker, vroom, relay, getsentry-backend)
- ST-specific migration stage (snuba-py: `st_migrate`)
- Soak time only for S4S and US (relay, getsentry-backend, objectstore)

**Test coverage:** `different-stages-per-region.jsonnet` covers different stage sets per region.

### Pattern 3: `getsentry.is_st(region)` conditional (3 repos)
Used by snuba-py, snuba-rs, and symbolicator to choose deploy scripts, migration logic, and approval types.

**Test coverage:** Not a pipedream concern — this runs inside `pipeline_fn`. Pipedream just calls `pipeline_fn(region)` and handles whatever comes back.

### Pattern 4: `region_pops` per-pop jobs (2 repos)
relay-pop and uptime-checker define jobs per sub-PoP using comprehensions like `['deploy-primary-' + pop]: ...`. These generate job names that already contain region identifiers.

**Test coverage:** Not a pipedream concern at the library level. However, the `-{region}` suffix appended by grouping will create double-suffixed names (e.g. `deploy-primary-de-de`). Documented as a known issue.

### Pattern 5: Multiple stages per pipeline (most services)
Real services typically have 2-4 stages: `checks`, `deploy-canary`, `deploy-primary`, `soak-time`. Some have `migrations`, `health_check`, `scale-down-canary`.

**Test coverage:** Most fixtures use a single `deploy` stage. `different-stages-per-region.jsonnet` uses deploy + verify. Adequate — pipedream doesn't treat stages differently based on count.

### Pattern 6: `rollback.final_stage` override (2 repos)
symbolicator and super-big-consumers override `final_stage` to `deploy-primary` instead of the default `pipeline-complete`.

**Test coverage:** **GAP** — we test invalid `final_stage` (failing fixtures) but not a valid override. Added `rollback-final-stage-override.jsonnet`.

### Pattern 7: No rollback config (1 repo)
sentry-scripts has no rollback.

**Test coverage:** Covered — `basic-autodeploy.jsonnet` has no rollback config.

### Pattern 8: `include_regions` for `snty-tools` (3 repos)
sentry-scripts, ops/workflow-engine-k8s, ops/script-runner-k8s.

**Test coverage:** `include-default-excluded.jsonnet` tests `include_regions: ['control']`. snty-tools uses the same mechanism. Covered.

### Pattern 9: Heavy `exclude_regions` narrowing to few groups (common)
conduit excludes `['us','de','customer-1/2/4/7']` leaving only s4s. relay-pop excludes everything except s4s and customer-7.

**Test coverage:** `exclude-region.jsonnet` (partial exclude) and `exclude-entire-group.jsonnet` (full group excluded). Covered.

## Coverage Gap Summary

| Gap | Severity | Action |
|-----|----------|--------|
| Valid `rollback.final_stage` override | Medium | Add `rollback-final-stage-override.jsonnet` fixture |
| Stage-level env vars (no job env vars) | Low | seer sets `SENTRY_REGION` at stage level only. Implicitly covered by env-vars-precedence but could add explicit fixture. |
| `auto_pipeline_progression: false` | Low | Exists in code but NOT used by any real service. Skip for now. |
