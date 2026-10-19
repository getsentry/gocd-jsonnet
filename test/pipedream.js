import { expect, test } from "vitest";
import { render_fixture, get_fixture_content } from "./utils/testdata.js";

test("autodeploy: no trigger pipeline", async () => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);
  expect(got.pipelines["deploy-example"]).toBeFalsy();
});

test("manual deploy: has trigger pipeline with correct materials", async () => {
  const got = await render_fixture("pipedream/basic-manual.jsonnet", false);
  const trigger = got.pipelines["deploy-example"];

  expect(trigger).toBeTruthy();
  expect(trigger.materials.init_repo).toBeTruthy();
  expect(trigger.stages.length).toBe(1);
});

test("generates pipeline per group in correct order", async () => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);

  const pipelineNames = Object.keys(got.pipelines).filter((name) =>
    name.startsWith("deploy-example-"),
  );

  // Should have s4s2, de, us, st (control/snty-tools excluded by default)
  expect(pipelineNames.includes("deploy-example-s4s2")).toBe(true);
  expect(pipelineNames.includes("deploy-example-de")).toBe(true);
  expect(pipelineNames.includes("deploy-example-us")).toBe(true);
  expect(pipelineNames.includes("deploy-example-st")).toBe(true);
  expect(pipelineNames.includes("deploy-example-control")).toBe(false);
});

test("multi-region group has parallel jobs for each region", async () => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);

  // st group has customer-1, customer-2, customer-7
  const st = got.pipelines["deploy-example-st"];
  const stJobs = Object.keys(st.stages[0].deploy.jobs);
  expect(stJobs.sort()).toStrictEqual([
    "deploy-customer-1",
    "deploy-customer-2",
    "deploy-customer-7",
  ]);
});

test("single-region group has one job", async () => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);

  const de = got.pipelines["deploy-example-de"];
  const deJobs = Object.keys(de.stages[0].deploy.jobs);
  // Single-region groups skip the auto-suffix since pipeline_fn is called
  // once and the user-emitted job names are already unique.
  expect(deJobs).toStrictEqual(["deploy"]);
});

test("serial mode: pipelines chain sequentially", async () => {
  const got = await render_fixture("pipedream/basic-manual.jsonnet", false);

  // s4s2 depends on trigger
  const s4s2 = got.pipelines["deploy-example-s4s2"];
  expect(s4s2.materials["deploy-example-pipeline-complete"]).toBeTruthy();

  // de depends on s4s2
  const de = got.pipelines["deploy-example-de"];
  expect(de.materials["deploy-example-s4s2-pipeline-complete"]).toBeTruthy();

  // us depends on de
  const us = got.pipelines["deploy-example-us"];
  expect(us.materials["deploy-example-de-pipeline-complete"]).toBeTruthy();
});

test("parallel mode: all pipelines depend on trigger only", async () => {
  const got = await render_fixture("pipedream/parallel-mode.jsonnet", false);

  const s4s2 = got.pipelines["deploy-example-s4s2"];
  const de = got.pipelines["deploy-example-de"];
  const us = got.pipelines["deploy-example-us"];

  // All depend on trigger
  expect(s4s2.materials["deploy-example-pipeline-complete"]).toBeTruthy();
  expect(de.materials["deploy-example-pipeline-complete"]).toBeTruthy();
  expect(us.materials["deploy-example-pipeline-complete"]).toBeTruthy();

  // None depend on each other
  expect(de.materials["deploy-example-s4s2-pipeline-complete"]).toBeFalsy();
  expect(us.materials["deploy-example-de-pipeline-complete"]).toBeFalsy();
});

test("exclude region: removes job but keeps group", async () => {
  const got = await render_fixture("pipedream/exclude-region.jsonnet", false);

  const st = got.pipelines["deploy-example-st"];
  const jobs = Object.keys(st.stages[0].deploy.jobs);

  expect(jobs.includes("deploy-customer-2")).toBe(false);
  expect(jobs.includes("deploy-customer-1")).toBe(true);
  expect(jobs.includes("deploy-customer-7")).toBe(true);
});

test("exclude all regions in group: skips entire group", async () => {
  const got = await render_fixture(
    "pipedream/exclude-entire-group.jsonnet",
    false,
  );

  expect(got.pipelines["deploy-example-st"]).toBeFalsy();
  expect(got.pipelines["deploy-example-de"]).toBeTruthy();
});

test("include region: adds default-excluded group", async () => {
  const got = await render_fixture(
    "pipedream/include-default-excluded.jsonnet",
    false,
  );

  expect(got.pipelines["deploy-example-control"]).toBeTruthy();
});

test("rollback pipeline structure", async () => {
  const got = await render_fixture("pipedream/rollback.jsonnet", false);

  const rollback = got.pipelines["rollback-example"];
  expect(rollback).toBeTruthy();
  expect(rollback.stages.length).toBe(3);
  expect(rollback.environment_variables.ROLLBACK_STAGE).toBe("deploy");
  expect(rollback.environment_variables.REGION_PIPELINE_FLAGS).toBeTruthy();
  expect(rollback.environment_variables.ALL_PIPELINE_FLAGS).toBeTruthy();
});

test("rollback: invalid stage errors", () => {
  expect(() =>
    get_fixture_content("pipedream/rollback-bad-stage.failing.jsonnet", false),
  ).toThrow("Stage 'this-stage-does-not-exist' does not exist");
});

test("rollback: invalid final stage errors", () => {
  expect(() =>
    get_fixture_content(
      "pipedream/rollback-bad-final-stage.failing.jsonnet",
      false,
    ),
  ).toThrow("Stage 'this-stage-does-not-exist' does not exist");
});

test("rollback: final_pipeline anchors material on an earlier group", async () => {
  const got = await render_fixture(
    "pipedream/rollback-final-pipeline-override.jsonnet",
    false,
  );

  const rollback = got.pipelines["rollback-example"];
  expect(rollback).toBeTruthy();
  // Material watches the `us` group's final stage, not the default last group.
  expect(
    rollback.materials["deploy-example-us-pipeline-complete"],
  ).toBeTruthy();
  expect(
    rollback.materials["deploy-example-us-pipeline-complete"].pipeline,
  ).toBe("deploy-example-us");
  expect(rollback.materials["deploy-example-us-pipeline-complete"].stage).toBe(
    "pipeline-complete",
  );
  // Rollback still re-runs every region pipeline.
  expect(
    rollback.environment_variables.REGION_PIPELINE_FLAGS.includes(
      "deploy-example-st",
    ),
  ).toBeTruthy();
  expect(rollback.environment_variables.ALLOW_MISSING_FLAGS).toBe(
    "--allow-missing",
  );
});

test("rollback: unknown final_pipeline errors", () => {
  expect(() =>
    get_fixture_content(
      "pipedream/rollback-bad-final-pipeline.failing.jsonnet",
      false,
    ),
  ).toThrow("not found in service pipelines");
});

test("conflicting stage properties across regions errors", () => {
  expect(() =>
    get_fixture_content(
      "pipedream/stage-props-conflict.failing.jsonnet",
      false,
    ),
  ).toThrow("conflicting stage properties across regions in group");
});

test("merged stage objects (missing comma) errors", () => {
  expect(() =>
    get_fixture_content("pipedream/merged-stages.failing.jsonnet", false),
  ).toThrow("each stage must have exactly one key");
});

test("all pipelines end with pipeline-complete stage", async () => {
  const got = await render_fixture("pipedream/basic-autodeploy.jsonnet", false);

  for (const [name, pipeline] of Object.entries(got.pipelines)) {
    const lastStage = pipeline.stages[pipeline.stages.length - 1];
    const lastStageName = Object.keys(lastStage)[0];
    expect(lastStageName, `${name} should end with pipeline-complete`).toBe(
      "pipeline-complete",
    );
  }
});
