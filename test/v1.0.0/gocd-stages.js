import test from 'ava';
import {assert_testdata} from '../utils/testdata.js';

const files = [
  'v1.0.0/gocd-stages/basic-no-opts.jsonnet',
  'v1.0.0/gocd-stages/basic-manual-approval.jsonnet',
  'v1.0.0/gocd-stages/basic-success-approval.jsonnet',
];
for (const f of files) {
  test(`render ${f}`, async t => {
    await assert_testdata(t, f);
  });
}
