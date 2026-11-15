# slackfmt Mac app PRD

Status: ratified 2026-10-30 @ 260735399ccbf1582198d75f35ae6b0387e815e1 · rev 1 · owner Muwuso · SOW: none, by the small-change row · applies: the owner's own tooling; a small change (appetite one week, inside that row's 1 to 3); patterns/engagement.md, small tool · engagement record: docs/engagement.md
Rulings: hub panels 2026-10-24 (cards 1 to 5: engine, triggers, fixes, repo, signing); 2026-10-27 16:41 (the same five, answered); 19:27 (scope now with the existing pieces); 20:39 (rev 0 ratified); 21:06 (board align, cards 1 to 3); 2026-10-30 19:51 (mockups, Q1 and mini DS ratified)
changed: prior rev 0, ratified 2026-10-27 20:39, never committed · sections header, 6, 7, 8, 11, 12, 14, Appendices · moved: R1, R3, R5, R6, R9, R11, R18 to R21, R25, R26, R30 changed; R32 to R36 new; T1 to T18 changed; X3 and X4 branches rewritten; X7 new; pending D1 new; Q1 closed
Gate: the build starts only at G3, recorded in docs/engagement.md (ruling 158).

## 1. Summary

A menu bar app for his Mac. He copies anything, clicks the # in the menu bar, and the clipboard now holds Slack's own paste format, so Cmd-V in Slack pastes it formatted. It runs slackfmt's open-source converter (forked to muwusomkochi/slackfmt) inside macOS's built-in JavaScript engine. It writes a rich HTML and RTF copy beside Slack's format, so the same copy pastes formatted in Notion, Linear and Mail, unless X3 rules that out. It fixes six converter gaps found in the code. The appetite is one week from G3.

## 2. Problem, measured

He writes in Markdown and in Claude, then pastes into Slack. Slack turns it into plain text with stray asterisks. So he either reformats by hand in Slack's composer, or opens slackfmt's website in a Chromium browser, pastes, copies, and pastes again.

| What happens | Evidence (source, depth, read date) |
|---|---|
| Markdown pasted into Slack shows raw markers | slackfmt README, before and after images (github.com/cauethenorio/slackfmt, full, 2026-10-24) |
| The web fix only works from a Chromium browser | packages/web/src/utils/clipboard.ts:13 (full, 2026-10-24); WebKit bundles custom types into its own same-origin type (webkit.org/blog/8170, full, 2026-10-24) |
| The converter drops hard breaks, images, thematic breaks, list start numbers, task boxes, and the quote around a quoted list | serializers/markdown-to-delta.ts:154 to 177 (full, 2026-10-24); read, not run, so T12 writes each case as a failing test first |
| The fallback plain text is raw Markdown | packages/clipboard/src/lib.rs:27, packages/cli/src/cli.ts:59 (full, 2026-10-24) |
| How often he pastes formatted text into Slack | Unmeasured, because only he holds it |

Every research fact behind this PRD is in docs/values-ledger.md.

## 3. Who it is for

Muwuso, on his Apple Silicon Mac, macOS 14 or later, signed with his Apple Development identity. Nobody else installs it.

## 4. Appetite and window

Phase 1: one week from G3, one Code tab session plus fix-ups. Window: in daily use before 2026-11-10, because it's a small tool he wants now. At the limit, candidates are cut first. If the ship line no longer fits, the work stops and is reshaped, never extended silently.

## 5. Goals and non-goals

Goals, ranked:
- G1. One click turns any copy into a formatted Slack paste. Measure: E1, RP1.
- G2. The app never makes the clipboard worse. When it can't convert, the clipboard stays exactly as it was. Measure: T3, T4.
- G3. The same copy pastes formatted outside Slack: Notion, Linear, Mail. Measure: E2. Becomes a non-goal if X3 fails.

Non-goals:
- An editor or preview window. His words, 2026-10-27 16:41: "i asked for toolbar app i can press and paste and get the correct format back?!!"
- Pasting for him. A synthetic Cmd-V needs Accessibility permission (R14).
- Turning Slack messages back into Markdown. Not asked for.
- iOS, or a share extension.
- A shared or notarized build (16:41, card 5).
- A desktop widget. A widget can't run an action on click (24 Oct panel, card 2 pick).
- Sending the fixes upstream is wanted (16:41, card 4) but it's process, not product, so it's tracked on the slackfmt list (m030) and in §9.

## 6. Design

The requirements and acceptance bind; the mockups (2026-10-30 19:51, card 1) and the mini DS (docs/DS.md) illustrate them.

Identity: V12.

Elements:
- The status item: a # template image. Idle; done (a checkmark); nothing converted (a nosign, with a tooltip naming why). Timings: V9.
- The done capsule: a check and "Copied for Slack", bottom centre of the screen the pointer is on. It takes no focus and no clicks. Tokens: V17.
- The menu, on right-click or Option-left-click, in this order, with separators as drawn: Copy for Slack · Hotkey ⌃⌥⌘V (disabled, the combo right-aligned) · Launch at login (ticked when on) · Check Slack's format · Quit Slackfmt ⌘Q.

Strings (each bound by the R-line named):

| Where | Text | Bound by |
|---|---|---|
| VoiceOver label of the status item | Copy for Slack | R22 |
| Done, in the capsule and announced | Copied for Slack | R23, R32 |
| Nothing converted: empty clipboard | Clipboard is empty | R12 |
| Nothing converted: already Slack's format | Already Slack format | R12 |
| Nothing converted: an image type present | Images can't be converted | R12 |
| Nothing converted: a file URL present | Files can't be converted | R12 |
| Nothing converted: too long | Too long to convert | R12 |
| Nothing converted: converter error | Couldn't convert this | R12 |
| Check: matches | Slack's format still matches | R21 |
| Check: present but unreadable | Slack's format changed: formatted pastes may break | R21 |
| Check: absent | No Slack format on the clipboard. Copy a formatted message in Slack first | R21 |
| First-run notification | Copy something, then click # in the menu bar | R33 |
| Services menu item | Copy for Slack | R3 |

The nothing-converted announcement is "Nothing converted: " plus the reason.

Flows:
- F1 Click: copy, left-click #, see the checkmark and the capsule, Cmd-V in Slack. Choosing Copy for Slack in the menu is F1 (R35).
- F2 Hotkey: copy, press the hotkey, the same feedback, Cmd-V.
- F3 Services: select text in any app, choose Services > Copy for Slack, the same feedback, Cmd-V.
- F4 Check: copy a formatted message in Slack, choose Check Slack's format, read the result.
- First run: no window opens, launch at login turns on, macOS asks once to allow notifications, and the first-run notification shows if allowed.

## 7. Requirements

Conventions: MUST and MUST NOT carry their BCP 14 meanings (RFC 2119, RFC 8174), in capitals. No other BCP 14 keyword appears. "Convert" means: read a source pasteboard by R5 and R6, then write the general pasteboard by R7 to R9. The source is the general pasteboard for F1 and F2, and the Services pasteboard for F3. R10 and R11 apply to whichever source is read.

Triggers:
- R1 [p1] [G1] When he left-clicks the status item without Option, the app MUST convert.
- R2 [p1] [G1] [pending X5] When he presses the hotkey the menu shows (V11), the app MUST convert.
- R3 [p1] [G1] When he chooses Services > Copy for Slack on selected text, the app MUST convert, with the selection as the source.
- R35 [p1] [G1] When he chooses Copy for Slack in the menu, the app MUST convert.
- R36 [p1] [G1] When he chooses Quit Slackfmt or presses ⌘Q with the menu open, the app MUST quit.
- R4 [p1] [G1] [pending X2] A conversion MUST finish within 300 ms at the median of 20 runs for input up to 20,000 characters, timed from the trigger event to the general pasteboard's changeCount incrementing.

Reading:
- R5 [p1] [G1] The app MUST read the first type present in V4's order.
- R6 [p1] [G1] When the type read is plain text, the app MUST classify it by V5.

Writing:
- R7 [p1] [G1] A conversion MUST write `org.chromium.web-custom-data` holding one Chromium pickle laid out by V3, its one entry `slack/texty` holding the Delta JSON.
- R8 [p1] [G3] [pending X3] A conversion MUST also write `public.html` and `public.rtf` carrying, from the Delta, bold, italic, strikethrough, inline code, links, lists (nested, ordered and task), quotes and code blocks, by V18's paths.
- R9 [p1] [harm: a raw-Markdown paste outside Slack] A conversion MUST write `public.utf8-plain-text` by V15's mapping.

Refusals and states:
- R10 [p1] [harm: a broken paste] When the source already holds Slack's format, the app MUST NOT write to the general pasteboard.
- R11 [p1] [harm: a lost clipboard] If the source is empty, holds an image type (V19), holds a file URL (V19), holds more than V8's limit, or the converter throws, then the app MUST NOT write to the general pasteboard.
- R12 [p1] [G2] When R10 or R11 applies, the status item MUST show the nosign for V9's time with that reason's tooltip string from §6.
- R13 [p1] [G1] When a conversion from F1, F2, F3 or R35 succeeds, the status item MUST show the checkmark for V9's time, then return to idle.
- R32 [p1] [G1] When a conversion from F1, F2, F3 or R35 succeeds, the app MUST show the done capsule by V17 for V9's hold, without taking focus or accepting clicks.
- R14 [p1] [harm: a frightening permission prompt] The app MUST NOT request Accessibility, Input Monitoring or Screen Recording permission.
- R15 [p1] [harm: privacy] The app MUST NOT open a network connection.
- R16 [p1] [harm: privacy] The app MUST NOT write clipboard content to disk, to the unified log, or to standard output or error.
- R17 [p1] [G1] The app MUST NOT show a Dock icon or open a window other than its status item, its menu, the done capsule, the notification permission prompt, and R21's alert.
- R18 [p1] [G1] When he right-clicks or Option-left-clicks the status item, the app MUST open the menu in §6's order.
- R19 [p1] [G1] When the app first runs, it MUST register to launch at login.
- R20 [p1] [G1] When he chooses Launch at login, the app MUST flip its registration and its tick.
- R21 [p1] [harm: Slack changes its format silently] When he chooses Check Slack's format, the app MUST show the §6 check string chosen by V20, as a notification, or as an alert when notifications are off.
- R22 [p1] [harm: excluded from a screen reader] The status item MUST carry the VoiceOver label "Copy for Slack".
- R23 [p1] [harm: excluded from a screen reader] When R12 or R13 shows a state, the app MUST announce its §6 string to VoiceOver.
- R33 [p1] [G1] When the app first runs and notifications are allowed, it MUST post the first-run notification.

Converter (upstream-bound):
- R24 [p1] [G1] When the converter receives a hard break inside a paragraph, it MUST emit a "\n" insert with no block attributes.
- R25 [p1] [G1] When the converter receives an image with alt text, it MUST emit the alt text with a link attribute to the image's URL.
- R34 [p1] [G1] If the converter receives an image with empty alt text, then it MUST emit the URL as the text, with a link attribute to it.
- R26 [p1] [G1] When the converter receives a thematic break, it MUST emit V13 as its own line.
- R27 [p1] [G1] [pending X4, D1] When the converter receives an ordered list that starts at n, it MUST emit its first item numbered n, in D1's encoding.
- R28 [p1] [G1] When the converter receives a task list item, it MUST emit V14's box before its text.
- R29 [p1] [G1] [pending X4, D1] When the converter receives a list inside a blockquote, it MUST emit every line of that list inside the quote, in D1's encoding.
- R30 [p1] [harm: a regression] Every upstream test passing at V6 MUST still pass, unless R24 to R29 change its expected output.
- R31 [p1] [G1] [pending X1] When the converter receives HTML, it MUST convert it without a browser DOM.

Pending decision:
- D1. How Slack's Delta carries a list's start number and a list inside a quote. Settled by X4, in Build's loop 1, before R27 or R29 is built. If X4 passes, D1 is Slack's own encoding, copied into the values table. If it fails, D1 is X4's fail branch.

Values table (ruling 160):

| V | Value | Bound by | Source, depth, read date |
|---|---|---|---|
| V1 | Pasteboard type `org.chromium.web-custom-data` | R5, R7, R10 | ledger L1 (lib.rs, full, 2026-10-24) |
| V2 | Entry name `slack/texty` | R7, R10, V20 | ledger L1 |
| V3 | Pickle: a u32 LE payload size counting every byte after itself; a u32 LE entry count of 1; then the type string and the value string, each as a u32 LE count of UTF-16 code units, the UTF-16LE bytes, and zero bytes to the next 4-byte boundary | R7, V20 | ledger L2 (lib.rs, full, 2026-10-24) |
| V4 | Read order: Slack's format (V1 holding V2), `public.html`, `public.rtf`, `public.utf8-plain-text` | R5 | ledger L4 (formats.ts, full, 2026-10-24); `public.rtf` added by rev 0 |
| V5 | Plain-text class, on the text trimmed of whitespace: if it starts with `{` or `[` and parses as JSON that is an array or holds an `ops` array, Delta; else if the regex `<[a-z][a-z0-9]*[\s>]`, case-insensitive and unanchored, matches within its first 200 characters, HTML; else Markdown | R6 | ledger L5 (detect.ts, full, 2026-10-24) |
| V6 | Upstream baseline commit `551c592` | R30 | ledger L10 |
| V7 | 300 ms, median of 20 runs, input up to 20,000 characters | R4 | rev 0 ratified 2026-10-27 20:39 |
| V8 | Over 200,000 UTF-16 code units, counted on the type read | R11 | rev 0, unit added rev 1 |
| V9 | Done: 1.0 s ±0.2. Nothing: 1.5 s ±0.2. Capsule: 120 ms fade in, 1.0 s ±0.2 fully shown, 200 ms fade out; no fades with Reduce Motion | R12, R13, R32 | mini DS ratified 2026-10-30 19:51 |
| V10 | Every string in §6 | R3, R12, R21 to R23, R33 | mockups ratified 2026-10-30 19:51 |
| V11 | Hotkey Ctrl-Opt-Cmd-V, shown ⌃⌥⌘V; fallback Ctrl-Opt-Cmd-S, shown ⌃⌥⌘S | R2, X5 | 2026-10-24 panel; rev 0 |
| V12 | App Slackfmt, bundle id `com.anoraq.slackfmt`, binary `Slackfmt`, arm64, macOS 14 or later, App Sandbox on, hardened runtime | §6, T5, T7 | rev 0 ratified 2026-10-27 20:39 |
| V13 | Ten U+2500 (──────────) then "\n" | R26 | mockups panel 2026-10-30 19:51, card 2; ledger L8 |
| V14 | "☐ " (U+2610 and a space) for open, "☑ " (U+2611 and a space) for done | R28 | rev 0 |
| V15 | Plain text from the Delta: bold, italic, strike and code markers dropped; a link is its text, a space and its URL in round brackets; a bullet item starts "• ", a nested item four more spaces per level; an ordered item "n. "; a task item V14; a quoted line "> "; a thematic break V13; an image its alt text, a space and its URL in round brackets; a code block's lines as written, no fences; a heading its text | R9 | rev 1 |
| V16 | Glyphs: SF Symbols `number`, `checkmark`, `nosign`; template PDFs of the same names if missing | §6, R12, R13 | mini DS ratified 2026-10-30 19:51 (pending X7) |
| V17 | Capsule: 36 pt high, 16 pt sides, 8 pt gap, 18 pt radius, `.hudWindow` material, system 13 pt medium, check 13 pt semibold; centred on the screen holding the pointer, bottom edge 72 pt above that screen's visibleFrame bottom; a non-activating panel ignoring mouse events | R32 | mini DS ratified 2026-10-30 19:51 |
| V18 | Paths: RTF read through NSAttributedString to HTML, then as HTML (R31); HTML from the Delta by core's new `toHtml`; RTF from that HTML through NSAttributedString | R5, R8 | rev 0 (24 Oct panel, card 1: engine) |
| V19 | Image types `public.png`, `public.tiff`, `public.jpeg`, `public.heic`; file URL type `public.file-url` | R11 | rev 1 |
| V20 | Check: "still matches" when V1 is present, its pickle decodes by V3, V2 is present, and its value parses as JSON holding an `ops` array; "changed" when V1 is present and any of those fails; "absent" when V1 is not present | R21 | rev 1 |
| V21 | Test hooks: `--convert-now` runs one conversion of the general pasteboard and exits 0 converted, 2 nothing converted, 1 error; `--test-throw` makes the converter throw; `--specimen` opens the states for review | T1, T4 | rev 1 |

Ship line: R1 to R36.

Candidates, below the ship line:
- C1 rank 1: the menu shows the first line of the last conversion. [G1]
- C2 rank 2: a sound on success, off by default. [G1]

## 8. Acceptance

The judge for RP1, E1, E2 and T16 is Muwuso. The fixtures live in apps/macos/Tests/fixtures/. fixture.md is Appendix A; fixture.txt is derived from it by V15. The build session writes fixture.html, fixture.rtf, fixture.delta.json, fixture-html.delta.json, fixture.pickle and fixture-20k.md (fixture.md repeated and cut at a line end at 20,000 characters) from §7 and the values table before any fix commits, each with distinct content per type for T17, and shows them in its handback. The verifier checks them against §7 before T1 runs.

| id | covers | test (given / when / then) | must refuse | passes when |
|---|---|---|---|---|
| T1 | R1, R7, R13, R32 | Given fixture.md as plain text, when a left mouse click is posted (CGEvent) on the status item's frame | | the pickle bytes equal fixture.pickle; its decoded slack/texty deep-equals fixture.delta.json; the checkmark shows at +0.1 s and +0.75 s and is idle at +1.3 s; the capsule shows at +0.2 s and is gone at +1.6 s |
| T2 | R8, R9 | Given T1's result | a Markdown marker or a square-bracket link in plain text | plain text equals fixture.txt; public.html, parsed, and public.rtf, read through NSAttributedString, each carry every V18 attribute where fixture.md has it |
| T3 | R10, R12 | Given a Slack desktop copy, when T1's click runs | any write | changeCount unchanged; the nosign shows at +0.1 s and +1.25 s, idle at +1.8 s; tooltip "Already Slack format" |
| T4 | R11, R12 | Given, in turn: empty; an image copied from Preview; a file copied in Finder; an image copied from Safari (HTML and image types); exactly 200,000 code units; 200,001 code units; fixture.md with `--test-throw` | any write in the refused cases | changeCount unchanged for every case but 200,000, which converts; each tooltip matches §6; nosign timing as T3 |
| T5 | R15 | Given F1 to F4 run ten times with `nettop -p <pid>` running throughout | any socket | none; `codesign -d --entitlements -` shows App Sandbox on and no network client entitlement; `codesign -dv` shows the hardened runtime flag |
| T6 | R14 | Given a fresh user account, when the app launches and F1 to F4 and the hotkey each run | an Accessibility, Input Monitoring or Screen Recording prompt | none of the three appears, and the app isn't listed in those three Privacy & Security panes |
| T7 | R16 | Given a canary line added to fixture.md, ten conversions, and T4's throw case | the canary anywhere below | it's absent from the app container, $TMPDIR, ~/Library/Caches, ~/Library/Application Support, ~/Library/Logs, `log show --last 10m --predicate 'process == "Slackfmt"'`, and the app's captured stdout and stderr |
| T8 | R2, R4, R10, R11 | T1, T2, T3, T4, T15, T17 and T18, each triggered by posting the hotkey the menu shows (CGEvent) | as in T3, T4 | each passes |
| T9 | R3, R7, R8, R9, R13, R32 | Given fixture.md in a TextEdit document set to plain text, selected, when Services > Copy for Slack is chosen from TextEdit's menu | | T1's pasteboard and timing checks and T2 pass; the capsule shows; repeat with T3's and T4's sources in TextEdit to show R10 and R11 apply |
| T10 | R17 to R20, R32, R35, R36 | Given a first run, then log out and in, then F1 to F4 with TextEdit frontmost | a Dock icon; an on-screen window outside R17's list; the capsule taking focus or a click | SMAppService.mainApp.status is enabled after the first run and the app runs after log-in; the toggle flips off then on, status and tick each time; CGWindowListCopyWindowInfo for the pid shows only R17's windows; TextEdit stays frontmost and key after each conversion; a click on the capsule lands on the window beneath; right-click and Option-left-click each open the menu in §6's order; Copy for Slack in the menu passes T1's checks; Quit and ⌘Q each end the process |
| T11 | R21 | Given, in turn: a Slack copy; V1 holding a pickle whose slack/texty isn't Delta; V1 holding bytes that don't decode; plain text; first with notifications on, then off | | each shows its V20 string, as a notification, then as an alert |
| T12 | R24 to R29, R34 | One core test per line, committed failing before its fix: a backslash and a two-space hard break; an image with alt and one without; `---`, `***` and `<hr>`; a list starting at 3; open and done tasks; a quoted list | the old output | each passes after its fix, against its fixture |
| T13 | R30 | Given the fork's main | | every upstream test name at V6 is present and passes, except those R24 to R29 change; each changed test was updated in the same commit as its fix (git log) and is listed in the handback |
| T14 | R31 | Given fixture.html, when the bundle runs in JSContext | | the Delta deep-equals fixture-html.delta.json |
| T15 | R4 | Given fixture-20k.md and fixture-20k.html, 20 runs each, timed from the click event to changeCount incrementing | | each median within 300 ms |
| T16 | R22, R23 | Given VoiceOver on, when T1, T3 and each T4 case run (F1 stands for F2 and F3: the announcement keys on the state shown, not the trigger) | | VoiceOver reads "Copy for Slack" and announces each state's string |
| T17 | R5 | Given, in turn: HTML, RTF and plain text together; RTF and plain text; HTML and plain text; plain text only; each type holding distinct content | reading a lower type when a higher one is present | the output matches the fixture of the highest type present |
| T18 | R6 | Given plain text holding, in turn: fixture.delta.json; a JSON array of ops; JSON without `ops`; fixture.html; HTML whose first tag is uppercase; HTML whose first tag starts after character 200; fixture.md | | each is classified by V5 and converts to its expected fixture |
| T19 | R19, R33 | Given a first run with notifications allowed | | the app is registered (T10) and the first-run notification shows with §6's string |
| RP1 | R1, R7 | Replay of the real failure: a Claude reply copied with Claude's copy button pastes into Slack with asterisks today. After the click, he pastes it into Slack | raw asterisks | he sees the formatting (slackfmt list row m020) |

Eval rows:

| id | covers | fixture set (real sources) | baseline | judge | passes when |
|---|---|---|---|---|---|
| E1 | R7, R24 to R29, R34 | Appendix A, one Claude reply, one Notion page, one Google Doc | the same copy pasted plain into Slack | Muwuso | each visibly beats its baseline, side by side |
| E2 | R8, R9 | the same four, pasted into Notion, Linear and Mail | the same copy pasted plain | Muwuso | each visibly beats its baseline |

Measurements the build runs first, in loop 1 (no SOW, so they sit here):

| # | question | how | passes when | if it fails, then |
|---|---|---|---|---|
| X1 | Does the core bundle run in JavaScriptCore? | esbuild IIFE in a JSContext test | fixture.md and fixture.html convert | swap Turndown for rehype-remark; if the bundle can't run at all, stop: a Swift port gets a new PRD revision |
| X2 | Is a conversion fast enough? | T15 | each median within 300 ms | keep one warm JSContext; if it still misses, stop and reshape R4 in a new revision |
| X3 | Does Slack still read slack/texty when public.html and public.rtf sit beside it? | write all four types, paste into Slack desktop | it pastes Slack's format | R8 leaves the ship line and becomes C3, rank 3; E2 drops; G3 becomes a non-goal; §1's rich-copy sentence goes; T2 checks R9 only and T9 drops its R8 check |
| X4 | Can Slack's Delta carry a list start number and a quoted list? | copy both from Slack desktop, decode by V3 | Slack's own Delta shows them, and D1 is that encoding | D1: each ordered item starts with its number, starting at n and counting up, then ". " as text, with no list attribute; each line of a quoted list starts with "> " then its V15 marker as text, with the blockquote attribute |
| X5 | Is Ctrl-Opt-Cmd-V free on his Mac? | RegisterEventHotKey, then press it with his usual apps running | it registers and only Slackfmt reacts | use V11's fallback; the menu shows it |
| X6 | Does the Services item show without a Settings change? | install, `/System/Library/CoreServices/pbs -update`, open the Services menu in TextEdit | it's listed | the first-run notification adds: "Turn on Copy for Slack in System Settings > Keyboard > Keyboard Shortcuts > Services" |
| X7 | Do the V16 symbols exist on macOS 14? | `NSImage(systemSymbolName:)` for each, on his Mac | all three return an image | draw the missing ones as 16 pt template PDFs under the same names |

## 9. Outcome measures

- For two weeks after it ships, he notes any paste that came out wrong. Read at review on 2026-11-24, by him and this hub.
- Upstream PRs opened after RP1 passes (slackfmt list row m030).

## 10. Cross-cutting

- Accessibility: R22, R23, T16; Reduce Motion in V9.
- Privacy: R15, R16.
- Security: V12; T5.
- Performance and reliability: R4, X2; R10 to R12 for failure.
- Localisation: n/a because only he uses it, in English.
- Cost: n/a because there's no service behind it.

## 11. Alternatives considered

| Option | Why it lost | Ruling |
|---|---|---|
| Popover editor with preview | He asked for a button, not an editor | 2026-10-27 16:41, card 2 text |
| Full Swift port of the converter | Drifts from upstream on day one | 2026-10-24 panel, card 1 |
| Tauri shell reusing the Rust crate | Heaviest app, Rust toolchain, least native | 2026-10-24 panel, card 1 |
| Raycast Markdown Converter | Writes mrkdwn text, not Slack's paste format (ledger L13) | none, not offered |
| pandoc plus an HTML clipboard script | Relies on Slack's HTML paste path, not its own format (ledger L13) | none, not offered |
| Paste for him with a synthetic Cmd-V | Needs Accessibility permission (R14) | rev 0 |
| A click opens a menu, as the HIG asks (ledger L12) | The app is one action and he asked for press and paste; the menu stays on right-click | 2026-10-27 21:06, card 2 |
| Convert automatically when Slack comes to the front (Pure Paste's auto toggle) | Changes the clipboard without him acting; untested | 2026-10-27 21:06, card 2; parked |
| A result card (Clop) or a notification per convert (Shottr) | No size saving to show; notifications pile up | 2026-10-27 21:06, card 1 |
| Em dashes as the thematic break | Puts em dashes in his messages | 2026-10-30 19:51, card 2 |

## 12. Risks

Rabbit holes, each with its patch:
- Turndown needs a DOM: X1's branch.
- Slack prefers HTML over its own format: X3's branch.
- Slack changes its private format: R9 keeps readable plain text, and R21 warns.
- A file or image copy carries text or HTML beside it: R11 refuses on V19's types before reading.
- macOS shows a "Paste from other apps" prompt (ledger L11): it's macOS's, not the app's, so R14 doesn't cover it. If it shows, the build notes the macOS version and he allows Slackfmt once in Settings.

Drawbacks: a fork to carry if upstream doesn't merge.

Dependencies: slackfmt upstream (owner: Cauê Thenório); Slack desktop's paste behaviour (owner: Slack).

Pre-mortem: "It is 2026-11-10, and it failed."

| Cause | Points to |
|---|---|
| Slack ignored the custom data from a non-Chromium writer | R7, X3 |
| The converter wouldn't run in JavaScriptCore | R31, X1 |
| He went back to the website because a click gave no clear feedback | R13, R32, R23 |
| An image or file copy got wiped | R11, T4 |
| The hotkey clashed with another app | R2, X5 |

## 13. Phasing

One phase. It delivers the whole tool.

## 14. Rulings and open questions

Rulings: as in the header. Records: docs/direction.md, docs/DS.md, docs/values-ledger.md, docs/engagement.md.

Open questions: none, because Q1 closed on 2026-10-30 19:51, card 2 (V13).

Pending: D1, settled by X4 in Build's loop 1 (§7).

## 15. Parked

- An editor window.
- Pasting for him.
- Slack to Markdown.
- An iOS share extension.
- A desktop widget.
- Converting automatically when Slack comes to the front.

## Appendix A: fixture.md

```
**Skills update**
Panel cards fix landed (s140)\
pick sits below the pills now  
and the gap under the heading is _wider_ and ~~tighter~~ fixed

- [precedent](https://github.com/muwusomkochi/precedent) synced
  - reader cut at 54fdad2
- [ ] upload the decision-panels cut
- [x] ds-workflow seal

3. third step keeps its number
4. fourth follows

> Upload only after the test panel:
> - render it live
> - then upload

---

Run `scripts/pack decision-panels` from ~/Development/skills.

```sh
scripts/pack decision-panels
```

***

![wishbone cover](https://example.com/cover.png)
![](https://example.com/no-alt.png)
```

## Appendix B: build reads

Rev 0 (2026-10-27, a fresh agent given only the PRD): 15 rows checked less than their line, 14 values missing, 1 refusal row missing, 6 lines out of shape, 11 contradictions. All amended.

Rev 1 (2026-10-30, a fresh agent given only the PRD and ruling 160's two clauses): 21 rows checked less than their line, 12 values missing, 0 refusal rows missing, 4 phrasing, 11 contradictions, 8 other. All amended except one: it asked to retag R2, R4, R8 and R31 from pending X to pending D, and they stay X, because each rests on a measurement, which is what pending X marks (patterns/spec.md §7). It also caught a product defect: a file or image copy carries text or HTML beside it, so R11 would have let the app convert it and wipe the copy.

The build-read test (ruling 160): rev 1 is the first read since the two clauses, and both kinds still lead. The clauses were applied to an existing draft, not written in from the first line, so this is a weak test of them. It's logged for the agency arc, not ruled here.

## Appendix C: revision history

| Rev | What changed | Sections | Where each ruling lives |
|---|---|---|---|
| 0 | First draft, amended after the build read; ratified 2026-10-27 20:39 | all | §14 |
| 1 | The done capsule; the HIG departure on click; Q1 closed; ruling 160's values table and case-per-member rows; the rev 1 build read's amendments, including R11's file and image refusal; R33 to R36 for the first-run notification, empty-alt images and the menu's actions | header, 6, 7, 8, 11, 12, 14, A, B | header; docs/direction.md; docs/engagement.md |
</content>
</invoke>
