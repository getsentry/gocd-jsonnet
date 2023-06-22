import * as fs from 'node:fs/promises';
import * as path from 'path';
import {execSync} from 'node:child_process';

export async function assert_testdata(t, filename) {
  const gotBuff = execSync(`jsonnet test/testdata/${filename}`);
  const got = gotBuff.toString();


  const goldenPath = path.join('test', 'testdata', `${filename}.golden`);
  try {
    await fs.stat(goldenPath)
  } catch (err) {
    console.log(`Golden file ${goldenPath} does not exist. Creating it.`);
    await fs.writeFile(goldenPath, got);
  }

  const wantBuff = await fs.readFile(goldenPath);
  const want = wantBuff.toString();
  t.is(got, want);
}
