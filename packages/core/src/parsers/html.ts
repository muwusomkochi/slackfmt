import type { Element, Root, RootContent, Text } from "hast";
import rehypeParse from "rehype-parse";
import TurndownService from "turndown";
import { unified } from "unified";
import { type Mark, markCssMarks } from "./css-marks.js";

const turndown = new TurndownService({
  headingStyle: "atx",
  codeBlockStyle: "fenced",
  bulletListMarker: "-",
  emDelimiter: "*",
  preformattedCode: true,
});

turndown.remove(["head", "style", "script", "title"]);

turndown.addRule("brInPre", {
  filter(node) {
    return node.nodeName === "BR" && !!node.closest("pre");
  },
  replacement() {
    return "\n";
  },
});

const STRUCK_TAGS = ["DEL", "S", "STRIKE"];

function isStruck(node: Node | null): boolean {
  return !!node && STRUCK_TAGS.includes(node.nodeName);
}

turndown.addRule("strikethrough", {
  filter(node) {
    return isStruck(node);
  },
  replacement(content, node) {
    // One pair of markers per run: struck text inside struck text, or right beside it, shares them.
    if ((node.parentNode as HTMLElement | null)?.closest("del, s, strike")) return content;
    const open = isStruck(node.previousSibling) ? "" : "~~";
    const close = isStruck(node.nextSibling) ? "" : "~~";
    return content
      .split(/(\n\s*\n)/)
      .map((block) => strike(block, open, close))
      .join("");
  },
});

/** Markers touch the text: a space or break outside them, a tilde beside them escaped. */
function strike(block: string, open: string, close: string): string {
  const [, before, text, after] = /^(\s*)([\s\S]*?)(\s*)$/.exec(block) as RegExpExecArray;
  if (!text) return block;
  const escaped = text.replace(/^~/, "\\~").replace(/([^\\])~$/, "$1\\~");
  return before + open + escaped + close + after;
}

turndown.addRule("taskListItem", {
  filter(node) {
    return (
      node.nodeName === "INPUT" &&
      node.getAttribute("type")?.toLowerCase() === "checkbox" &&
      !!node.closest("li")
    );
  },
  replacement(_content, node) {
    const box = (node as HTMLElement).hasAttribute("checked") ? "[x]" : "[ ]";
    return /^\s/.test(node.nextSibling?.textContent ?? "") ? box : `${box} `;
  },
});

turndown.addRule("plainPre", {
  filter(node) {
    return node.nodeName === "PRE" && !node.querySelector("code");
  },
  replacement(_content, node) {
    const text = rawText(node).replace(/^\n+|\n+$/g, "");
    const longest = Math.max(2, ...(text.match(/`+/g) ?? []).map((run) => run.length));
    const fence = "`".repeat(longest + 1);
    return `\n\n${fence}\n${text}\n${fence}\n\n`;
  },
});

/** A node's text as written, unescaped, with its line breaks. */
function rawText(node: Node): string {
  if (node.nodeName === "BR") return "\n";
  if (node.childNodes.length === 0) return node.textContent ?? "";
  return Array.from(node.childNodes).map(rawText).join("");
}

const MARKERS: Record<Mark, string> = { bold: "**", italic: "*", strike: "~~" };

turndown.addRule("cssMarks", {
  filter(node) {
    return node.hasAttribute("data-marks");
  },
  replacement(content, node) {
    if (!content.trim()) return content;
    const marks = ((node as HTMLElement).getAttribute("data-marks") ?? "").split(" ") as Mark[];
    const open = marks.map((mark) => MARKERS[mark]).join("");
    const close = [...open].reverse().join("");
    const trimmed = content.trim();
    // A tilde beside the strikethrough's own would join it.
    const text = marks.includes("strike")
      ? trimmed.replace(/^~/, "\\~").replace(/([^\\])~$/, "$1\\~")
      : trimmed;
    const before = seam(node, "previousSibling", trimmed[0]);
    const after = seam(node, "nextSibling", trimmed[trimmed.length - 1]);
    return before + open + text + close + after;
  },
});

const MARKED = /^(B|STRONG|I|EM|DEL|S|STRIKE)$/;
const BLOCK =
  /^(ADDRESS|ARTICLE|ASIDE|BLOCKQUOTE|BODY|BR|DD|DIV|DL|DT|FIGURE|FOOTER|FORM|H[1-6]|HEADER|HR|HTML|LI|MAIN|NAV|OL|P|PRE|SECTION|TABLE|TBODY|TD|TFOOT|TH|THEAD|TR|UL|X-TURNDOWN)$/;

/**
 * Markdown reads a marker by the characters on either side of it. Between marked text and
 * other marked text, or between a word and marked punctuation, an empty tag lets it read both.
 */
function seam(
  node: TurndownService.Node,
  side: "previousSibling" | "nextSibling",
  edge: string,
): string {
  const neighbour = neighbourOf(node, side);
  if (!neighbour || /\s/.test(neighbour.character)) return "";
  const punctuation = /[\p{P}\p{S}]/u;
  const word = !punctuation.test(neighbour.character);
  return neighbour.marked || (word && punctuation.test(edge)) ? "<wbr>" : "";
}

function neighbourOf(
  from: Node,
  side: "previousSibling" | "nextSibling",
): { character: string; marked: boolean } | null {
  const end = side === "previousSibling" ? "lastChild" : "firstChild";
  for (let node: Node | null = from; node && !BLOCK.test(node.nodeName); node = node.parentNode) {
    for (let sibling = node[side]; sibling; sibling = sibling[side]) {
      if (BLOCK.test(sibling.nodeName)) return null;
      const text = sibling.textContent ?? "";
      if (!text) continue;
      let marked = false;
      for (let leaf: Node | null = sibling; leaf; leaf = leaf[end]) {
        marked ||=
          MARKED.test(leaf.nodeName) || !!(leaf as HTMLElement).getAttribute?.("data-marks");
      }
      return { character: side === "previousSibling" ? text[text.length - 1] : text[0], marked };
    }
  }
  return null;
}

const PRESENTATIONAL_TAGS = new Set(["span", "div", "br"]);

function isPresentationalOnly(node: RootContent): boolean {
  if (node.type === "text") return true;
  if (node.type === "comment" || node.type === "doctype") return true;
  if (node.type === "element") {
    if (!PRESENTATIONAL_TAGS.has(node.tagName)) return false;
    return node.children.every(isPresentationalOnly);
  }
  return false;
}

function hasWhiteSpacePre(el: Element): boolean {
  const style = (el.properties?.style as string) ?? "";
  return /white-space\s*:\s*pre/.test(style);
}

function findPreformattedContainer(nodes: RootContent[]): Element | null {
  for (const node of nodes) {
    if (node.type !== "element") continue;
    if (node.tagName === "pre") return node;
    if (node.tagName === "div" && hasWhiteSpacePre(node)) return node;
    // Walk into wrapper elements like html, head, body, div
    const found = findPreformattedContainer(node.children as RootContent[]);
    if (found) return found;
  }
  return null;
}

function extractText(nodes: RootContent[]): string {
  let result = "";
  for (const node of nodes) {
    if (node.type === "text") {
      result += (node as Text).value;
    } else if (node.type === "element") {
      if (node.tagName === "br") {
        result += "\n";
      } else if (node.tagName === "div") {
        // div boundaries produce newlines, but avoid leading newline for first div
        if (result.length > 0 && !result.endsWith("\n")) {
          result += "\n";
        }
        const inner = extractText(node.children as RootContent[]);
        if (inner === "") {
          // Empty div = blank line
          result += "\n";
        } else {
          result += inner;
        }
      } else {
        // span or other presentational — just recurse
        result += extractText(node.children as RootContent[]);
      }
    }
  }
  return result;
}

const HIDDEN_TAGS = new Set(["head", "style", "script", "title"]);

/** The text a reader sees, without its spacing. */
function visibleText(nodes: RootContent[]): string {
  return nodes
    .map((node) => {
      if (node.type === "text") return node.value.replace(/\s+/g, "");
      if (node.type !== "element" || HIDDEN_TAGS.has(node.tagName)) return "";
      return visibleText(node.children as RootContent[]);
    })
    .join("");
}

function tryExtractSyntaxHighlighted(input: string): string | null {
  const tree = unified().use(rehypeParse, { fragment: false }).parse(input) as Root;

  const container = findPreformattedContainer(tree.children as RootContent[]);
  if (!container) return null;

  // Check all children are presentational only
  if (!container.children.every((c) => isPresentationalOnly(c as RootContent))) return null;

  // Beside other text it's one block among others, and returning it alone would lose the rest.
  if (visibleText(tree.children as RootContent[]) !== visibleText([container])) return null;

  const text = extractText(container.children as RootContent[]);
  // Trim trailing newline that may result from structure
  return text.replace(/\n$/, "");
}

export function htmlToMarkdown(input: string): string {
  const extracted = tryExtractSyntaxHighlighted(input);
  if (extracted !== null) return extracted;
  return turndown.turndown(markCssMarks(input));
}
