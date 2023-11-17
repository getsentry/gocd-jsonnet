import test from "ava";
import {
  assert_testdata,
  assert_gocd_structure,
  get_fixtures,
  render_fixture,
  get_fixture_content,
} from "./utils/testdata.js";

(async () => {
  const files = await get_fixtures("pipedream");
  for (const f of files) {
    test(`render ${f} as multiple files`, async (t) => {
      await assert_testdata(t, f, true);
      await assert_gocd_structure(t, f, true);
    });

    test(`render ${f} as a single file`, async (t) => {
      await assert_testdata(t, f, false);
      await assert_gocd_structure(t, f, true);
    });
  }
})();

test("ensure manual deploys is expected structure", async (t) => {
  const got = await render_fixture("pipedream/no-autodeploy.jsonnet", false);

  t.deepEqual(Object.keys(got), ["format_version", "pipelines"]);
  t.truthy(got.pipelines["deploy-example"]);
  t.truthy(got.pipelines["deploy-example-s4s"]);
  t.truthy(got.pipelines["deploy-example-customer-5"]);

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

  // Ensure a test region depends on the trigger material
  const c5 = got.pipelines["deploy-example-customer-5"];
  t.deepEqual(c5.materials, {
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

test("ensure auto deploys is expected structure", async (t) => {
  const got = await render_fixture("pipedream/autodeploy.jsonnet", false);

  t.deepEqual(Object.keys(got), ["format_version", "pipelines"]);
  t.falsy(got.pipelines["deploy-example"]);
  t.truthy(got.pipelines["deploy-example-s4s"]);
  t.truthy(got.pipelines["deploy-example-customer-5"]);
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

  // Ensure a test region has just the repo material
  const c5 = got.pipelines["deploy-example-customer-5"];
  t.deepEqual(c5.materials, {
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
      "--pipeline=deploy-example-s4s --pipeline=deploy-example-us --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-3 --pipeline=deploy-example-customer-4",
    GOCD_ACCESS_TOKEN: "{{SECRET:[devinfra][gocd_access_token]}}",
    REGION_PIPELINE_FLAGS:
      "--pipeline=deploy-example-s4s --pipeline=deploy-example-us --pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-3 --pipeline=deploy-example-customer-4",
    ROLLBACK_MATERIAL_NAME: "example_repo",
    ROLLBACK_STAGE: "example_stage",
  });
  t.deepEqual(r["materials"], {
    "deploy-example-customer-4-pipeline-complete": {
      pipeline: "deploy-example-customer-4",
      stage: "pipeline-complete",
    },
  });
  t.deepEqual(r.stages.length, 3);
});

test("ensure exclude regions removes regions without trigger pipeline", async (t) => {
  const got = await render_fixture("pipedream/exclude-regions.jsonnet", false);

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-6",
    "rollback-example",
  ]);

  // Ensure customer-1 has just the repo material
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
    "--pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4",
  );
  t.deepEqual(
    regionPipelines,
    "--pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4",
  );
});

test("ensure exclude regions removes regions with trigger pipeline", async (t) => {
  const got = await render_fixture(
    "pipedream/exclude-regions-no-autodeploy.jsonnet",
    false,
  );

  t.deepEqual(Object.keys(got.pipelines).sort(), [
    "deploy-example",
    "deploy-example-customer-1",
    "deploy-example-customer-2",
    "deploy-example-customer-4",
    "deploy-example-customer-6",
    "rollback-example",
  ]);

  // Ensure customer-1 has just the repo material
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
    "--pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4 --pipeline=deploy-example",
  );
  t.deepEqual(
    regionPipelines,
    "--pipeline=deploy-example-customer-1 --pipeline=deploy-example-customer-2 --pipeline=deploy-example-customer-4",
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
