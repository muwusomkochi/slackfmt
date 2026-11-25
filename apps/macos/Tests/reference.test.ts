// The fixtures' expected outputs, by V23: the fork's core under Node, on each input in the format V5 gives it.
// WRITE_FIXTURES=1 writes the inputs derived from fixture.md and fixture.html, and every expected output; without it,
// each file must already equal what core gives. The .rtf files and their .rtf.html come from the Swift test target.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { describe, expect, it } from "vitest";
import { detectFormat } from "../../../packages/cli/src/detect.ts";
import { convert, toPlainText } from "../../../packages/core/src/index.ts";

const fixtures = join(import.meta.dirname, "fixtures");
const limit = 20_000;
const writing = process.env.WRITE_FIXTURES === "1";

const read = (name: string) => readFileSync(join(fixtures, name), "utf8");

function settle(name: string, content: string | Buffer): void {
  const path = join(fixtures, name);
  if (writing) {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, content);
  }
  expect(readFileSync(path).equals(Buffer.from(content)), name).toBe(true);
}

const reference = (input: string, format: string = detectFormat(input)) => convert(input, { format });

function pickle(type: string, value: string): Buffer {
  const u32 = (n: number) => {
    const bytes = Buffer.alloc(4);
    bytes.writeUInt32LE(n);
    return bytes;
  };
  const string = (s: string) => {
    const bytes = Buffer.from(s, "utf16le");
    return Buffer.concat([u32(s.length), bytes, Buffer.alloc((4 - (bytes.length % 4)) % 4)]);
  };
  const payload = Buffer.concat([u32(1), string(type), string(value)]);
  return Buffer.concat([u32(payload.length), payload]);
}

function settleExpected(name: string, delta: string): void {
  settle(`expected/${name}.delta.json`, delta);
  settle(`expected/${name}.pickle`, pickle("slack/texty", delta));
}

const md = read("fixture.md");
const html = read("fixture.html");

function cutAt(text: string, end: RegExp): string {
  const repeated = text.repeat(Math.ceil(limit / text.length) + 1);
  const ends = [...repeated.matchAll(end)].map((m) => m.index + m[0].length).filter((i) => i <= limit);
  return repeated.slice(0, Math.max(...ends));
}

async function largestDelta(): Promise<string> {
  let largest = "";
  for (let n = 1; ; n++) {
    const delta = await reference(md.repeat(n), "markdown");
    if (delta.length > limit) return largest;
    largest = delta;
  }
}

const words = (count: number) => `${"plain words ".repeat(20).slice(0, count - 1)} `;

describe("fixtures", () => {
  it("fixture.md, as Markdown", async () => {
    expect(detectFormat(md)).toBe("markdown");
    const delta = await reference(md);
    settle("fixture.delta.json", delta);
    settle("fixture.pickle", pickle("slack/texty", delta));
    settle("fixture.txt", toPlainText(delta));
  });

  it("fixture.html, as HTML", async () => {
    expect(detectFormat(html)).toBe("html");
    settle("fixture-html.delta.json", await reference(html));
  });

  it("the 20k fixtures", async () => {
    const md20k = cutAt(md, /\n/g);
    const html20k = cutAt(html, /<\/(p|ul|ol|li|blockquote|pre)>/g);
    const delta20k = await largestDelta();
    for (const input of [md20k, html20k, delta20k]) expect(input.length).toBeLessThanOrEqual(limit);
    settle("fixture-20k.md", md20k);
    settle("fixture-20k.html", html20k);
    settle("fixture-20k.delta.json", delta20k);
    settleExpected("fixture-20k-md", await reference(md20k));
    settleExpected("fixture-20k-html", await reference(html20k));
    settleExpected("fixture-20k-delta", await reference(delta20k));
  });

  it("the RTF fixtures, from the HTML NSAttributedString writes", async () => {
    for (const name of ["fixture-20k", "a17"]) {
      expect(existsSync(join(fixtures, `${name}.rtf`)), `${name}.rtf`).toBe(true);
      settleExpected(`${name}-rtf`, await reference(read(`${name}.rtf.html`), "html"));
    }
    expect(readFileSync(join(fixtures, "fixture-20k.rtf")).length).toBeLessThanOrEqual(limit);
    settleExpected("a17-plain", await reference("plain wins"));
  });

  it("A18's inputs", async () => {
    const delta = await reference(md);
    const inputs: [name: string, format: string, input: string][] = [
      ["01-delta", "quill-delta", delta],
      ["02-ops-array", "quill-delta", JSON.stringify(JSON.parse(delta).ops)],
      ["03-json-not-delta", "markdown", '{"text": "**bold**"}'],
      ["04-html", "html", html],
      ["05-html-uppercase", "html", html.replace(/<\/?[a-z][a-z0-9]*/g, (tag) => tag.toUpperCase())],
      ["06-words-then-html", "markdown", words(201) + html],
      ["07-markdown", "markdown", md],
      ["08-opens-with-a-link", "markdown", "[precedent](https://github.com/muwusomkochi/precedent) synced"],
      ["09-tag-within-200", "html", `${words(196)}<em>x</em>`],
      ["10-tag-past-200", "markdown", `${words(197)}<em>x</em>`],
    ];
    for (const [name, format, input] of inputs) {
      expect(detectFormat(input), name).toBe(format);
      settle(`a18/${name}.txt`, input);
      settleExpected(`a18-${name}`, await reference(input));
    }
    expect(words(196).length).toBe(196);
    expect(words(197).length).toBe(197);
    expect(words(201).length).toBe(201);
  });
});
