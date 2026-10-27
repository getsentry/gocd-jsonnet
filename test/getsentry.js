import { test } from "vitest";
import { assert_testdata, get_fixtures } from "./utils/testdata.js";

for (const filename of await get_fixtures("getsentry")) {
  test(`render ${filename}`, async () => {
    await assert_testdata(filename);
  });
}
