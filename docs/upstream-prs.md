# Upstream pull requests

One branch per converter fix, each cut from upstream `551c592`, each with its test committed failing before its fix and a changeset. m030 opens these against `cauethenorio/slackfmt` `main`, after the Slack test. Nothing is opened yet.

Every upstream test at `551c592` (101 in `packages/core`) is present and passes on every branch, and no branch changes one.

Four branches touch the list code (`fix/ordered-list-start`, `fix/task-lists`, `fix/quoted-lists` in `markdown-to-delta.ts`; `fix/task-lists` and `fix/html-strikethrough` in `html.ts`), so the later ones need a rebase once an earlier one merges. This fork's `main` carries all of them merged: its merge commits show the resolution, and `packages/core/tests/fixes-together.test.ts` holds the cases where they meet.

| Branch | Failing test | Fix | Requirement |
|---|---|---|---|
| `fix/hard-breaks` | f8257d0 | ba88e62 | R24 |
| `fix/images` | 791732b, then d3a14f0 | 7a6f16c, then 3833ebe | R25, R34 |
| `fix/thematic-breaks` | 1dd0f3f | 9b047c7 | R26 |
| `fix/ordered-list-start` | 7ca4b1d | 6c53bd1 | R27 |
| `fix/task-lists` | ad1e200 | f00e2d9 | R28 |
| `fix/quoted-lists` | 07bd88c | 8ccfbfb | R29 |
| `fix/html-strikethrough` | 9712f17, then b789fe2 | a10c337, then 534ef4e | R37 |
| `fix/bare-ops-array` | 3365f0b | 009fb87 | A18's second input |

R30 is the regression guard above. R31 (HTML without a browser DOM) needed no converter change: core at `551c592` already converts HTML in a bare JavaScript engine when it's bundled with Turndown's own DOM.

## fix/hard-breaks

Title: fix(core): keep hard breaks as line breaks

```
A hard break (a backslash or two spaces at a line's end, or an HTML <br>) was dropped, so the two lines ran together: "first line\⏎second line" came out as "first linesecond line".

It's now a newline, with the line's own block attributes, the same as a soft break gets. Inside a quote, both lines stay quoted.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/images

Title: fix(core): keep images as links

```
Images were dropped. Slack's Delta can't hold one, so an image now becomes its alt text linked to its URL, or the URL linked to itself when there's no alt text. Reference-style images resolve to their definition first. In a table, which becomes a code block and so holds no links, an image keeps its alt text or URL.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/thematic-breaks

Title: fix(core): keep thematic breaks as a box rule

```
Thematic breaks (---, *** and <hr>) were dropped. Slack has no block for one, so each is now a line of ten U+2500, the character tables already use for their rule.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/ordered-list-start

Title: fix(core): keep an ordered list's start number

```
A list starting at 3 pasted into Slack numbered from 1. Slack's Delta has no start number, and Slack's own composer keeps such a list as text ("3. Pears"), so a list that doesn't start at 1 is now written as numbered text. A list from 1 is still a list.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/task-lists

Title: fix(core): keep task list items' boxes

```
"- [ ] open" and "- [x] done" lost their state. Each item's text now starts with ☐ or ☑. HTML checkboxes inside a list item (as GitHub renders them) are read the same way.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/quoted-lists

Title: fix(core): keep lists inside their quote

```
A list inside a blockquote lost the quote. Slack's own copy of a quoted list marks each item with list and border: 1, and no blockquote attribute, and pasting that form back gives a list inside the quote. Lists inside quotes are now written that way, and read back from a Delta the same way, so they round-trip.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/html-strikethrough

Title: fix(core): keep strikethrough from HTML

```
Turndown has no rule for <del>, <s> or <strike>, so struck text from HTML came out plain. Each is now ~~struck~~, with neighbouring and nested struck text sharing one pair of markers, spaces and breaks kept outside them, a tilde at an edge escaped, and each paragraph of a struck block struck on its own.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/bare-ops-array

Title: fix(core): convert a bare ops array

```
The CLI's detection calls a bare JSON array a Delta, but the Delta parser only read { ops: [...] } and threw "ops is not iterable". It now reads either.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```
