import { test } from "vitest";
import {
  assert_testdata,
  assert_gocd_structure,
  get_fixtures,
} from "./utils/testdata.js";

for (const filename of await get_fixtures("pipedream")) {
  test(`render ${filename} as multiple files`, async () => {
    await assert_testdata(filename, true);
    await assert_gocd_structure(filename, true);
  });

  test(`render ${filename} as a single file`, async () => {
    await assert_testdata(filename, false);
    await assert_gocd_structure(filename, false);
  });
}
