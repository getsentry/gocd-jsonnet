import test from "ava";
import { render_fixture, get_fixture_content } from "./utils/testdata.js";

test("autodeploy: no trigger pipeline", async (t) => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);
  t.falsy(got.pipelines["deploy-example"]);
});

test("manual deploy: has trigger pipeline with correct materials", async (t) => {
  const got = await render_fixture("pipedream/basic-manual.jsonnet", false);
  const trigger = got.pipelines["deploy-example"];

  t.truthy(trigger);
  t.truthy(trigger.materials.init_repo);
  t.is(trigger.stages.length, 1);
});

test("generates pipeline per group in correct order", async (t) => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);

  const pipelineNames = Object.keys(got.pipelines).filter((n) =>
    n.startsWith("deploy-example-"),
  );

  // Should have de, us, st (control/snty-tools excluded by default)
  t.true(pipelineNames.includes("deploy-example-de"));
  t.true(pipelineNames.includes("deploy-example-us"));
  t.true(pipelineNames.includes("deploy-example-st"));
  t.false(pipelineNames.includes("deploy-example-control"));
});

test("multi-region group has parallel jobs for each region", async (t) => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);

  // st group has customer-1, customer-2, customer-4, customer-7
  const st = got.pipelines["deploy-example-st"];
  const stJobs = Object.keys(st.stages[0].deploy.jobs);
  t.deepEqual(stJobs.sort(), [
    "deploy-customer-1",
    "deploy-customer-2",
    "deploy-customer-4",
    "deploy-customer-7",
  ]);
});

test("single-region group has one job", async (t) => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);

  const de = got.pipelines["deploy-example-de"];
  const deJobs = Object.keys(de.stages[0].deploy.jobs);
  t.deepEqual(deJobs, ["deploy-de"]);
});

test("serial mode: pipelines chain sequentially", async (t) => {
  const got = await render_fixture("pipedream/basic-manual.jsonnet", false);

  // de depends on trigger
  const de = got.pipelines["deploy-example-de"];
  t.truthy(de.materials["deploy-example-pipeline-complete"]);

  // us depends on de
  const us = got.pipelines["deploy-example-us"];
  t.truthy(us.materials["deploy-example-de-pipeline-complete"]);
});

test("parallel mode: all pipelines depend on trigger only", async (t) => {
  const got = await render_fixture("pipedream/parallel-mode.jsonnet", false);

  const de = got.pipelines["deploy-example-de"];
  const us = got.pipelines["deploy-example-us"];

  // All depend on trigger
  t.truthy(de.materials["deploy-example-pipeline-complete"]);
  t.truthy(us.materials["deploy-example-pipeline-complete"]);

  // None depend on each other
  t.falsy(us.materials["deploy-example-de-pipeline-complete"]);
});

test("exclude region: removes job but keeps group", async (t) => {
  const got = await render_fixture("pipedream/exclude-region.jsonnet", false);

  const st = got.pipelines["deploy-example-st"];
  const jobs = Object.keys(st.stages[0].deploy.jobs);

  t.false(jobs.includes("deploy-customer-2"));
  t.true(jobs.includes("deploy-customer-1"));
  t.true(jobs.includes("deploy-customer-4"));
  t.true(jobs.includes("deploy-customer-7"));
});

test("exclude all regions in group: skips entire group", async (t) => {
  const got = await render_fixture(
    "pipedream/exclude-entire-group.jsonnet",
    false,
  );

  t.falsy(got.pipelines["deploy-example-st"]);
  t.truthy(got.pipelines["deploy-example-de"]);
});

test("include region: adds default-excluded group", async (t) => {
  const got = await render_fixture(
    "pipedream/include-default-excluded.jsonnet",
    false,
  );

  t.truthy(got.pipelines["deploy-example-control"]);
});

test("rollback pipeline structure", async (t) => {
  const got = await render_fixture("pipedream/rollback.jsonnet", false);

  const r = got.pipelines["rollback-example"];
  t.truthy(r);
  t.is(r.stages.length, 3);
  t.is(r.environment_variables.ROLLBACK_STAGE, "deploy");
  t.truthy(r.environment_variables.REGION_PIPELINE_FLAGS);
  t.truthy(r.environment_variables.ALL_PIPELINE_FLAGS);
});

test("rollback: invalid stage errors", (t) => {
  const err = t.throws(() =>
    get_fixture_content("pipedream/rollback-bad-stage.failing.jsonnet", false),
  );
  t.true(
    err.message.includes("Stage 'this-stage-does-not-exist' does not exist"),
  );
});

test("rollback: invalid final stage errors", (t) => {
  const err = t.throws(() =>
    get_fixture_content(
      "pipedream/rollback-bad-final-stage.failing.jsonnet",
      false,
    ),
  );
  t.true(
    err.message.includes("Stage 'this-stage-does-not-exist' does not exist"),
  );
});

test("conflicting stage properties across regions errors", (t) => {
  const err = t.throws(() =>
    get_fixture_content(
      "pipedream/stage-props-conflict.failing.jsonnet",
      false,
    ),
  );
  t.true(
    err.message.includes("conflicting properties across regions in group"),
  );
});

test("merged stage objects (missing comma) errors", (t) => {
  const err = t.throws(() =>
    get_fixture_content(
      "pipedream/merged-stages.failing.jsonnet",
      false,
    ),
  );
  t.true(
    err.message.includes("each stage must have exactly one key"),
  );
});

test("all pipelines end with pipeline-complete stage", async (t) => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);

  for (const [name, pipeline] of Object.entries(got.pipelines)) {
    const lastStage = pipeline.stages[pipeline.stages.length - 1];
    const lastStageName = Object.keys(lastStage)[0];
    t.is(
      lastStageName,
      "pipeline-complete",
      `${name} should end with pipeline-complete`,
    );
  }
});
