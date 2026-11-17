# slackfmt Mac app, direction (compiled 2026-10-27)

Board: board/index.md (25 entries). His picks, from the align panel of 2026-10-27 21:06:
1. Feedback: the icon flips to a checkmark, and a capsule at bottom centre shows a check and "Copied for Slack" for 1 s. PRD rev 1 adds R32.
2. Click: a click converts and right-click opens the menu, departing from the HIG on purpose.
3. Glyph: the hash.

Why, in short: the capsule sits where his eyes are, whichever trigger he used. The click stays a single action because the app is a single action, and the HIG's other advice (offer other ways in) is already met by the hotkey and Services. The hash is slackfmt's own mark and can't be mistaken for a clipboard app.

## Reference lock table

Precedent snapshot cited: 54fdad2 (no pattern covers a menu bar utility yet; patterns/menu-bar-utility.md is drafted at build, step 7).

| # | Decision | Source | Still | Trait borrowed | Rejected, and why |
|---|---|---|---|---|---|
| 1 | Type | Apple HIG, the menu bar (desc); Pure Paste menu | board/web-purepaste-2.jpg | System font in the menu and the capsule, no custom face | A custom face: nothing else in the menu bar uses one |
| 2 | Palette | Apple HIG, menu bar extras (desc): "black and clear colors"; Raycast menu bar extras | board/web-raycast-menubar.gif | Monochrome template glyph; the system tints it for light, dark and selected | A coloured glyph or a brand colour: breaks in dark mode and against other extras |
| 3 | Layout rhythm (the menu) | Pure Paste menu; Maccy menu | board/web-purepaste-2.jpg, board/web-maccy-instructions.png | Action first, settings next, Quit last with ⌘Q, groups split by separators | Maccy's list-first layout: no history here |
| 4 | Signature move | Raycast HUD; Teachable toast (Refero); Givingli toast (Mobbin) | board/web-raycast-hud.webp, board/refero-teachable-b727825a.jpg, board/mobbin-givingli-f9c00080.jpg | A capsule with a check and a few words, bottom centre, gone in a second, plus the icon flip | Clop's result card (no saving to show: board/web-clop-poster.jpg); a notification per convert (piles up: board/web-shottr-notification.png) |
| 5 | Glyph | slackfmt README title "#slackfmt" (github.com/cauethenorio/slackfmt, full, 2026-10-24) | rendered on the 21:06 panel, card 3 | The hash | Clipboard (Pure Paste already uses one: board/web-purepaste-2.jpg); clipboard with check (fights the done checkmark) |
| 6 | Done copy | Givingli "Link copied"; Medium "Link copied"; Raycast "Todo copied" | board/mobbin-givingli-f9c00080.jpg, board/mobbin-medium-67bf0b3a.jpg, board/web-raycast-hud.webp | Noun plus "copied", no punctuation: "Copied for Slack" | Perplexity's exclamation (board/mobbin-perplexity-c9f01808.jpg); Todoist's "successfully" (board/mobbin-todoist-366fdcb3.jpg) |
| 7 | Nothing-converted state | Apple's own status symbols swap to a slashed or barred form for an off state (desc) | none on the board | Swap the glyph to `nosign` with a tooltip naming why | A capsule for failures too: noise on a non-event. Worth one more look at the build's own specimen before it locks |
| 8 | Check Slack's format result | Shottr notification | board/web-shottr-notification.png | A notification carries a result he asked for | An alert every time: blocks him for an answer he only reads |
| 9 | Click behaviour | Apple HIG, the menu bar (desc), departed from on purpose; Pure Paste menu as the HIG-shaped alternative | board/web-purepaste-2.jpg | Right-click keeps a standard menu | Menu-first (his 21:06 answer); auto when Slack is in front (untested, parked) |
| 10 | Thematic break in a paste | his mockups-panel answer, 2026-10-30 19:51, card 2; upstream's own table rule uses "─" (normalize.ts, full, 2026-10-24) | rendered on the mockups panel | A box rule of ten U+2500, the PRD's V13 | Three em dashes (rev 0's draft): against his no-em-dash rule |

Row 7 rests on a description only (the mini DS's check 1 looks again at the build's own specimen); row 10 closed with Q1 on 2026-10-30 19:51.

Stills: precedent, sessions/2026-10-27-slackfmt/board/ (private). The Mobbin and Refero screenshots stay out of the public slackfmt fork, which carries this file as docs/direction.md.
