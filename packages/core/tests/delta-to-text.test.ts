import { describe, expect, it } from "vitest";
import { toPlainText } from "../src/serializers/delta-to-text.js";

type Op = { insert: string; attributes?: Record<string, unknown> };

function text(...ops: Op[]): string {
  return toPlainText(JSON.stringify({ ops }));
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

describe("toPlainText", () => {
  it("ends a line at each newline and leaves no trailing newline", () => {
    expect(text({ insert: "one\ntwo\n\nthree\n" })).toBe("one\ntwo\n\nthree");
  });

  it("keeps a last line that has no newline", () => {
    expect(text({ insert: "one\ntwo" })).toBe("one\ntwo");
  });

  it("drops bold, italic, strike and code markers", () => {
    expect(
      text(
        { insert: "b", attributes: { bold: true } },
        { insert: "i", attributes: { italic: true } },
        { insert: "s", attributes: { strike: true } },
        { insert: "c", attributes: { code: true } },
        { insert: "\n" },
      ),
    ).toBe("bisc");
  });

  it("writes a link as its text and its URL in round brackets", () => {
    expect(
      text({ insert: "click", attributes: { link: "https://example.com" } }, { insert: " me\n" }),
    ).toBe("click (https://example.com) me");
  });

  it("writes a link whose text is its URL once", () => {
    const url = "https://example.com";
    expect(text({ insert: url, attributes: { link: url } }, { insert: "\n" })).toBe(url);
  });

  it("writes one URL for a link whose text changes formatting", () => {
    const link = "https://example.com";
    expect(
      text(
        { insert: "click ", attributes: { link } },
        { insert: "here", attributes: { link, bold: true } },
        { insert: "\n" },
      ),
    ).toBe("click here (https://example.com)");
  });

  it("marks bullets, and indents nested items by four spaces a level", () => {
    expect(
      text(
        { insert: "a" },
        bullet(),
        { insert: "b" },
        bullet({ indent: 1 }),
        { insert: "c" },
        bullet({ indent: 2 }),
      ),
    ).toBe("• a\n    • b\n        • c");
  });

  it("numbers ordered items, and starts again after another line or a shallower item", () => {
    expect(
      text(
        { insert: "a" },
        ordered(),
        { insert: "x" },
        ordered({ indent: 1 }),
        { insert: "y" },
        ordered({ indent: 1 }),
        { insert: "b" },
        ordered(),
        { insert: "z" },
        ordered({ indent: 1 }),
        { insert: "between\nc" },
        ordered(),
      ),
    ).toBe("1. a\n    1. x\n    2. y\n2. b\n    1. z\nbetween\n1. c");
  });

  it("gives a task item its box and no bullet", () => {
    expect(
      text(
        { insert: "☐ open" },
        bullet(),
        { insert: "☑ " },
        { insert: "done", attributes: { bold: true } },
        bullet(),
        { insert: "☐ nested" },
        bullet({ indent: 1 }),
      ),
    ).toBe("☐ open\n☑ done\n    ☐ nested");
  });

  it("starts a quoted line with one marker", () => {
    expect(text({ insert: "said" }, quote, { insert: "• typed" }, quote)).toBe("> said\n> • typed");
  });

  it("starts a quoted list line with the marker, then its list form", () => {
    expect(
      text(
        { insert: "said" },
        quote,
        { insert: "a" },
        bullet({ border: 1 }),
        { insert: "b" },
        bullet({ indent: 1, border: 1 }),
        { insert: "☑ c" },
        bullet({ border: 1 }),
      ),
    ).toBe("> said\n> • a\n>     • b\n> ☑ c");
  });

  it("numbers an ordered item inside a quote from 1", () => {
    expect(
      text({ insert: "a" }, ordered({ border: 1 }), { insert: "b" }, ordered({ border: 1 })),
    ).toBe("> 1. a\n> 2. b");
  });

  it("keeps a quoted list's numbers apart from the list before it", () => {
    expect(text({ insert: "a" }, ordered(), { insert: "b" }, ordered({ border: 1 }))).toBe(
      "1. a\n> 1. b",
    );
  });

  it("keeps the numbers of an ordered item inside a quote that starts past 1", () => {
    expect(text({ insert: "3. third" }, quote)).toBe("> 3. third");
  });

  it("gives a heading its text", () => {
    expect(text({ insert: "Title" }, { insert: "\n", attributes: { header: 2 } })).toBe("Title");
  });

  it("keeps a thematic break's rule", () => {
    expect(text({ insert: "a\n\n──────────\n\nb\n" })).toBe("a\n\n──────────\n\nb");
  });

  it("keeps a code block's lines as written, with no fences", () => {
    const code: Op = { insert: "\n", attributes: { "code-block": true } };
    expect(text({ insert: "  if (x) {" }, code, code, { insert: "  }" }, code)).toBe(
      "  if (x) {\n\n  }",
    );
  });

  it("is empty for an empty Delta", () => {
    expect(text()).toBe("");
  });
});
