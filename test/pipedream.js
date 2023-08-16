import test from 'ava';
import {assert_testdata, get_fixtures} from './utils/testdata.js';

const files = await get_fixtures('pipedream');
for (const f of files) {
  test(`render ${f} as multiple files`, async t => {
    await assert_testdata(t, f, true);
  });

  test(`render ${f} as a single file`, async t => {
    await assert_testdata(t, f, false);
  });
}
