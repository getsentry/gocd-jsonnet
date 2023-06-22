import test from 'ava';
import {assert_testdata} from '../utils/testdata.js';

const files = [
  'v1.0.0-pipedream-no-autodeploy.jsonnet',
  'v1.0.0-pipedream-autodeploy.jsonnet',
];
for (const f of files) {
  test(`render ${f}`, async t => {
    await assert_testdata(t, f);
  });
}
