import { describe, expect, it } from "vitest";
import { toHtml } from "../src/serializers/delta-to-html.js";

type Op = { insert: string; attributes?: Record<string, unknown> };

function html(...ops: Op[]): string {
  return toHtml(JSON.stringify({ ops }));
}

const bullet = (attributes: Record<string, unknown> = {}): Op => ({
  insert: "\n",
  attributes: { list: "bullet", ...attributes },
});
const ordered = (attributes: Record<string, unknown> = {}): Op => ({
  insert: "\n",
  attributes: { list: "ordered", ...attributes },
});
const quote: Op = { insert: "\n", attributes: { blockquote: true } };
const code: Op = { insert: "\n", attributes: { "code-block": true } };

describe("toHtml", () => {
  it("joins lines into a paragraph, and starts another at a blank line", () => {
    expect(html({ insert: "one\ntwo\n\nthree\n" })).toBe("<p>one<br>two</p><p>three</p>");
  });

  it("marks bold, italic, strike, code and links", () => {
    expect(
      html(
        { insert: "b", attributes: { bold: true } },
        { insert: "i", attributes: { italic: true } },
        { insert: "s", attributes: { strike: true } },
        { insert: "c", attributes: { code: true } },
        { insert: "l", attributes: { link: "https://example.com/?a=1&b=2" } },
        { insert: "\n" },
      ),
    ).toBe(
      '<p><strong>b</strong><em>i</em><s>s</s><code>c</code><a href="https://example.com/?a=1&amp;b=2">l</a></p>',
    );
  });

  it("nests marks on the same text", () => {
    expect(
      html(
        { insert: "x", attributes: { bold: true, italic: true, link: "https://example.com" } },
        { insert: "\n" },
      ),
    ).toBe('<p><a href="https://example.com"><strong><em>x</em></strong></a></p>');
  });

  it("keeps a link whose text changes formatting as one link", () => {
    const link = "https://example.com";
    expect(
      html(
        { insert: "click ", attributes: { link } },
        { insert: "here", attributes: { link, bold: true } },
        { insert: "\n" },
      ),
    ).toBe('<p><a href="https://example.com">click <strong>here</strong></a></p>');
  });

  it("escapes text", () => {
    expect(html({ insert: 'a < b & c > d "e"\n' })).toBe('<p>a &lt; b &amp; c &gt; d "e"</p>');
  });

  it("nests a list inside its item", () => {
    expect(
      html(
        { insert: "a" },
        bullet(),
        { insert: "b" },
        bullet({ indent: 1 }),
        { insert: "c" },
        bullet({ indent: 2 }),
        { insert: "d" },
        bullet(),
      ),
    ).toBe("<ul><li>a<ul><li>b<ul><li>c</li></ul></li></ul></li><li>d</li></ul>");
  });

  it("writes an ordered list from 1", () => {
    expect(html({ insert: "a" }, ordered(), { insert: "b" }, ordered())).toBe(
      "<ol><li>a</li><li>b</li></ol>",
    );
  });

  it("starts another list where the type changes", () => {
    expect(html({ insert: "a" }, bullet(), { insert: "b" }, ordered())).toBe(
      "<ul><li>a</li></ul><ol><li>b</li></ol>",
    );
  });

  it("writes an ordered list starting past 1 as paragraphs", () => {
    expect(html({ insert: "3. third\n4. fourth\n" })).toBe("<p>3. third<br>4. fourth</p>");
  });

  it("writes a list that opens nested", () => {
    expect(
      html({ insert: "3. third\nnested" }, bullet({ indent: 1 }), { insert: "4. fourth\n" }),
    ).toBe("<p>3. third</p><ul><li>nested</li></ul><p>4. fourth</p>");
  });

  it("starts a task item's text with its box", () => {
    expect(html({ insert: "☐ open" }, bullet(), { insert: "☑ done" }, bullet())).toBe(
      "<ul><li>☐ open</li><li>☑ done</li></ul>",
    );
  });

  it("writes a quote, holding its list", () => {
    expect(
      html(
        { insert: "said" },
        quote,
        { insert: "a" },
        bullet({ border: 1 }),
        { insert: "b" },
        bullet({ indent: 1, border: 1 }),
        { insert: "after" },
        quote,
        { insert: "\noutside" },
        bullet(),
      ),
    ).toBe(
      "<blockquote><p>said</p><ul><li>a<ul><li>b</li></ul></li></ul><p>after</p></blockquote><ul><li>outside</li></ul>",
    );
  });

  it("keeps a quoted list apart from the list before it", () => {
    expect(html({ insert: "a" }, ordered(), { insert: "b" }, ordered({ border: 1 }))).toBe(
      "<ol><li>a</li></ol><blockquote><ol><li>b</li></ol></blockquote>",
    );
  });

  it("writes a code block as written", () => {
    expect(html({ insert: "  if (a < b) {" }, code, code, { insert: "  }" }, code)).toBe(
      "<pre><code>  if (a &lt; b) {\n\n  }</code></pre>",
    );
  });

  it("writes a heading", () => {
    expect(html({ insert: "Title" }, { insert: "\n", attributes: { header: 2 } })).toBe(
      "<h2>Title</h2>",
    );
  });

  it("is empty for an empty Delta", () => {
    expect(html()).toBe("");
  });
});
