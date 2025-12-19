# Pipedream Cellularization - Working Notes

> **Do not commit this file.** Personal working notes for the `iw/grouped-pipedream` branch.

## 1. Stage Properties: "First Region Wins" — GoCD Architectural Limit

**Finding:** GoCD's XML schema (`cruise-config.xsd`) defines `fetch_materials`, `clean_workspace`, `approval`, and `keep_artifacts` as **strictly stage-level attributes**. They do not exist on `jobType`. The YAML config plugin (`StageTransform.java`) enforces the same boundary. There is **no per-job override mechanism** for stage properties in GoCD.

**Implication:** When merging multiple regions' jobs into a single stage in grouped Pipedream, the stage can only have ONE set of properties. The current approach uses the first region's properties. This is the only option given GoCD's architecture.

**Recommendation — add validation (~10-15 lines):** When regions in the same group define conflicting stage props for the same-named stage, we should error at build time rather than silently picking the first. Estimated implementation:

```jsonnet
// Inside transform_stage, after computing stage_props from first region:
local _ = std.foldl(
  function(acc, r)
    local p = region_pipelines[r];
    local rs = get_matching_stage(p, stage_name);
    local props = if rs != null then get_stage_props(rs) else stage_props;
    assert props == stage_props :
      "Stage '%s': conflicting properties across regions in group. "
      + "Region '%s' differs from '%s'." % [stage_name, r, regions[0]];
    acc,
  regions[1:],
  true
);
```

~10 lines of code. Should be added before finalizing.

---

## 2. Environment Variable Optimization — Implemented

**Problem (before):** All env vars (pipeline + stage + job) were blindly cascaded to every job, and pipeline/stage-level `environment_variables` were stripped from the output. This caused duplication — shared vars like `GOCD_ACCESS_TOKEN` were repeated N times per stage (once per region-job).

**Solution (implemented on this branch):** Env vars that are **identical across all regions** in a group are kept at stage level. Only vars that **differ between regions** are cascaded to job level. GoCD's native precedence (job > stage > pipeline) handles resolution correctly.

**Changes made:**
- `libs/pipedream.libsonnet`: Rewrote `transform_stage` to compute `common_env` (intersection of pipeline+stage env vars across all regions) and `region_specific_env` (the diff). Common vars go to stage, region-specific to jobs.
- `test/pipedream.js`: Added test `"env var optimization: common vars at stage level, region-specific at job level"` validating the split.
- Golden files for `env-vars-precedence` regenerated.

---

## 3. Double-calling `pipeline_fn(regions[0])` — Fixed

**Problem (before):** `pipeline_fn(regions[0])` was called at the top of `generate_group_pipeline` to get a template, then called AGAIN for every region (including `regions[0]`) in the `all_stages` fold and `transform_stage`. This meant `pipeline_fn` for the first region ran 3x.

**Fix (implemented on this branch):** Added a cache:
```jsonnet
local region_pipelines = { [r]: pipeline_fn(r) for r in regions };
```
All subsequent references use `region_pipelines[region]` instead of `pipeline_fn(region)`. Also extracted `get_matching_stage` helper to reduce repeated stage-matching logic.

---

## 4. s4s/s4s2 Alignment — Resolved

**Background:** On `main`, s4s2 replaced s4s as the prod region (commit `3b7e3b1`). s4s is now a test region.

**Change made:** Updated `getsentry.libsonnet` so the `s4s` group only contains `['s4s2']` (was `['s4s', 's4s2']`). This aligns with main where s4s2 is the prod region.

**Impact on downstream compatibility (positive):**
- The `s4s` group is now single-region, so no double-suffixed job names for s4s.
- The `region_pops` crash risk for uptime-checker/relay is **eliminated for the s4s group** — `pipeline_fn('s4s2')` is already called on main today, so all services already handle it.
- Pipeline name changes: `deploy-{service}-s4s2` → `deploy-{service}-s4s`. This is still a rename that downstream tools need to handle.

**Remaining TODO:** `test_groups` is currently empty. On main, `s4s` is a test region. Consider whether to add it as a test group.

---

## 5/8. Pipeline Name + Job Name Changes — Downstream Impact

### Pipeline Name Changes

Pipeline names change from `deploy-{service}-{region}` to `deploy-{service}-{group}`:
- `deploy-example-customer-1`, `-customer-2`, `-customer-4`, `-customer-7` → `deploy-example-st`
- `deploy-example-s4s2` → `deploy-example-s4s` (s4s group name, contains only s4s2)
- Single-region groups unchanged: `deploy-example-de`, `deploy-example-us`

**Key insight after s4s2 alignment:** Most single-region groups (`de`, `us`, `control`, `snty-tools`) keep their existing pipeline names. Only two name changes actually happen:
1. `s4s2` → `s4s` (group name differs from region name)
2. `customer-{1,2,4,7}` → `st` (four pipelines collapse to one)

### Repos That Will Break

| Repo | Severity | What breaks |
|------|----------|-------------|
| **gocd-deployment-visualizer** (deploy-tools) | **Critical** | `isMultiregion()` checks for `-s4s2`/`-customer-1` suffixes. `isPipedreamPipeline()` has hardcoded allowlist of per-region names. `findPrimaryTrigger()` looks for `-s4s2`. `PIPEDREAM_SUFFIX_CUSTOMER_MAP` maps per-region suffixes to display names. `constructTree()` hardcodes `-s4s2` stripping. |
| **eng-pipes** | **Critical** | Slack feed filters have hardcoded `deploy-snuba-py-customer-{N}`, etc. `getFormattedRegion()` parses pipeline suffixes for Datadog tags — `-st` won't map to anything. |
| **sentry-feature-scoring** | **High** | Hardcoded `deploy-getsentry-backend-s4s2` in exclusion list. Deploy completeness check references `deploy-getsentry-backend-customer-7`. |
| **sentry-feature-scoring-frontend** | **High** | Constructs pipeline names via `` `deploy-getsentry-backend-${region}` `` with per-region strings. `BACKEND_REGIONS` array lists individual regions. |
| **devinfra-pause-metrics** | **Medium** | Parses region from pipeline suffix, has hardcoded region buckets. |
| **ops** | **Medium** | `dd-event.py` has `REGIONS_MAP` with `customer-*` keys. |

### Job Name Issues

**No true name collisions found**, but one remaining concern:

1. **Double-suffixed names in st group:** Services that embed region/pop in job names (e.g., uptime-checker's `deploy-canary-de`) will get `deploy-canary-de-de` after the `-{region}` append. Ugly but functionally correct. **The s4s group no longer has this issue** since it's single-region.

2. **`region_pops` crash risk reduced:** With s4s2 as the sole region in the s4s group, `pipeline_fn('s4s2')` is already the status quo on main. The crash risk only applies to the `st` group for services like uptime-checker/relay that may not have entries for all customer regions in `region_pops`. (These services likely already exclude customer regions or have them in their pops dictionaries since customers are already prod regions on main.)

### Recommendations

**Option A — Coordinated migration (recommended):**
1. Update all downstream repos to use group-aware pipeline naming BEFORE cutting v2
2. During transition, these repos should handle both old and new naming patterns
3. Create a Linear ticket per repo with specific file changes needed

**Option B — Compatibility shim:**
Add a mapping/lookup in the Pipedream library itself that exposes both the group name and the constituent region names, so downstream tools can query "which regions are in group `st`?" rather than hardcoding names.

**Option C — Keep per-region pipeline names (simplest, least disruptive):**
Instead of naming pipelines `deploy-{service}-{group}`, continue naming them `deploy-{service}-{first_region_in_group}`. So the `st` group would still be `deploy-example-customer-1` and the `s4s` group would be `deploy-example-s4s2`. This avoids ALL downstream breakage but makes the group concept less visible in naming. Not recommended long-term but could be a transitional approach.

**Option D — Name groups after first region (hybrid):**
Same as Option C but only for groups where the name differs from the first region. The `s4s` group contains `['s4s2']`, so name it `deploy-example-s4s2`. The `st` group contains `['customer-1', ...]`, so name it `deploy-example-customer-1`. Only truly custom group names (if any) get a new name. This makes the change invisible to downstream tools while still grouping jobs in parallel internally.
