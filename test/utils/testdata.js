import * as fs from "node:fs/promises";
import * as path from "path";
import { execSync } from "node:child_process";

export function get_fixture_content(filename, outputfiles) {
  const buff = execSync(
    `jsonnet test/testdata/fixtures/${filename} --ext-code output-files=${outputfiles}`
  );
  return buff.toString();
}

export async function render_fixture(filename, outputfiles = false) {
  return JSON.parse(get_fixture_content(filename, outputfiles));
}

export async function assert_testdata(t, filename, outputfiles = true) {
  const got = get_fixture_content(filename, outputfiles);

  const suffix = [];
  if (outputfiles) {
    suffix.push("output-files");
  } else {
    suffix.push("single-file");
  }
  const goldenPath = path.join(
    "test",
    "testdata",
    "goldens",
    `${filename}_${suffix.join("-")}.golden`
  );
  try {
    await fs.stat(goldenPath);
  } catch (err) {
    console.log(`Golden file ${goldenPath} does not exist. Creating it.`);
    await fs.mkdir(path.dirname(goldenPath), { recursive: true });
    await fs.writeFile(goldenPath, got);
  }

  const wantBuff = await fs.readFile(goldenPath);
  const want = wantBuff.toString();

  // Deep Equal with give more helpful diffs
  t.deepEqual(JSON.parse(got), JSON.parse(want));
  // We still want the golden to match exactly
  t.is(got, want);
}

function check_gocd_structure(t, config) {
  t.deepEqual(Object.keys(config), ["format_version", "pipelines"]);
}

export async function assert_gocd_structure(t, filename, outputfiles) {
  const got = await render_fixture(filename, outputfiles);
  if (outputfiles) {
    for (const fn of Object.keys(got)) {
      const config = got[fn];
      check_gocd_structure(t, config);
    }
  } else {
    check_gocd_structure(t, got);
  }
}

export async function get_fixtures(fixture_subdir) {
  const files = await fs.readdir(
    path.join("test/testdata/fixtures", fixture_subdir)
  );
  return files
    .filter((f) => !f.endsWith(".failing.jsonnet"))
    .map((f) => path.join(fixture_subdir, f));
}
