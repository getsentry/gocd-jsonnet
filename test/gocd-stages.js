import test from 'ava';
import {assert_testdata} from './utils/testdata.js';

const files = [
  'gocd-stages/basic-no-opts.jsonnet',
  'gocd-stages/basic-manual-approval.jsonnet',
  'gocd-stages/basic-success-approval.jsonnet',
];
for (const f of files) {
  test(`render ${f}`, async t => {
    await assert_testdata(t, f);
  });
}
