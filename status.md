# Pipedream Cellularization — Comprehensive Status

> Updated 2026-04-09. Working directory: `/Users/mingchen/Desktop/sentry/gocd-jsonnet`
> Branch: `iw/grouped-pipedream` (6 commits ahead of main)

---

## 1. What This Project Does

Changes the Pipedream deployment model from **one GoCD pipeline per region** to **one pipeline per group**, with regions within each group running as parallel jobs.

**Before (main):** Sequential pipeline per region:
```
deploy-example-s4s2 → deploy-example-de → deploy-example-us → deploy-example-customer-1 → ... → deploy-example-customer-7
```

**After (this branch):** Sequential pipeline per group, parallel jobs within:
```
deploy-example-s4s → deploy-example-de → deploy-example-us → deploy-example-st
                                                              (customer-1, -2, -4, -7 as parallel jobs)
```

The groups are defined in `libs/getsentry.libsonnet`:
```jsonnet
{
  s4s: ['s4s2'],           // single region
  de: ['de'],              // single region
  us: ['us'],              // single region
  control: ['control'],    // default-excluded
  'snty-tools': ['snty-tools'],  // default-excluded
  st: ['customer-1', 'customer-2', 'customer-4', 'customer-7'],  // multi-region
}
```

### Pipeline Name Changes (only 2 actual renames)

| Old Name | New Name | Reason |
|----------|----------|--------|
| `deploy-{service}-s4s2` | `deploy-{service}-s4s` | Group name differs from region |
| `deploy-{service}-customer-{1,2,4,7}` (4 pipelines) | `deploy-{service}-st` (1 pipeline) | Collapsed into group |
| `deploy-{service}-de` | unchanged | Single-region group |
| `deploy-{service}-us` | unchanged | Single-region group |
| `deploy-{service}-control` | unchanged | Single-region group |
| `deploy-{service}-snty-tools` | unchanged | Single-region group |

---

## 2. Branch State

### Commits on `iw/grouped-pipedream` (6 ahead of main)

1. `0b17dc0` — ref(pipedream): Adding grouping support
2. `1f4b769` — cascade pipeline and stage level environment variables down to the job level
3. `3bdb415` — ref(pipedream): env var optimization, s4s2 alignment, and test coverage
4. `4394b71` — ref(pipedream): add build-time validation for conflicting stage properties
5. `8403a80` — ref(pipedream): add single-key stage object assertion
6. `cda941a` — update repo readme to reflect grouping (cherry-picked from 98abdde)

### Uncommitted Changes

None — all work committed.

### All 49 tests pass

47 original + 2 new (stage property conflict detection + merged stage detection).

### Stashes (all superseded — safe to drop)

- `stash@{0}` and `stash@{1}`: On `mingchen/di-1685-gocd-static-agent-blocking-for-pipeline-complete`. Older version of env var/s4s2 work — already incorporated and improved upon in commit `3bdb415`.
- `stash@{2}`: On `iw/grouped-pipedream` at older commit `17530cd`. Subset, also superseded.

---

## 3. Key Files Changed

### `libs/pipedream.libsonnet` (core — ~500 lines)
Complete rewrite of pipeline generation:
- `generate_group_pipeline()` — creates one pipeline per group, aggregates jobs from all regions
- `transform_stage()` — merges jobs from regions, optimizes env vars (common at stage, region-specific at job)
- `get_service_pipelines()` — generates pipelines for all groups
- Caches `pipeline_fn` results per region to avoid redundant calls
- `get_matching_stage()` helper for stage lookup
- **Build-time assertion:** Stage property conflict validation across regions
- **Build-time assertion:** Single-key stage object validation (catches missing commas)

### `libs/getsentry.libsonnet` (config — 27 lines)
Changed from flat `prod_regions`/`test_regions` arrays to `pipeline_groups` object with `group_order`. Added `group_names`, `test_group_names`, `get_targets(group)` accessors.

### `README.md`
Updated with grouping docs, typo fixes (cherry-picked from 98abdde).

### Test fixtures (16 fixtures)
- `basic-autodeploy.jsonnet`, `basic-manual.jsonnet` — core flows
- `multi-region-group.jsonnet` — st group with 4 regions
- `parallel-mode.jsonnet` — fan-out mode
- `exclude-region.jsonnet`, `exclude-entire-group.jsonnet` — exclusion patterns
- `include-default-excluded.jsonnet` — control/snty-tools inclusion
- `env-vars-precedence.jsonnet` — pipeline/stage/job cascading
- `different-stages-per-region.jsonnet` — conditional stages
- `stage-props.jsonnet` — consistent stage properties across regions
- `stage-props-conflict.failing.jsonnet` — conflict detection
- `merged-stages.failing.jsonnet` — single-key assertion
- `rollback.jsonnet`, `rollback-final-stage-override.jsonnet` — rollback config
- `rollback-bad-stage.failing.jsonnet`, `rollback-bad-final-stage.failing.jsonnet` — error cases

---

## 4. Remaining TODOs in gocd-jsonnet

### Done This Session
- [x] Stage property conflict validation (~18 lines in `transform_stage`)
- [x] Failing fixture + test for conflict detection
- [x] Single-key stage object assertion (~18 lines in `generate_group_pipeline`)
- [x] Failing fixture + test for merged stages
- [x] Cherry-picked README update from commit `98abdde`

### Done Previously
- [x] Group-based pipeline generation
- [x] Env var cascade optimization
- [x] s4s/s4s2 alignment
- [x] All test fixtures and golden files

### Still TODO
- [ ] **`test_groups` decision** — On main, `s4s` is a test region (in `test_regions`). Currently `test_groups` is empty. Should `s4s` be added as a test group?
- [ ] **Tag v3.0.0** — No release tag exists yet. Ready to tag once branch is merged or at Ming's discretion.
- [ ] **Push latest commits** — 3 new commits (4394b71, 8403a80, cda941a) need pushing to origin.

---

## 5. devinfra-example-service (Pilot)

### Comprehensive Pipeline — DONE

- Repo: `/Users/mingchen/Desktop/sentry/devinfra-example-service/`
- Branch: `mingchen/comprehensive-pipedream-pilot` (1 commit ahead of main)
- Commit: `a3e1d52` — ref(pipedream): comprehensive pilot pipeline exercising all features

**Features exercised:**

| Feature | How |
|---------|-----|
| Manual deploy | `auto_deploy: false` → trigger pipeline with manual approval |
| Region-conditional stages | checks (us/de), canary (us/de/control), soak-time (us only) |
| Region-conditional jobs | health-check only in us deploy-primary |
| Pipeline env var cascade | SENTRY_REGION, SENTRY_DEPLOY_ENV differ per region → cascade to jobs |
| Stage env vars | DEPLOY_TIMEOUT common across regions → stays at stage level |
| Job env vars | LABEL_SELECTOR at job level |
| Stage properties | fetch_materials: true, approval: { type: 'success' } |
| Include default-excluded | control region included via `include_regions` |
| Multi-region parallel jobs | st group: customer-1,-2,-4,-7 as parallel jobs |
| Rollback + final_stage override | Rollback watches deploy-primary instead of pipeline-complete |

**Generated pipelines (7 files):**
```
deploy-devinfra-example-service.yaml        (trigger)
deploy-devinfra-example-service-s4s.yaml    (s4s2 — deploy-primary only)
deploy-devinfra-example-service-de.yaml     (de — checks, canary, primary)
deploy-devinfra-example-service-us.yaml     (us — checks, canary, primary, soak-time + health-check)
deploy-devinfra-example-service-control.yaml (control — canary, primary)
deploy-devinfra-example-service-st.yaml     (4 parallel jobs — primary only)
rollback-devinfra-example-service.yaml      (rollback with final_stage=deploy-primary)
```

### Still TODO for pilot
- [ ] Update `jsonnetfile.json` to point at `v3.0.0` once tagged
- [ ] Run `make gocd` with official version (currently tested with locally copied vendor libs)
- [ ] Push branch and create PR
- [ ] Verify GoCD loads the config correctly

---

## 6. Downstream Impact — Full Inventory

### Version Pinning
All 71 downstream repos pin gocd-jsonnet at `v2.19.0` via `jsonnetfile.json`. Rollout = bump to `v3.0.0`.

### Downstream Tool Updates

| Repo | Severity | Status | What Needs Changing |
|------|----------|--------|---------------------|
| **gocd-deployment-visualizer** | Critical | **DONE** (branch exists) | Branch: `mingchen/di-1670-update-for-grouped-pipedream` (commit `af9b359`). Updated `isPipedreamPipeline()`, `findPrimaryTrigger()`, `PIPEDREAM_SUFFIX_CUSTOMER_MAP`, `isMultiregion()`. 6 files changed. **Needs merge to main.** |
| **eng-pipes** | Critical | **NOT STARTED** | 60+ hardcoded pipeline names in Slack feed filters (`gocdSlackFeeds/index.ts`), `getFormattedRegion()` in `deployDatadogEvents.ts` (parses region from pipeline name suffix for Datadog tags), paused pipeline reminders config, no-deploys alert config, consecutive unsuccessful alert config. **Files:** `src/config/index.ts`, `src/brain/gocd/gocdSlackFeeds/index.ts`, `src/brain/gocd/gocdDataDog/deployDatadogEvents.ts`, `src/brain/gocd/gocdNoDeploysAlert/index.ts`, `src/brain/gocd/gocdConsecutiveUnsuccessfulAlert/index.ts` |
| **sentry-feature-scoring** | High | **NOT STARTED** | Hardcoded `deploy-getsentry-backend-s4s2` in `src/consts.py:28`. `deploy-getsentry-backend-customer-7` completeness check in `src/productivity/metrics/deploy_failure_rate.py:58,131`. Deploy rate/duration queries reference `deploy-getsentry-backend-us` (unchanged, but verify). |
| **sentry-feature-scoring-frontend** | High | **NOT STARTED** | `BACKEND_REGIONS` array, pipeline name construction via template literals. |
| **devinfra-pause-metrics** | Medium | **NOT STARTED** | Region parsing from pipeline suffix, hardcoded region buckets. Repo not found locally. |
| **ops** | Medium | **NOT STARTED** | `dd-event.py` has `REGIONS_MAP` with `customer-*` keys. |

### Service Repos (71 consumers — just version bump)

**15 service repos** with their own pipedream templates:
getsentry-backend, relay-pop, relay-processing, snuba-py, snuba-rs, symbolicator, chartcuterie, taskbroker, conduit, vroom, uptime-checker, super-big-consumers, seer, seer-gpu, launchpad, objectstore, tempest, sentry-scripts

**50+ ops k8s templates** in `/Users/mingchen/Desktop/sentry/ops/gocd/templates/`

All just need `jsonnetfile.json` bumped from `v2.19.0` → `v3.0.0`.

---

## 7. Linear Project Status

**Project:** [Pipedream Cellularization](https://linear.app/getsentry/project/pipedream-cellularization-97a9f328cfeb/overview)
- **Lead:** Ming Chen
- **Team:** DevInfra (DI)
- **Target date:** 2026-04-17
- **Priority:** High
- **Initiative:** CI/CD allows gradual rollouts and easy rollbacks

**Milestones:**
1. Finalize Implementation (due Mar 6, 100%)
2. deploy-tools Updates (due Mar 27, 100%)
3. Pilot Testing (due Mar 27, 100%)
4. **Release and Rollout** (due Apr 10, 0%)
5. **Rollout Completion and Documentation** (due Apr 16, 0%)

---

## 8. Proposed Rollout Order

### Phase 0 — Finish gocd-jsonnet — NEARLY DONE
1. ~~Commit stage prop validation + tests~~ DONE
2. ~~Add single-key stage assertion~~ DONE
3. ~~Cherry-pick README update~~ DONE
4. Push 3 new commits to origin
5. Tag `v3.0.0` (after merge or at Ming's discretion)

### Phase 1 — Update downstream tools (BEFORE any service cuts over)
1. Merge gocd-deployment-visualizer branch (already done, just merge)
2. Update eng-pipes (critical — Slack feeds, Datadog tagging, pipeline filters)
3. Update sentry-feature-scoring + frontend
4. Update devinfra-pause-metrics
5. Update ops dd-event.py
6. During transition, tools should ideally handle BOTH old and new naming

### Phase 2 — Pilot with devinfra-example-service — PIPELINE READY
1. ~~Build comprehensive pipeline_fn~~ DONE (branch `mingchen/comprehensive-pipedream-pilot`)
2. Update jsonnetfile.json to v3.0.0 (once tagged)
3. Run `make gocd` with official version
4. Push and create PR
5. Verify GoCD loads config, visualizer works, eng-pipes processes events

### Phase 3 — Production services (progressive)
- **Wave 1 (low-risk):** chartcuterie, tempest, launchpad, devinfra-example-service
- **Wave 2 (medium):** conduit, vroom, uptime-checker, seer, taskbroker, objectstore
- **Wave 3 (critical):** snuba-py, snuba-rs, relay-pop, relay-processing, symbolicator
- **Wave 4 (core):** getsentry-backend, sentry-scripts, super-big-consumers
- Each wave: bump `jsonnetfile.json`, run `make gocd`, merge, verify in GoCD

### Phase 4 — Cleanup
- Remove backward-compat code from downstream tools
- Clean up orphaned per-region pipeline configs in GoCD
- Update Notion/docs
- Close Linear milestones

---

## 9. Reference: Downstream Repo Locations

| Repo | Local Path |
|------|-----------|
| gocd-jsonnet | `/Users/mingchen/Desktop/sentry/gocd-jsonnet` |
| gocd-deployment-visualizer | `/Users/mingchen/Desktop/sentry/gocd-deployment-visualizer` |
| eng-pipes | `/Users/mingchen/Desktop/sentry/eng-pipes` (helios) |
| sentry-feature-scoring | `/Users/mingchen/Desktop/sentry/sentry-feature-scoring` |
| devinfra-example-service | `/Users/mingchen/Desktop/sentry/devinfra-example-service` |
| ops | `/Users/mingchen/Desktop/sentry/ops` |
| getsentry | `/Users/mingchen/Desktop/sentry/getsentry` |
