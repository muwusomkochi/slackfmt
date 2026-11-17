# slackfmt Mac app values ledger                         (closes Discover; ruling 157.2; compiled retroactively 2026-10-30)

Every fact a PRD line may bind that Discover read, with its source, depth and read date. Decisions made after Discover (strings, timings, glyphs) are not facts: they live in the PRD's values table with their ruling.

| # | Fact | Source | Depth | Read |
|---|---|---|---|---|
| L1 | Slack desktop reads a `slack/texty` entry inside the Chromium custom type `org.chromium.web-custom-data` on paste | upstream README "How does this even work?"; packages/clipboard/src/lib.rs | full | 2026-10-24 |
| L2 | The pickle layout: u32 LE payload size; u32 LE entry count; each string a u32 LE UTF-16 code-unit count, UTF-16LE bytes, zero padding to 4 | lib.rs `encode_chromium_pickle`, `pickle_string` | full | 2026-10-24 |
| L3 | Upstream writes plain text as the raw input, so the fallback is raw Markdown | lib.rs:27; packages/cli/src/cli.ts:59 | full | 2026-10-24 |
| L4 | Upstream's MIME priority: slack/texty, slack/html, text/html, text/plain | packages/core/src/formats.ts | full | 2026-10-24 |
| L5 | Upstream's format detection: JSON with an `ops` array is Delta; `<[a-z][a-z0-9]*[\s>]` in the first 200 characters is HTML; else Markdown | packages/cli/src/detect.ts | full | 2026-10-24 |
| L6 | The converter's gaps: `break`, `image` and `thematicBreak` fall to the children-only default branch; list start ignored; task items unmarked; list attributes reset inside a quote | packages/core/src/serializers/markdown-to-delta.ts:154 to 177 | full; read, not run | 2026-10-24 |
| L7 | Upstream's HTML path uses Turndown, whose `brInPre` rule calls `node.closest`, so it needs a DOM | packages/core/src/parsers/html.ts | full | 2026-10-24 |
| L8 | Upstream draws table rules with U+2500 | packages/core/src/normalize.ts | full | 2026-10-24 |
| L9 | The web copy uses `execCommand("copy")` with `setData("slack/texty")`, which only Chromium carries to the system pasteboard; WebKit bundles custom types into its own same-origin type | packages/web/src/utils/clipboard.ts:13; webkit.org/blog/8170 | full | 2026-10-24 |
| L10 | Upstream baseline commit `551c592`, 2026-04-01 | upstream git log | full | 2026-10-24 |
| L11 | macOS may prompt before an app reads the pasteboard; a flag only on macOS 26, unconfirmed as default since | mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4 | full | 2026-10-24 |
| L12 | HIG: a click on a menu bar extra should show a menu; use a template symbol; the bar is 24 pt; don't rely on the extra being present; offer other ways in | developer.apple.com/design/human-interface-guidelines/the-menu-bar | full | 2026-10-27 |
| L13 | Existing alternatives and what they write: Raycast Markdown Converter writes mrkdwn text; pandoc plus a pbcopy script writes HTML | raycast.com/ewilderj/markdown-converter; jvt.me/posts/2026/01/13/mac-slack-external-markdown | full | 2026-10-24 |

Unread, carried as risk, not fact: whether Slack prefers HTML over its own format when both are on the pasteboard (X3); whether Slack's Delta carries list starts and quoted lists (X4).
