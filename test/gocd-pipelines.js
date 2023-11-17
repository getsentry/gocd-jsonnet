import test from "ava";
import { assert_testdata, get_fixtures } from "./utils/testdata.js";

const files = await get_fixtures("gocd-pipelines");
for (const f of files) {
  test(`render ${f}`, async (t) => {
    await assert_testdata(t, f);
  });
}
