# Upstream pull requests

One branch per converter fix, each cut from upstream `551c592`, each with its test committed failing before its fix and a changeset. m030 opens these against `cauethenorio/slackfmt` `main`, after the Slack test. Nothing is opened yet.

Every upstream test at `551c592` (101 in `packages/core`) is present and passes on every branch. One branch changes one: `fix/html-italics` changes the output that "converts italic" in `packages/core/tests/html.test.ts` expects, in the same commit as its fix.

Some branches touch the same code, so the later ones need a rebase once an earlier one merges:

- the list code in `markdown-to-delta.ts`: `fix/ordered-list-start`, `fix/task-lists`, `fix/quoted-lists`, `fix/split-ordered-lists`
- the Turndown rules in `html.ts`: `fix/task-lists`, `fix/html-strikethrough`, `fix/html-italics`, `fix/html-head-text`, `fix/plain-pre`, `fix/css-marks`
- the processor in `normalize.ts`: `fix/images`, `fix/raw-html-blocks`
- the whole-copy `<pre>` in `html.ts`: `fix/plain-pre`, `fix/pre-code-markdown`

This fork's `main` carries all of them merged: its merge commits show the resolution, and `packages/core/tests/fixes-together.test.ts` holds the cases where they meet. Two branches differ once others are in: a nested list written as numbered text (`fix/ordered-list-start`) also splits the list it's in (`fix/split-ordered-lists`), and a numbered task (`fix/task-lists`) keeps its box after its number. A third shares a check: `fix/pre-code-markdown` carries its own test for "all of the copy's text", and on `main` it uses the one `fix/plain-pre` adds, so a head's text is left out and an image or rule beside the `<pre>` keeps it a code block.

| Branch | Failing test | Fix | Requirement |
|---|---|---|---|
| `fix/hard-breaks` | f8257d0, then 7d88581 | ba88e62, then c9d9e6b (more cases in 6e8c2f4) | R24 |
| `fix/images` | 791732b, then d3a14f0 | 7a6f16c, then 3833ebe | R25, R34 |
| `fix/thematic-breaks` | 1dd0f3f | 9b047c7 | R26 |
| `fix/ordered-list-start` | 7ca4b1d | 6c53bd1 | R27 |
| `fix/task-lists` | ad1e200 | f00e2d9 | R28 |
| `fix/quoted-lists` | 07bd88c | 8ccfbfb | R29 |
| `fix/html-strikethrough` | 9712f17, then b789fe2, then 97c9851 | a10c337, then 534ef4e, then fd9b94c | R37 |
| `fix/css-marks` | 641547d, then a8c7833, then 06db508 | 0ad674a, then 3bcdee4, then 52ba8a8 | R38 |
| `fix/html-head-text` | d94b01f | 652a1e6 | R39 |
| `fix/raw-html-blocks` | d03efa5, then 71fed16 | 8f0e013, then 1162b26 | R40 |
| `fix/html-italics` | cc03c6b | 979b4b9 | R41 |
| `fix/bare-ops-array` | 3365f0b | 009fb87 | R42 |
| `fix/split-ordered-lists` | f244e3e | 8cdaf39 | R43 |
| `fix/plain-pre` | bfb54d5, then 2c1eb63 | 5ed8811, then 7412476 | R44 |
| `fix/pre-code-markdown` | b47a943 | 86700f1 | R45 |

R30 is the regression guard above. R31 (HTML without a browser DOM) needed no converter change: core at `551c592` already converts HTML in a bare JavaScript engine when it's bundled with Turndown's own DOM.

## fix/hard-breaks

Title: fix(core): keep hard breaks as line breaks

```
A hard break (a backslash or two spaces at a line's end, or an HTML <br>) was dropped, so the two lines ran together: "first line\⏎second line" came out as "first linesecond line".

It's now a newline, with the line's own block attributes, the same as a soft break gets. Inside a quote, both lines stay quoted. A break before an inline tag is kept too: remark-stringify swaps a line end there for a space.

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
Turndown has no rule for <del>, <s> or <strike>, so struck text from HTML came out plain. Each is now ~~struck~~, with neighbouring and nested struck text sharing one pair of markers, spaces and breaks kept outside them, a tilde at an edge escaped, each paragraph of a struck block struck on its own, and an empty <wbr> between a word and struck punctuation, where Markdown would read no marker.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/bare-ops-array

Title: fix(core): convert a bare ops array

```
The CLI's detection calls a bare JSON array a Delta, but the Delta parser only read { ops: [...] } and threw "ops is not iterable". It now reads either.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/css-marks

Title: fix(core): keep marks set in CSS

```
Google Docs, and other editors, set marks in CSS rather than tags, so their bold, italic and strikethrough were lost. Google Docs also wraps a whole copy in <b style="font-weight:normal">, so all of it came out bold.

Text whose style sets a font weight of bold or 600 and up, an italic or oblique font style, or a line-through is now bold, italic or struck. An element whose style sets a lighter weight adds no bold, whatever its tag, and one that inherits keeps what's around it. Marks in a <style> sheet aren't read.

This adds rehype-stringify, the counterpart of the rehype-parse core already has: the marks are worked out on the parsed HTML, then handed to Turndown. HTML with no style attribute skips the step.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/html-head-text

Title: fix(core): leave out text inside head, style, script and title

```
HTML with a <head> (Word copies one) put its title and its stylesheet's text in the message. Text inside <head>, <style>, <script> and <title> is now left out.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/raw-html-blocks

Title: fix(core): keep a raw HTML block's text

```
A raw HTML block in Markdown was dropped, text and all. Its text is now kept as plain paragraphs, with the tags stripped, in a list item, a quote or a footnote too. Inline HTML is unchanged: its tags are dropped and its text was already kept.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/html-italics

Title: fix(core): write HTML italics with an asterisk

```
Turndown writes italics with underscores, which Markdown doesn't read inside a word, so "un<em>believ</em>able" came out as "un_believ_able". They're now written with asterisks.

This changes what "converts italic" in html.test.ts expects ("*hello*" rather than "_hello_").

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/split-ordered-lists

Title: fix(core): keep an ordered list's count after a block splits it

```
Slack's Delta can't hold a code block inside a list item, so an ordered list with one between its items starts again at 1 after it. The items after such a block are now numbered text, from where the count left off. An unsplit list is still a list.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/plain-pre

Title: fix(core): keep the text around a plain pre

```
HTML with a <pre> that has no <code> was converted to that <pre>'s text alone, and the rest of the copy was lost. It's now read that way only when the <pre> holds all of the copy's text. Otherwise the whole copy is converted, and the <pre> becomes a code block among the rest. An image or a rule beside it counts as more than its text.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## fix/pre-code-markdown

Title: fix(core): read a whole-copy pre code holding Markdown as Markdown

```
A Markdown draft copied by hand out of a chat's code block arrives as one <pre> holding one <code>, and it came out as one code block of raw Markdown.

When such a <pre><code> holds all of the copy's text, it's now read as the copy's Markdown source if its class names Markdown or plain text (language-markdown, md, plaintext, plain, text or txt), or if it names no language and its text holds Markdown's own marks: a heading, bold, italics, strikethrough, inline code, a labelled link, a list, a quote, a rule, a table, an image or a fence. One naming another language stays a code block, and so does one with no language and none of those marks, so "converts code block" passes unchanged. Indented lines, raw tags and bare URLs don't count as marks, since code holds them too.

Code with no language named that does hold such marks (a "# comment" line, "__init__") is read as Markdown. Beside other text, a <pre><code> is a code block as before.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```
