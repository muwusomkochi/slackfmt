export type Attributes = Record<string, unknown>;

export interface Segment {
  text: string;
  attributes: Attributes;
}

export interface Line {
  segments: Segment[];
  attributes: Attributes;
}

interface DeltaOp {
  insert: string;
  attributes?: Attributes;
}

/** A Delta's lines: each newline ends one, and its attributes are the line's. */
export function deltaLines(delta: string): Line[] {
  const { ops } = JSON.parse(delta) as { ops: DeltaOp[] };
  const lines: Line[] = [];
  let segments: Segment[] = [];
  for (const { insert, attributes = {} } of ops) {
    insert.split("\n").forEach((text, index) => {
      if (index > 0) {
        lines.push({ segments, attributes });
        segments = [];
      }
      if (text) segments.push({ text, attributes });
    });
  }
  if (segments.length > 0) lines.push({ segments, attributes: {} });
  return lines;
}

export function lineText(line: Line): string {
  return line.segments.map((segment) => segment.text).join("");
}

/** A line's segments, grouped so a link's segments stay together. */
export function linkRuns(line: Line): { link: string | undefined; segments: Segment[] }[] {
  const runs: { link: string | undefined; segments: Segment[] }[] = [];
  for (const segment of line.segments) {
    const link = segment.attributes.link as string | undefined;
    const last = runs[runs.length - 1];
    if (last && last.link === link) last.segments.push(segment);
    else runs.push({ link, segments: [segment] });
  }
  return runs;
}

export function isList(line: Line): boolean {
  return line.attributes.list === "bullet" || line.attributes.list === "ordered";
}

export function isQuoted(line: Line): boolean {
  return isList(line) ? !!line.attributes.border : !!line.attributes.blockquote;
}

export function indentOf(line: Line): number {
  return (line.attributes.indent as number | undefined) ?? 0;
}
