import { detectFormat } from "../../../packages/cli/src/detect.ts";
import { convert, toHtml, toPlainText } from "../../../packages/core/src/index.ts";

async function run(input: string, format: string = detectFormat(input)) {
  const delta = await convert(input, { format });
  return { delta, html: toHtml(delta), plain: toPlainText(delta) };
}

Object.assign(globalThis, { slackfmt: { convert: run } });
