import { describe, expect, it } from "vitest";
import { convert } from "../src/pipeline.js";

function delta(...ops: Array<{ insert: string; attributes?: Record<string, unknown> }>): string {
  return JSON.stringify({ ops });
}

describe("fixes that meet", () => {
  it("keeps a list nested in a quoted numbered item inside the quote", async () => {
    const result = await convert("> 3. third\n>    - nested\n> 4. fourth", { format: "markdown" });
    expect(result).toBe(
      delta(
        { insert: "3. third" },
        { insert: "\n", attributes: { blockquote: true } },
        { insert: "nested" },
        { insert: "\n", attributes: { list: "bullet", indent: 1, border: 1 } },
        { insert: "4. fourth" },
        { insert: "\n", attributes: { blockquote: true } },
      ),
    );
  });

  it("puts a task's box after its number", async () => {
    const result = await convert("3. [ ] third\n4. [x] fourth", { format: "markdown" });
    expect(result).toBe(delta({ insert: "3. ☐ third\n4. ☑ fourth\n" }));
  });

  it("keeps a quoted task's box", async () => {
    const result = await convert("> - [x] done", { format: "markdown" });
    expect(result).toBe(
      delta({ insert: "☑ done" }, { insert: "\n", attributes: { list: "bullet", border: 1 } }),
    );
  });
});
