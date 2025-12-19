# Pipedream Cellularization — Working Notes

> Do not commit this file.

## Test Coverage Audit (DI-1601 / DI-1602)

### Gap found and filled

Added `rollback-final-stage-override.jsonnet` — symbolicator and
super-big-consumers use `rollback.final_stage` to point at `deploy-primary`
instead of the default `pipeline-complete`. We had tests for invalid overrides
but not a valid one.

### Already covered by existing fixtures

- Auto-deploy vs manual deploy
- Region exclusions (partial and full group)
- Region inclusions (control; snty-tools uses same mechanism)
- Parallel mode
- No rollback config
- Pipeline/stage/job env var cascading
- Different stages per region
- Stage property conflicts across regions
- Multi-region vs single-region groups

Full use-case inventory in `PIPEDREAM_USE_CASES.md`.

---

## Env Var Cascade — Impact Assessment

We changed env var handling so that variables identical across all regions in a
group stay at stage level, while region-specific variables cascade to job level.

### Will this cause issues?

**No.** GoCD natively resolves env vars with job > stage > pipeline precedence.
Moving shared vars up to stage level is semantically identical to duplicating
them at job level — GoCD evaluates them the same way.

Checked against all 18 service templates and 50+ ops templates:

- **Every service** sets `SENTRY_REGION` at pipeline level. This differs per
  region, so it correctly cascades to job level (region-specific).
- **Shared secrets** (e.g. `GOCD_ACCESS_TOKEN`, `GITHUB_TOKEN`, `DATADOG_API_KEY`)
  are the same across all regions. These now stay at stage level instead of
  being duplicated into every job. No behavioral change.
- **seer** sets `SENTRY_REGION` at stage level (not pipeline level). With a
  single-region group this is fine — it becomes a common env var at stage level.
  In a multi-region group it would correctly cascade to job level since the
  values differ.
- **getsentry-backend** is the most env-var-heavy service (`SENTRY_REGION`,
  `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_PROJECT_ID`, etc. all at pipeline
  level). All region-specific vars will cascade to jobs; shared vars like
  `GITHUB_TOKEN` and `SKIP_CANARY_CHECKS` stay at stage level. Correct.

**One edge case to be aware of:** if a service sets the same env var key at
both pipeline and stage level with different values, the stage value wins in the
merged parent env (pipeline + stage merge). This is the same precedence as
before — no change in behavior.

---

## Stage Properties — GoCD Architectural Limit

GoCD's XML schema defines `fetch_materials`, `clean_workspace`, `approval`, and
`keep_artifacts` as strictly stage-level attributes. There is no per-job
override. When merging multiple regions' jobs into a single stage, the first
region's properties win.

**Recommendation:** Add ~10 lines of validation to error at build time if
regions in the same group define conflicting stage props for the same stage.

---

## Downstream Pipeline Name Breakage (DI-1670)

Pipeline names change from `deploy-{service}-{region}` to
`deploy-{service}-{group}`. Two actual renames:

1. `s4s2` → `s4s` (group name differs from region name)
2. `customer-{1,2,4,7}` → `st` (four pipelines collapse to one)

Single-region groups (`de`, `us`, `control`, `snty-tools`) keep existing names.

### Repos that need updates

| Repo | Severity | What breaks |
|------|----------|-------------|
| gocd-deployment-visualizer | Critical | `isMultiregion()`, `isPipedreamPipeline()`, `findPrimaryTrigger()`, `PIPEDREAM_SUFFIX_CUSTOMER_MAP`, `constructTree()` |
| eng-pipes | Critical | Slack feed filters, `getFormattedRegion()` Datadog tagging |
| sentry-feature-scoring | High | Hardcoded `deploy-getsentry-backend-s4s2` exclusion, `deploy-getsentry-backend-customer-7` completeness check |
| sentry-feature-scoring-frontend | High | `BACKEND_REGIONS` array, pipeline name construction |
| devinfra-pause-metrics | Medium | Region parsing from pipeline suffix |
| ops | Medium | `dd-event.py` `REGIONS_MAP` |

### Double-suffixed job names

Services that embed region/pop in job names (uptime-checker, relay-pop) will get
`deploy-primary-de-de` style names. Functionally correct but ugly. Only affects
the `st` group in practice since `s4s` is now single-region.

---

## s4s/s4s2 Alignment

Updated `getsentry.libsonnet` so the `s4s` group contains only `['s4s2']`,
matching main where s4s2 is the prod region (commit `3b7e3b1`).

**Remaining TODO:** `test_groups` is empty. On main, `s4s` is a test region.
Consider adding it as a test group.

---

## Pilot Testing — devinfra-example-service (DI-1607)

Bumped `devinfra-example-service` to `v3.0.0-rc.1`.
PR: https://github.com/getsentry/devinfra-example-service/pull/24

Generated pipelines verified locally (`make gocd`):

- `deploy-devinfra-example-service-s4s` — single job (`s4s2`), `SENTRY_REGION` at stage level
- `deploy-devinfra-example-service-de` — single job, chained after s4s
- `deploy-devinfra-example-service-us` — single job, chained after de
- `deploy-devinfra-example-service-st` — 4 parallel jobs (`customer-1`, `-2`, `-4`, `-7`), `SENTRY_REGION` at job level
- `rollback-devinfra-example-service` — watches st, references all 4 group pipelines
- `control`/`snty-tools` correctly excluded by default

---

## Issues Found During Pilot Review

### 1. Silent stage loss when stage objects have multiple keys

`demo.libsonnet` has a missing comma between two stage objects (lines 30–31),
causing jsonnet to merge them via implicit `+`. The resulting single object
`{first: {...}, 'deploy-primary': {...}}` is treated as one stage, and
`get_stage_name()` (which calls `std.objectFields(stage)[0]`) only sees
`deploy-primary` (alphabetical). The `first` stage silently disappears.

This is a pre-existing bug in the example service, not in gocd-jsonnet. But it
reveals a footgun: **any service with a missing comma between stages would
silently lose a stage.** Should add a build-time assertion in `transform_stage`
that each stage object has exactly one key.

### 2. Stage property conflict validation (still TODO)

`get_stage_props` takes the first region's properties and ignores the rest.
If `customer-1` defines `approval: manual` and `customer-7` defines
`approval: success` on the same stage in the `st` group, the first region wins
silently. Need ~10 lines of validation to error at build time when regions in
the same group define conflicting stage props. (Also noted in "Stage
Properties" section above.)

### 3. No `exclude_groups` config option

`exclude_regions` only operates on region names. To exclude the entire `st`
group you'd need: `exclude_regions: ['customer-1', 'customer-2', 'customer-4',
'customer-7']`. An `exclude_groups: ['st']` option would be cleaner and
wouldn't break when new regions are added to a group. Low priority but nice
to have.

---

## Code Changes on Branch

- `libs/pipedream.libsonnet`: env var optimization (common vars at stage level),
  `pipeline_fn` result caching, extracted `get_matching_stage` helper
- `libs/getsentry.libsonnet`: s4s group → `['s4s2']` only
- `test/pipedream.js`: updated s4s group assertion
- Test fixtures updated to use `st` group for multi-region tests
  (`env-vars-precedence`, `stage-props`, `different-stages-per-region`)
- Added `rollback-final-stage-override.jsonnet` fixture
- All golden files regenerated
- Pre-release `v3.0.0-rc.1` cut from `iw/grouped-pipedream` branch
