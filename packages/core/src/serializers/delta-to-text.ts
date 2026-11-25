import {
  deltaLines,
  indentOf,
  isList,
  isQuoted,
  type Line,
  lineText,
  linkRuns,
} from "./delta-lines.js";

const TASK_BOX = /^[☐☑] /;

/** A Delta as plain text that reads well where no formatting is kept. */
export function toPlainText(delta: string): string {
  const marker = listMarkers();
  return deltaLines(delta)
    .map((line) => (isQuoted(line) ? "> " : "") + marker(line) + inlineText(line))
    .join("\n");
}

function inlineText(line: Line): string {
  return linkRuns(line)
    .map(({ link, segments }) => {
      const text = segments.map((segment) => segment.text).join("");
      return link === undefined || link === text ? text : `${text} (${link})`;
    })
    .join("");
}

/** Gives each line its list marker in turn, counting ordered items at each level. */
function listMarkers(): (line: Line) => string {
  let counters: number[] = [];
  let quoted = false;
  return (line) => {
    if (!isList(line)) {
      counters = [];
      return "";
    }
    if (isQuoted(line) !== quoted) counters = [];
    quoted = isQuoted(line);

    const level = indentOf(line);
    const indent = "    ".repeat(level);
    counters = counters.slice(0, level + 1);
    if (line.attributes.list === "ordered") {
      counters[level] = (counters[level] ?? 0) + 1;
      return `${indent}${counters[level]}. `;
    }
    counters[level] = 0;
    return TASK_BOX.test(lineText(line)) ? indent : `${indent}• `;
  };
}
