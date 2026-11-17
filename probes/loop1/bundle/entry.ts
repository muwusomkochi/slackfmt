// Loop 1 probe entry: the fork's core, bundled as an IIFE for a JSContext (X1, X2, X3).
// deltaToHtml and deltaToPlain are probe stand-ins so X2 can time a path that writes all four
// types. They are not core's planned toHtml (V18) or V15's mapping, and no app code uses them.
import { convert } from "../../../packages/core/src/index.ts";

type Attrs = Record<string, unknown>;
type Op = { insert: string; attributes?: Attrs };
type Line = { segs: { text: string; attrs: Attrs }[]; block: Attrs };

function toLines(delta: string): Line[] {
  const ops: Op[] = JSON.parse(delta).ops;
  const lines: Line[] = [];
  let segs: Line["segs"] = [];
  for (const op of ops) {
    const parts = op.insert.split("\n");
    parts.forEach((part, i) => {
      if (part) segs.push({ text: part, attrs: op.attributes ?? {} });
      if (i < parts.length - 1) {
        lines.push({ segs, block: op.attributes ?? {} });
        segs = [];
      }
    });
  }
  if (segs.length) lines.push({ segs, block: {} });
  return lines;
}

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

function inlineHtml(line: Line): string {
  return line.segs
    .map(({ text, attrs }) => {
      let h = esc(text);
      if (attrs.code) h = `<code>${h}</code>`;
      if (attrs.bold) h = `<strong>${h}</strong>`;
      if (attrs.italic) h = `<em>${h}</em>`;
      if (attrs.strike) h = `<s>${h}</s>`;
      if (typeof attrs.link === "string") h = `<a href="${esc(attrs.link)}">${h}</a>`;
      return h;
    })
    .join("");
}

export function deltaToHtml(delta: string): string {
  const out: string[] = [];
  const lists: string[] = [];
  let code: string[] | null = null;
  let quote = false;
  const closeLists = (depth: number) => {
    while (lists.length > depth) out.push(`</li></${lists.pop()}>`);
  };
  const closeCode = () => {
    if (code) out.push(`<pre><code>${code.join("\n")}\n</code></pre>`);
    code = null;
  };
  for (const line of toLines(delta)) {
    const b = line.block;
    if (!b["code-block"]) closeCode();
    if (!b.blockquote && quote) {
      out.push("</blockquote>");
      quote = false;
    }
    if (!b.list) closeLists(0);
    if (b["code-block"]) {
      code ??= [];
      code.push(line.segs.map((s) => esc(s.text)).join(""));
    } else if (b.list) {
      const tag = b.list === "ordered" ? "ol" : "ul";
      const depth = ((b.indent as number) ?? 0) + 1;
      if (lists.length >= depth) {
        closeLists(depth);
        if (lists[depth - 1] !== tag) {
          closeLists(depth - 1);
          out.push(`<${tag}><li>`);
          lists.push(tag);
        } else out.push("</li><li>");
      } else {
        while (lists.length < depth) {
          out.push(`<${tag}><li>`);
          lists.push(tag);
        }
      }
      out.push(inlineHtml(line));
    } else if (b.blockquote) {
      if (!quote) out.push("<blockquote>");
      quote = true;
      out.push(`<p>${inlineHtml(line)}</p>`);
    } else if (line.segs.length) {
      out.push(`<p>${inlineHtml(line)}</p>`);
    }
  }
  closeCode();
  closeLists(0);
  if (quote) out.push("</blockquote>");
  return out.join("\n");
}

export function deltaToPlain(delta: string): string {
  const counters: number[] = [];
  return toLines(delta)
    .map((line) => {
      const b = line.block;
      const text = line.segs
        .map(({ text, attrs }) =>
          typeof attrs.link === "string" && attrs.link !== text ? `${text} (${attrs.link})` : text,
        )
        .join("");
      let prefix = "";
      if (b.list) {
        const depth = (b.indent as number) ?? 0;
        counters.length = depth + 1;
        counters[depth] = (counters[depth] ?? 0) + 1;
        prefix = "    ".repeat(depth) + (b.list === "ordered" ? `${counters[depth]}. ` : "• ");
      } else counters.length = 0;
      return (b.blockquote ? "> " : "") + prefix + text;
    })
    .join("\n");
}

async function run(input: string, format: string) {
  const delta = await convert(input, { format });
  return { delta, html: deltaToHtml(delta), plain: deltaToPlain(delta) };
}

(globalThis as Record<string, unknown>).slackfmtProbe = { convert, run, deltaToHtml, deltaToPlain };
