import test from 'ava';
import {assert_testdata} from './utils/testdata.js';

const files = [
  'getsentry/is-st.jsonnet',
];
for (const f of files) {
  test(`render ${f}`, async t => {
    await assert_testdata(t, f);
  });
}
