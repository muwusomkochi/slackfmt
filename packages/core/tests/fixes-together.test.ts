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

  const ordered = { insert: "\n", attributes: { list: "ordered" } };
  const strike = { strike: true };

  it("keeps the count after a nested list that's numbered text", async () => {
    const result = await convert("1. one\n\n   3. inner\n2. two", { format: "markdown" });
    expect(result).toBe(delta({ insert: "one" }, ordered, { insert: "3. inner\n2. two\n" }));
  });

  it("keeps the count after a nested list whose own count was split", async () => {
    const result = await convert(
      "1. one\n   1. a\n      ```\n      x\n      ```\n   2. b\n2. two",
      { format: "markdown" },
    );
    expect(result).toBe(
      delta(
        { insert: "one" },
        ordered,
        { insert: "a" },
        { insert: "\n", attributes: { list: "ordered", indent: 1 } },
        { insert: "x" },
        { insert: "\n", attributes: { "code-block": true } },
        { insert: "2. b\n2. two\n" },
      ),
    );
  });

  it("puts a task's box after its number once a block has split the list", async () => {
    const result = await convert("1. [x] one\n   ```\n   a\n   ```\n2. [ ] two", {
      format: "markdown",
    });
    expect(result).toBe(
      delta(
        { insert: "☑ one" },
        ordered,
        { insert: "a" },
        { insert: "\n", attributes: { "code-block": true } },
        { insert: "2. ☐ two\n" },
      ),
    );
  });

  it("marks text once when a tag and its style both strike it", async () => {
    for (const html of [
      '<p><span style="text-decoration:line-through">a <del>b</del> c</span></p>',
      '<p><del>a <span style="text-decoration:line-through">b</span> c</del></p>',
      '<p><s style="text-decoration:line-through">a b c</s></p>',
    ]) {
      expect(await convert(html, { format: "html" })).toBe(
        delta({ insert: "a b c", attributes: strike }, { insert: "\n" }),
      );
    }
  });

  it("keeps struck text beside text struck in CSS", async () => {
    const html = '<p><del>a</del><span style="text-decoration:line-through">b</span><s>c</s></p>';
    expect(await convert(html, { format: "html" })).toBe(
      delta({ insert: "abc", attributes: strike }, { insert: "\n" }),
    );
  });

  it("keeps a list, an image and a box inside a styled wrapper", async () => {
    const html =
      '<b style="font-weight:normal"><ol start="3"><li><p><span style="font-weight:700">x</span></p></li></ol>' +
      '<ul><li><input type="checkbox" checked> done</li></ul>' +
      '<p><img alt="pic" src="https://example.com/p.png"></p><hr></b>';
    expect(await convert(html, { format: "html" })).toBe(
      delta(
        { insert: "3. " },
        { insert: "x", attributes: { bold: true } },
        { insert: "\n\n☑ done" },
        { insert: "\n", attributes: { list: "bullet" } },
        { insert: "\n" },
        { insert: "pic", attributes: { link: "https://example.com/p.png" } },
        { insert: "\n\n──────────\n" },
      ),
    );
  });

  it("keeps a head's text out when marks are set in CSS", async () => {
    const html =
      "<html><head><title>Title</title><style>p { color: red }</style></head>" +
      '<body><p><span style="font-weight:700">body</span></p></body></html>';
    expect(await convert(html, { format: "html" })).toBe(
      delta({ insert: "body", attributes: { bold: true } }, { insert: "\n" }),
    );
  });

  it("keeps the spacing of a plain pre beside text styled in CSS", async () => {
    const html =
      '<p><span style="font-weight:700">Run</span></p><pre style="color:red">a\n  b</pre>';
    expect(await convert(html, { format: "html" })).toBe(
      delta(
        { insert: "Run", attributes: { bold: true } },
        { insert: "\n\na" },
        { insert: "\n", attributes: { "code-block": true } },
        { insert: "  b" },
        { insert: "\n", attributes: { "code-block": true } },
      ),
    );
  });

  it("keeps a bold task's box out of its bold", async () => {
    const html =
      '<ul><li style="font-weight:700"><input type="checkbox" checked> done</li>' +
      '<li><input type="checkbox"><span style="font-weight:700"> open</span></li></ul>';
    expect(await convert(html, { format: "html" })).toBe(
      delta(
        { insert: "☑ " },
        { insert: "done", attributes: { bold: true } },
        { insert: "\n", attributes: { list: "bullet" } },
        { insert: "☐ " },
        { insert: "open", attributes: { bold: true } },
        { insert: "\n", attributes: { list: "bullet" } },
      ),
    );
  });

  it("keeps marks apart where struck and marked text meet", async () => {
    const html =
      '<p><del>(a)</del><span style="font-weight:700">b</span><s>c.</s>d<b><del>(e)</del></b> f</p>';
    expect(await convert(html, { format: "html" })).toBe(
      delta(
        { insert: "(a)", attributes: strike },
        { insert: "b", attributes: { bold: true } },
        { insert: "c.", attributes: strike },
        { insert: "d" },
        { insert: "(e)", attributes: { bold: true, strike: true } },
        { insert: " f\n" },
      ),
    );
  });

  it("keeps an image beside a plain pre", async () => {
    const html = '<pre>one</pre><p><img src="https://example.com/p.png" alt="pic"></p>';
    expect(await convert(html, { format: "html" })).toBe(
      delta(
        { insert: "one" },
        { insert: "\n", attributes: { "code-block": true } },
        { insert: "\n" },
        { insert: "pic", attributes: { link: "https://example.com/p.png" } },
        { insert: "\n" },
      ),
    );
  });

  it("reads a whole-copy pre code as Markdown past a head's title and style", async () => {
    const html =
      "<html><head><title>a page</title><style>pre{}</style></head><body><pre><code>**Done**\n\n- one</code></pre></body></html>";
    expect(await convert(html, { format: "html" })).toBe(
      delta(
        { insert: "Done", attributes: { bold: true } },
        { insert: "\n\none" },
        { insert: "\n", attributes: { list: "bullet" } },
      ),
    );
  });

  it("keeps a pre code holding Markdown as a code block beside an image", async () => {
    const html =
      '<pre><code>**Done**\n\n- one</code></pre><p><img src="https://example.com/p.png" alt="pic"></p>';
    expect(await convert(html, { format: "html" })).toBe(
      delta(
        { insert: "**Done**" },
        { insert: "\n\n", attributes: { "code-block": true } },
        { insert: "- one" },
        { insert: "\n", attributes: { "code-block": true } },
        { insert: "\n" },
        { insert: "pic", attributes: { link: "https://example.com/p.png" } },
        { insert: "\n" },
      ),
    );
  });
});
