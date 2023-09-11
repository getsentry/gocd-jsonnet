import test from 'ava';
import {assert_testdata, assert_gocd_structure, get_fixtures, render_fixture} from './utils/testdata.js';

const files = await get_fixtures('pipedream');
for (const f of files) {
  test(`render ${f} as multiple files`, async t => {
    await assert_testdata(t, f, true);
    await assert_gocd_structure(t, f, true);
  });

  test(`render ${f} as a single file`, async t => {
    await assert_testdata(t, f, false);
    await assert_gocd_structure(t, f, true);
  });
}

test(`ensure manual deploys is expected structure`, async t => {
  const got = await render_fixture('pipedream/no-autodeploy.jsonnet', false);

  t.deepEqual(Object.keys(got), ['format_version', 'pipelines']);
  t.truthy(got.pipelines['deploy-example']);
  t.truthy(got.pipelines['deploy-example-s4s']);
  t.truthy(got.pipelines['deploy-example-customer-5']);

  // Ensure the trigger has the right initial material
  const trigger = got.pipelines['deploy-example'];
  t.deepEqual(trigger.materials, {
    init_repo: {
      branch: 'master',
      destination: 'init',
      git: 'git@github.com:getsentry/init.git',
      shallow_clone: true,
    },
  });

  // Ensure s4s depends on the trigger material
  const s4s = got.pipelines['deploy-example-s4s'];
  t.deepEqual(s4s.materials, {
    'deploy-example-pipeline-complete': {
      pipeline: 'deploy-example',
      stage: 'pipeline-complete',
    },
    'example_repo': {
      branch: 'master',
      destination: 'example',
      git: 'git@github.com:getsentry/example.git',
      shallow_clone: true,
    },
  });

  // Ensure a test region depends on the trigger material
  const c5 = got.pipelines['deploy-example-customer-5'];
  t.deepEqual(c5.materials, {
    'deploy-example-pipeline-complete': {
      pipeline: 'deploy-example',
      stage: 'pipeline-complete',
    },
    'example_repo': {
      branch: 'master',
      destination: 'example',
      git: 'git@github.com:getsentry/example.git',
      shallow_clone: true,
    },
  });
});

test(`ensure auto deploys is expected structure`, async t => {
  const got = await render_fixture('pipedream/autodeploy.jsonnet', false);

  t.deepEqual(Object.keys(got), ['format_version', 'pipelines']);
  t.falsy(got.pipelines['deploy-example']);
  t.truthy(got.pipelines['deploy-example-s4s']);
  t.truthy(got.pipelines['deploy-example-customer-5']);

  // Ensure s4s has just the repo material
  const s4s = got.pipelines['deploy-example-s4s'];
  t.deepEqual(s4s.materials, {
    'example_repo': {
      branch: 'master',
      destination: 'example',
      git: 'git@github.com:getsentry/example.git',
      shallow_clone: true,
    },
  });

  // Ensure a test region has just the repo material
  const c5 = got.pipelines['deploy-example-customer-5'];
  t.deepEqual(c5.materials, {
    'example_repo': {
      branch: 'master',
      destination: 'example',
      git: 'git@github.com:getsentry/example.git',
      shallow_clone: true,
    },
  });
});
