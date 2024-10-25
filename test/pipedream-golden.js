import test from "ava";
import {
  assert_testdata,
  assert_gocd_structure,
  get_fixtures,
} from "./utils/testdata.js";

/*
Kept separate from the other pipedream tests since otherwise these tests
do not get run. I am not sure why.
*/
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
