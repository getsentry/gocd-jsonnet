import test from 'ava';
import {assert_testdata} from './utils/testdata.js';

const files = [
  'pipedream/no-autodeploy.jsonnet',
  'pipedream/autodeploy.jsonnet',
  'pipedream/minimal-config.jsonnet',
];
for (const f of files) {
  test(`render ${f} as files`, async t => {
    await assert_testdata(t, f, true);
  });

  test(`render ${f} as single file`, async t => {
    await assert_testdata(t, f, false);
  });
}
