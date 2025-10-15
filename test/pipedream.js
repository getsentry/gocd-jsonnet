import test from "ava";
import { render_fixture, get_fixture_content } from "./utils/testdata.js";

test("ensure manual deploys is expected structure in serial", async (t) => {
  const got = await render_fixture(
    "pipedream/no-autodeploy-serial.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got), ["format_version", "pipelines"]);
  t.truthy(got.pipelines["deploy-example"]);
  t.truthy(got.pipelines["deploy-example-s4s"]);

  // Ensure the trigger has the right initial material
  const trigger = got.pipelines["deploy-example"];
  t.deepEqual(trigger.materials, {
    init_repo: {
      branch: "master",
      destination: "init",
      git: "git@github.com:getsentry/init.git",
      shallow_clone: true,
    },
  });

  // Ensure s4s depends on the trigger material
  const s4s = got.pipelines["deploy-example-s4s"];
  t.deepEqual(s4s.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });
});

test("ensure manual deploys is expected structure in parallel", async (t) => {
  const got = await render_fixture(
    "pipedream/no-autodeploy-parallel.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got), ["format_version", "pipelines"]);
  t.truthy(got.pipelines["deploy-example"]);
  t.truthy(got.pipelines["deploy-example-s4s"]);

  // Ensure the trigger has the right initial material
  const trigger = got.pipelines["deploy-example"];
  t.deepEqual(trigger.materials, {
    init_repo: {
      branch: "master",
      destination: "init",
      git: "git@github.com:getsentry/init.git",
      shallow_clone: true,
    },
  });

  // Ensure s4s depends on the trigger material
  const s4s = got.pipelines["deploy-example-s4s"];
  t.deepEqual(s4s.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });
});

test("ensure auto deploys is expected structure in serial", async (t) => {
  const got = await render_fixture(
    "pipedream/autodeploy-serial.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got), ["format_version", "pipelines"]);
  t.falsy(got.pipelines["deploy-example"]);
  t.truthy(got.pipelines["deploy-example-s4s"]);
  t.truthy(got.pipelines["rollback-example"]);

  // Ensure s4s has just the repo material
  const s4s = got.pipelines["deploy-example-s4s"];
  t.deepEqual(s4s.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  const r = got.pipelines["rollback-example"];
  t.deepEqual(r["environment_variables"], {
    ALL_PIPELINE_FLAGS:
      "--pipeline=deploy-example-s4s --pipeline=deploy-example-de --pipeline=deploy-example-us --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
    GOCD_ACCESS_TOKEN: "{{SECRET:[devinfra][gocd_access_token]}}",
    REGION_PIPELINE_FLAGS:
      "--pipeline=deploy-example-s4s --pipeline=deploy-example-de --pipeline=deploy-example-us --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
    ROLLBACK_MATERIAL_NAME: "example_repo",
    ROLLBACK_STAGE: "example_stage",
    TRIGGERED_BY: "",
  });
  t.deepEqual(r["materials"], {
    "deploy-example-customer-7-pipeline-complete": {
      pipeline: "deploy-example-customer-7",
      stage: "pipeline-complete",
    },
  });
  t.deepEqual(r.stages.length, 3);
});

test("ensure auto deploys is expected structure in parallel", async (t) => {
  const got = await render_fixture(
    "pipedream/autodeploy-parallel.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got), ["format_version", "pipelines"]);
  t.falsy(got.pipelines["deploy-example"]);
  t.truthy(got.pipelines["deploy-example-s4s"]);
  t.truthy(got.pipelines["rollback-example"]);

  // Ensure s4s has just the repo material
  const s4s = got.pipelines["deploy-example-s4s"];
  t.deepEqual(s4s.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  const r = got.pipelines["rollback-example"];
  t.deepEqual(r["environment_variables"], {
    ALL_PIPELINE_FLAGS:
      "--pipeline=deploy-example-s4s --pipeline=deploy-example-de --pipeline=deploy-example-us --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
    GOCD_ACCESS_TOKEN: "{{SECRET:[devinfra][gocd_access_token]}}",
    REGION_PIPELINE_FLAGS:
      "--pipeline=deploy-example-s4s --pipeline=deploy-example-de --pipeline=deploy-example-us --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
    ROLLBACK_MATERIAL_NAME: "example_repo",
    ROLLBACK_STAGE: "example_stage",
    TRIGGERED_BY: "",
  });
  t.deepEqual(r["materials"], {
    "deploy-example-customer-7-pipeline-complete": {
      pipeline: "deploy-example-customer-7",
      stage: "pipeline-complete",
    },
  });
  t.deepEqual(r.stages.length, 3);
});

test("ensure exclude regions removes regions without trigger pipeline in serial", async (t) => {
  const got = await render_fixture(
    "pipedream/exclude-regions-autodeploy-serial.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-7",
    "deploy-example-de",
    "deploy-example-s4s2",
    "rollback-example",
  ]);

  // Ensure de has just the repo material
  const de = got.pipelines["deploy-example-de"];
  t.deepEqual(de.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-2 has pipeline material too
  const c2 = got.pipelines["deploy-example-customer-2"];
  t.deepEqual(c2.materials, {
    "deploy-example-customer-1-pipeline-complete": {
      pipeline: "deploy-example-customer-1",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure rollback has the expected rollback pipelines
  const r = got.pipelines["rollback-example"];
  const allPipelines = r.environment_variables["ALL_PIPELINE_FLAGS"];
  const regionPipelines = r.environment_variables["REGION_PIPELINE_FLAGS"];
  t.deepEqual(
    allPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
  t.deepEqual(
    regionPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
});

test("ensure exclude regions removes regions without trigger pipeline in parallel", async (t) => {
  const got = await render_fixture(
    "pipedream/exclude-regions-autodeploy-parallel.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-7",
    "deploy-example-de",
    "deploy-example-s4s2",
    "rollback-example",
  ]);

  // Ensure de has just the repo material
  const de = got.pipelines["deploy-example-de"];
  t.deepEqual(de.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-2 has pipeline material too
  const c2 = got.pipelines["deploy-example-customer-2"];
  t.deepEqual(c2.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure rollback has the expected rollback pipelines
  const r = got.pipelines["rollback-example"];
  const allPipelines = r.environment_variables["ALL_PIPELINE_FLAGS"];
  const regionPipelines = r.environment_variables["REGION_PIPELINE_FLAGS"];
  t.deepEqual(
    allPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
  t.deepEqual(
    regionPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
});

test("ensure exclude regions removes regions with trigger pipeline in serial", async (t) => {
  const got = await render_fixture(
    "pipedream/exclude-regions-no-autodeploy-serial.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example",
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-7",
    "deploy-example-de",
    "deploy-example-s4s2",
    "rollback-example",
  ]);

  // Ensure de has just the repo material
  const de = got.pipelines["deploy-example-de"];
  t.deepEqual(de.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-2 has pipeline material too
  const c2 = got.pipelines["deploy-example-customer-2"];
  t.deepEqual(c2.materials, {
    "deploy-example-customer-1-pipeline-complete": {
      pipeline: "deploy-example-customer-1",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure rollback has the expected rollback pipelines
  const r = got.pipelines["rollback-example"];
  const allPipelines = r.environment_variables["ALL_PIPELINE_FLAGS"];
  const regionPipelines = r.environment_variables["REGION_PIPELINE_FLAGS"];
  t.deepEqual(
    allPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7 --pipeline=deploy-example",
  );
  t.deepEqual(
    regionPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
});

test("ensure exclude regions removes regions with trigger pipeline in parallel", async (t) => {
  const got = await render_fixture(
    "pipedream/exclude-regions-no-autodeploy-parallel.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example",
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-7",
    "deploy-example-de",
    "deploy-example-s4s2",
    "rollback-example",
  ]);

  // Ensure de has just the repo material
  const de = got.pipelines["deploy-example-de"];
  t.deepEqual(de.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-2 has pipeline material too
  const c2 = got.pipelines["deploy-example-customer-2"];
  t.deepEqual(c2.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure rollback has the expected rollback pipelines
  const r = got.pipelines["rollback-example"];
  const allPipelines = r.environment_variables["ALL_PIPELINE_FLAGS"];
  const regionPipelines = r.environment_variables["REGION_PIPELINE_FLAGS"];
  t.deepEqual(
    allPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7 --pipeline=deploy-example",
  );
  t.deepEqual(
    regionPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
});

test("ensure include regions adds regions without trigger pipeline in serial", async (t) => {
  const got = await render_fixture(
    "pipedream/include-regions-autodeploy-serial.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example-control",
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-7",
    "deploy-example-de",
    "deploy-example-s4s2",
    "rollback-example",
  ]);

  // Ensure de has just the repo material
  const de = got.pipelines["deploy-example-de"];
  t.deepEqual(de.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure control is included
  const control = got.pipelines["deploy-example-control"];
  t.deepEqual(control.materials, {
    "deploy-example-de-pipeline-complete": {
      pipeline: "deploy-example-de",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-1 depends on control
  const c1 = got.pipelines["deploy-example-customer-1"];
  t.deepEqual(c1.materials, {
    "deploy-example-control-pipeline-complete": {
      pipeline: "deploy-example-control",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-2 has pipeline material too
  const c2 = got.pipelines["deploy-example-customer-2"];
  t.deepEqual(c2.materials, {
    "deploy-example-customer-1-pipeline-complete": {
      pipeline: "deploy-example-customer-1",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure rollback has the expected rollback pipelines
  const r = got.pipelines["rollback-example"];
  const allPipelines = r.environment_variables["ALL_PIPELINE_FLAGS"];
  const regionPipelines = r.environment_variables["REGION_PIPELINE_FLAGS"];
  t.deepEqual(
    allPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-control --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
  t.deepEqual(
    regionPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-control --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
});

test("ensure include regions adds regions without trigger pipeline in parallel", async (t) => {
  const got = await render_fixture(
    "pipedream/include-regions-autodeploy-parallel.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example-control",
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-7",
    "deploy-example-de",
    "deploy-example-s4s2",
    "rollback-example",
  ]);

  // Ensure de has just the repo material
  const de = got.pipelines["deploy-example-de"];
  t.deepEqual(de.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure control is included
  const control = got.pipelines["deploy-example-control"];
  t.deepEqual(control.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-1 depends on control
  const c1 = got.pipelines["deploy-example-customer-1"];
  t.deepEqual(c1.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-2 has pipeline material too
  const c2 = got.pipelines["deploy-example-customer-2"];
  t.deepEqual(c2.materials, {
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure rollback has the expected rollback pipelines
  const r = got.pipelines["rollback-example"];
  const allPipelines = r.environment_variables["ALL_PIPELINE_FLAGS"];
  const regionPipelines = r.environment_variables["REGION_PIPELINE_FLAGS"];
  t.deepEqual(
    allPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-control --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
  t.deepEqual(
    regionPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-control --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
});

test("ensure include regions adds regions with trigger pipeline in parallel", async (t) => {
  const got = await render_fixture(
    "pipedream/include-regions-no-autodeploy-parallel.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example",
    "deploy-example-control",
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-7",
    "deploy-example-de",
    "deploy-example-s4s2",
    "rollback-example",
  ]);

  // Ensure de has just the repo material
  const de = got.pipelines["deploy-example-de"];
  t.deepEqual(de.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure control is included and also depends on the trigger pipeline
  const control = got.pipelines["deploy-example-control"];
  t.deepEqual(control.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-1 depends on control
  const c1 = got.pipelines["deploy-example-customer-1"];
  t.deepEqual(c1.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-2 has pipeline material too
  const c2 = got.pipelines["deploy-example-customer-2"];
  t.deepEqual(c2.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });
});

test("ensure include regions adds regions with trigger pipeline in serial", async (t) => {
  const got = await render_fixture(
    "pipedream/include-regions-no-autodeploy-serial.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example",
    "deploy-example-control",
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-7",
    "deploy-example-de",
    "deploy-example-s4s2",
    "rollback-example",
  ]);

  // Ensure de has just the repo material
  const de = got.pipelines["deploy-example-de"];
  t.deepEqual(de.materials, {
    "deploy-example-pipeline-complete": {
      pipeline: "deploy-example",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure control is included
  const control = got.pipelines["deploy-example-control"];
  t.deepEqual(control.materials, {
    "deploy-example-de-pipeline-complete": {
      pipeline: "deploy-example-de",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-1 depends on control
  const c1 = got.pipelines["deploy-example-customer-1"];
  t.deepEqual(c1.materials, {
    "deploy-example-control-pipeline-complete": {
      pipeline: "deploy-example-control",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure customer-2 has pipeline material too
  const c2 = got.pipelines["deploy-example-customer-2"];
  t.deepEqual(c2.materials, {
    "deploy-example-customer-1-pipeline-complete": {
      pipeline: "deploy-example-customer-1",
      stage: "pipeline-complete",
    },
    example_repo: {
      branch: "master",
      destination: "example",
      git: "git@github.com:getsentry/example.git",
      shallow_clone: true,
    },
  });

  // Ensure rollback has the expected rollback pipelines
  const r = got.pipelines["rollback-example"];
  const allPipelines = r.environment_variables["ALL_PIPELINE_FLAGS"];
  const regionPipelines = r.environment_variables["REGION_PIPELINE_FLAGS"];
  t.deepEqual(
    allPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-control --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7 --pipeline=deploy-example",
  );
  t.deepEqual(
    regionPipelines,
    "--pipeline=deploy-example-de --pipeline=deploy-example-control --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example-customer-7",
  );
});

test("error for invalid final rollback stage", async (t) => {
  const err = t.throws(() =>
    get_fixture_content(
      "pipedream/rollback-bad-final-stage.failing.jsonnet",
      false,
    ),
  );
  t.truthy(
    err?.message.includes(
      "RUNTIME ERROR: Stage 'this-stage-does-not-exist' does not exist",
    ),
  );
});

test("error for invalid rollback stage", async (t) => {
  const err = t.throws(() =>
    get_fixture_content("pipedream/rollback-bad-stage.failing.jsonnet", false),
  );
  t.truthy(
    err?.message.includes(
      "RUNTIME ERROR: Stage 'this-stage-does-not-exist' does not exist",
    ),
  );
});
