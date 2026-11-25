import {
  deltaLines,
  indentOf,
  isList,
  isQuoted,
  type Line,
  linkRuns,
  type Segment,
} from "./delta-lines.js";

/** A Delta as HTML, for apps that paste formatted text but don't read Slack's format. */
export function toHtml(delta: string): string {
  return groups(deltaLines(delta), isQuoted)
    .map((group) => {
      const html = blocks(group);
      return isQuoted(group[0]) ? `<blockquote>${html}</blockquote>` : html;
    })
    .join("");
}

type Block = "code" | "list" | "heading" | "blank" | "paragraph";

function blockOf(line: Line): Block {
  if (line.attributes["code-block"]) return "code";
  if (isList(line)) return "list";
  if (line.attributes.header) return "heading";
  return line.segments.length === 0 ? "blank" : "paragraph";
}

const render: Record<Block, (lines: Line[]) => string> = {
  code: (lines) => `<pre><code>${lines.map(rawText).join("\n")}</code></pre>`,
  list: lists,
  heading: (lines) => lines.map(heading).join(""),
  blank: () => "",
  paragraph: (lines) => `<p>${lines.map(inline).join("<br>")}</p>`,
};

function blocks(lines: Line[]): string {
  return groups(lines, blockOf)
    .map((group) => render[blockOf(group[0])](group))
    .join("");
}

function heading(line: Line): string {
  const tag = `h${line.attributes.header}`;
  return `<${tag}>${inline(line)}</${tag}>`;
}

/** Consecutive list lines: those at the first line's level are items, deeper ones nest in the item before. */
function lists(lines: Line[]): string {
  const level = indentOf(lines[0]);
  let html = "";
  let open: "ul" | "ol" | undefined;
  for (let i = 0; i < lines.length; ) {
    const tag = lines[i].attributes.list === "ordered" ? "ol" : "ul";
    if (tag !== open) html += `${open ? `</${open}>` : ""}<${tag}>`;
    open = tag;
    let next = i + 1;
    while (next < lines.length && indentOf(lines[next]) > level) next++;
    const nested = next > i + 1 ? lists(lines.slice(i + 1, next)) : "";
    html += `<li>${inline(lines[i])}${nested}</li>`;
    i = next;
  }
  return `${html}</${open}>`;
}

function inline(line: Line): string {
  return linkRuns(line)
    .map(({ link, segments }) => {
      const html = segments.map(marked).join("");
      return link === undefined ? html : `<a href="${escapeAttribute(link)}">${html}</a>`;
    })
    .join("");
}

function marked({ text, attributes }: Segment): string {
  let html = escapeText(text);
  if (attributes.code) html = `<code>${html}</code>`;
  if (attributes.strike) html = `<s>${html}</s>`;
  if (attributes.italic) html = `<em>${html}</em>`;
  if (attributes.bold) html = `<strong>${html}</strong>`;
  return html;
}

function rawText(line: Line): string {
  return line.segments.map((segment) => escapeText(segment.text)).join("");
}

function escapeText(text: string): string {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function escapeAttribute(attribute: string): string {
  return escapeText(attribute).replace(/"/g, "&quot;");
}

/** Splits lines into runs whose key is the same. */
function groups<Key>(lines: Line[], keyOf: (line: Line) => Key): Line[][] {
  const result: Line[][] = [];
  for (const line of lines) {
    const last = result[result.length - 1];
    if (last && keyOf(last[0]) === keyOf(line)) last.push(line);
    else result.push([line]);
  }
  return result;
}
