// The Node reference for X1's cross-check: core's source run by the repo's own test runner on the
// same fixtures (V23's method), written beside them as *.node.delta.json.
// Run: packages/core/node_modules/.bin/vitest run --root probes/loop1/bundle
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expect, test } from "vitest";
import { convert } from "../../../packages/core/src/index.ts";

const dir = process.env.SLACKFMT_FIXTURES ?? join(tmpdir(), "slackfmt-loop1-fixtures");

for (const [name, format] of [
  ["fixture.md", "markdown"],
  ["fixture.html", "html"],
] as const) {
  test(`${name} as ${format}`, async () => {
    const delta = await convert(readFileSync(join(dir, name), "utf8"), { format });
    writeFileSync(join(dir, `${name}.node.delta.json`), delta);
    const sha = createHash("sha256").update(delta).digest("hex");
    console.log(`reference ${name}: ${Buffer.byteLength(delta)} bytes, sha256 ${sha}`);
    expect(JSON.parse(delta).ops.length).toBeGreaterThan(0);
  });
}
