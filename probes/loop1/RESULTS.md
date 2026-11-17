# slackfmt loop 1 measurements

The eight measurements in section 8 of the slackfmt PRD (precedent `docs/engagements/slackfmt/PRD.md` at `2377f6e`, rev 4), run in this order: X7, X1, X2, X8, X5, X6, X3, X4. Probes only: nothing here is app code, and nothing is in `apps/macos`.

- Session: Code tab, "Skills · 2026-11-16 · d8ce98b4 · slackfmt loop 1 measurements". Check line `engagement-check muwusomkochi/precedent:docs/engagements/slackfmt/ENGAGEMENT.md X1,X2,X3,X4,X5,X6,X7,X8` printed `fetched 68f1476 on muwusomkochi/precedent@master` and `PASS` at 2026-11-16 7:08 pm AST.
- Machine: macOS 27.2.1 (26B131), Apple Silicon; Xcode 27.2 (27B52); Swift 6.4.2; Node 24.22.3; esbuild 0.25.12 (the lockfile's).
- Results: X7 passed, X1 passed, X2 failed, X8 failed, X5 passed, X6 passed, X3 passed, X4 failed. Each section below gives its command, its output and the branch taken on a failure.
- Fixtures: `fixture.md` is the PRD's Appendix A, `fixture.html` its Appendix E, and `fixture-20k.md` is fixture.md repeated and cut at a line end at or under 20,000 characters (section 8). `fixtures.py` reads them from the precedent clone at `2377f6e` at run time into `$TMPDIR/slackfmt-loop1-fixtures`, outside this repo. Their text isn't committed, so the log below gives sizes, hashes, op counts and attribute names, never fixture text.

## Re-running

```sh
cd ~/Development/slackfmt
npx --yes pnpm@10.30.1 install --frozen-lockfile --ignore-scripts --filter @slackfmt/core
python3 -I probes/loop1/fixtures.py
probes/loop1/bundle/build.sh
cd probes/loop1/JSCProbe && swift test
```

`fixtures.py` printed:

```
fixture.md: 29 lines, 616 UTF-16 units, sha256 ab1a3101e0cd904909c09efcac1dbef3ac57a4ab3f224260995db22cb939839e
fixture.html: 31 lines, 937 UTF-16 units, sha256 d490a66e519c7f0a27817120ffcc9fb2d8bb20dd35a08b64d18b6d8acab490a2
fixture-20k.md: 936 lines, 19984 UTF-16 units, sha256 a2ada0643791fdc2092ff63c832e9d3816218ffb91d35e68b5d463cb343749b8
```

## X7: do V16's symbols exist? Passed

Command: `sw_vers && swift probes/loop1/x7-symbols.swift`

```
ProductName:		macOS
ProductVersion:		27.2.1
BuildVersion:		26B131
number: image, 15x15 pt, template true; symbol set 2019, first on macOS 10.15
checkmark: image, 14x13 pt, template true; symbol set 2019, first on macOS 10.15
nosign: image, 15x15 pt, template true; symbol set 2019, first on macOS 10.15
all three returned an image
```

Passes when all three return an image: they do. The question names macOS 14 and this Mac runs 27.2.1, so the probe also reads the system's own symbol availability table (CoreGlyphs `name_availability.plist`): all three shipped in the 2019 set, before macOS 14.

## X1: does the core bundle run in JavaScriptCore? Passed

Command: `probes/loop1/bundle/build.sh`, then `swift test --filter X1Tests` (a Swift test that loads the IIFE into one `JSContext` and calls core's `convert` on each fixture).

The first build, `--platform=browser`, didn't load: `PLATFORM=browser OUTFILE=probes/loop1/build/core.browser.iife.js probes/loop1/bundle/build.sh`, then `SLACKFMT_BUNDLE=../build/core.browser.iife.js swift test --filter X1Tests`:

```
bundle threw on load: ReferenceError: Can't find variable: document
@file://~/Development/slackfmt/probes/loop1/build/core.browser.iife.js:2131:25
Executed 1 test, with 1 failure (1 unexpected)
```

Line 2131 is `decode-named-character-reference`'s `index.dom.js`, which micromark (core's Markdown parser) reaches through that package's `browser` export, so a browser build can't convert Markdown either. `--platform=neutral --main-fields=module,main` takes each package's plain-JS `default` export instead, and Turndown's build that carries domino, a DOM written in JavaScript, not a browser DOM (R31). That build stopped at load on `ReferenceError: Can't find variable: setTimeout`, from `@mixmark-io/domino/lib/WindowTimers.js`, which only captures the timer globals. `build.sh` adds a banner defining the four timer names as stubs that throw if called, so a real timer call would still surface. With it:

```
esbuild 0.25.12, --platform=neutral --main-fields=module,main --banner:js=<the timer stubs>
X1 bundle core.iife.js: 1375764 bytes, sha256 be9c7707db8c0b69fcce8394b539980bba0e140434e68f32d675e601f44bc649, loaded in 32.1 ms
X1 fixture.md as markdown: converted; 30 ops, 23 newlines; attributes: blockquote x1 = 1, bold x1 = 1, code x1 = 1, code-block x1 = 1, indent x1 = 1, italic x1 = 1, link x1, list x8 = bullet|ordered, strike x1 = 1; Delta 1376 bytes, sha256 44482180ccb3ec6c3c87ffe4489c2af88f2d1ce175d2223cb9ace334d8283c49
X1 fixture.html as html: converted; 28 ops, 21 newlines; attributes: blockquote x1 = 1, bold x1 = 1, code x1 = 1, code-block x1 = 1, indent x1 = 1, italic x1 = 1, link x1, list x8 = bullet|ordered; Delta 1315 bytes, sha256 80a66dcc827e5065ad67d8a77b58607555202d14aff6791375b6c74f9385ed8f
Executed 1 test, with 0 failures
```

Cross-check against core's source under Node, by the repo's own test runner (V23's method): `cd probes/loop1/bundle && ../../../packages/core/node_modules/.bin/vitest run`

```
reference fixture.md: 1376 bytes, sha256 44482180ccb3ec6c3c87ffe4489c2af88f2d1ce175d2223cb9ace334d8283c49
reference fixture.html: 1315 bytes, sha256 80a66dcc827e5065ad67d8a77b58607555202d14aff6791375b6c74f9385ed8f
fixture.md: JSContext Delta equals the Node reference byte for byte
fixture.html: JSContext Delta equals the Node reference byte for byte
```

Passes when fixture.md and fixture.html convert: both do, with the neutral build, and each Delta equals Node's byte for byte. The browser build fails at load. Seen along the way, not X1's question: fixture.html's Delta carries no `strike`, since Turndown's defaults have no rule for `<del>`.

## X2: is a conversion fast enough? Failed

Command: `swift test --filter X2Tests`. One `JSContext` loads the bundle once (not timed) and converts fixture-20k.md 20 times. Each run writes one pasteboard item holding V3's pickle, `public.html`, `public.rtf` and `public.utf8-plain-text`, and is timed from the call into the JSContext until `writeObjects` has returned with `changeCount` incremented (it increments at `clearContents`, just before the write). The HTML and plain text come from `bundle/entry.ts`'s stand-ins, since core has no `toHtml` yet; the RTF is that HTML through NSAttributedString (V18). This probes A15's path; it isn't A15.

```
X2 input fixture-20k.md: 19984 UTF-16 units; bundle loaded once in 28.6 ms (not timed)
X2 run 1 outputs: Delta 44396 bytes (973 ops, 742 newlines; attributes: blockquote x32 = 1, bold x33 = 1, code x32 = 1, code-block x32 = 1, indent x33 = 1, italic x33 = 1, link x33, list x259 = bullet|ordered, strike x33 = 1); pickle 88832 bytes, decodes by V3 to the same Delta; public.html 23103 bytes; public.rtf 112925 bytes; plain 15837 UTF-16 units
X2 runs (ms): 965.8, 322.5, 326.4, 327.0, 326.8, 325.5, 323.3, 332.8, 326.4, 326.9, 326.2, 322.4, 319.8, 320.4, 328.3, 319.1, 326.6, 321.9, 321.4, 321.0
X2 stage js: median 283.6 ms, max 291.2 ms
X2 stage pickle: median 4.7 ms, max 5.2 ms
X2 stage rtf: median 35.3 ms, max 669.2 ms
X2 stage write: median 0.6 ms, max 3.3 ms
X2 median of 20: 325.8 ms, min 319.1 ms, max 965.8 ms; budget 300 ms (V7)
```

Median 325.8 ms, over V7's 300 ms with one JSContext kept warm, so it failed. The branch, quoted from section 8: "keep one warm JSContext; if it still misses, stop and reshape R4 in a new revision".

Why it missed, measured, for the revision: the JavaScript stage doesn't speed up across warm runs, because JavaScriptCore here uses its JIT only in a process signed with `com.apple.security.cs.allow-jit`. V12's app (hardened runtime, App Sandbox) doesn't list that entitlement.

- The same conversion timed inside JavaScript, from a plain release binary: `swiftc -O probes/loop1/x2-js-only.swift -o probes/loop1/build/x2-js-only && probes/loop1/build/x2-js-only` printed `median 285.5 ms, min 277.0 ms, max 447.0 ms`, so neither the xctest host nor the Swift bridge is the cost. Lockdown Mode is off (`defaults read .GlobalPreferences LDMGlobalEnabled`: key absent). Re-signed ad hoc with the hardened runtime and `allow-jit`, the same binary printed `median 49.0 ms` and ran a 1e8-iteration integer loop in 45.0 ms, against 827.0 ms with the hardened runtime and no `allow-jit`.
- X2's whole loop from a release executable signed both ways, `probes/loop1/x2-signed.sh`:

```
== no-jit: flags=0x10002(adhoc,runtime); entitlements: none
X2 no-jit runs (ms): 1453.0, 377.9, 324.7, 325.1, 346.8, 316.7, 321.3, 312.8, 315.3, 316.8, 316.5, 376.8, 320.3, 322.8, 324.0, 327.1, 311.4, 310.7, 311.2, 310.2
X2 no-jit stage js: median 284.4 ms, max 339.6 ms
X2 no-jit stage rtf: median 34.6 ms, max 1143.1 ms
X2 no-jit median of 20: 320.8 ms, min 310.2 ms, max 1453.0 ms; budget 300 ms (V7)
== allow-jit: flags=0x10002(adhoc,runtime); entitlements: com.apple.security.cs.allow-jit
X2 allow-jit runs (ms): 488.4, 128.1, 100.8, 86.6, 88.8, 83.3, 81.5, 83.7, 80.9, 98.6, 124.9, 83.9, 83.9, 89.3, 80.9, 78.1, 80.5, 79.5, 75.7, 81.3
X2 allow-jit stage js: median 47.7 ms, max 87.8 ms
X2 allow-jit stage rtf: median 33.8 ms, max 397.5 ms
X2 allow-jit median of 20: 83.8 ms, min 75.7 ms, max 488.4 ms; budget 300 ms (V7)
```

With `allow-jit` the same path's median is 83.8 ms. That entitlement isn't in V12, so whether the revision changes R4 or V12 is the hub's call. Not measured here: a sandboxed build, and the first run after launch (488.4 ms with the JIT, 1453.0 ms without), which the median doesn't cover.

## X8: does NSAttributedString read V24's HTML into V24's RTF attributes? Failed

Command: `swift test --filter X8Tests`. fixture.html goes through NSAttributedString (HTML import), is written as RTF, and is read back through NSAttributedString. Each V24 feature is checked at the text spans fixture.html marks for it (found at run time, by XPath on the HTML), at both stages.

```
X8 fixture.html input 937 bytes -> NSAttributedString 441 units -> RTF 4220 bytes -> read back 415 units
X8 fixture.html bold [V24 RTF: bold font trait]: html import: present (1/1) | rtf read back: present (1/1)
X8 fixture.html bold RTF attributes present: font Times-Bold 12 pt (bold); paragraph (head indent 0, first-line indent 0); also NSKern, NSStrokeColor
X8 fixture.html italic [V24 RTF: italic font trait]: html import: present (1/1) | rtf read back: present (1/1)
X8 fixture.html italic RTF attributes present: font Times-Italic 12 pt (italic); paragraph (head indent 0, first-line indent 0); also NSKern, NSStrokeColor
X8 fixture.html strikethrough [V24 RTF: single strikethrough style]: html import: present (1/1) | rtf read back: present (1/1)
X8 fixture.html strikethrough RTF attributes present: font Times-Roman 12 pt; strikethrough 1; paragraph (head indent 0, first-line indent 0); also NSKern, NSStrikethroughColor, NSStrokeColor
X8 fixture.html inline code [V24 RTF: fixed-pitch font]: html import: present (1/1) | rtf read back: present (1/1)
X8 fixture.html inline code RTF attributes present: font Courier 13 pt (fixed-pitch); paragraph (head indent 0, first-line indent 0); also NSKern, NSStrokeColor
X8 fixture.html link [V24 RTF: link attribute to the URL]: html import: present (1/1) | rtf read back: present (1/1)
X8 fixture.html link RTF attributes present: font Times-Roman 12 pt; underline 1; link; paragraph (head indent 36, first-line indent 0, text lists {disc} from 1); also NSColor, NSKern, NSStrokeColor
X8 fixture.html bullet list [V24 RTF: a text list with a disc marker]: html import: present (1/1; marker formats seen: {disc}) | rtf read back: present (1/1; marker formats seen: {disc})
X8 fixture.html bullet list RTF attributes present: font Times-Roman 12 pt; underline 1; link; paragraph (head indent 36, first-line indent 0, text lists {disc} from 1); also NSColor, NSKern, NSStrokeColor
X8 fixture.html ordered list [V24 RTF: a text list with decimal markers from n]: html import: present (2/2; n = 3; seen: {decimal} from 3, {decimal} from 3) | rtf read back: present (2/2; n = 3; seen: {decimal} from 3, {decimal} from 3)
X8 fixture.html ordered list RTF attributes present: font Times-Roman 12 pt; paragraph (head indent 36, first-line indent 0, text lists {decimal} from 3); also NSKern, NSStrokeColor
X8 fixture.html task item [V24 RTF: a list item whose text starts with V14]: html import: ABSENT (0/2; first character after the list marker: a letter, a letter; in a text list: [true, true]) | rtf read back: ABSENT (0/2; first character after the list marker: a letter, a letter; in a text list: [true, true])
X8 fixture.html task item RTF attributes present: font Times-Roman 12 pt; paragraph (head indent 36, first-line indent 0, text lists {disc} from 1); also NSKern, NSStrokeColor
X8 fixture.html nested list [V24 RTF: a second text-list level]: html import: present (1/1; levels seen: 2) | rtf read back: present (1/1; levels seen: 2)
X8 fixture.html nested list RTF attributes present: font Times-Roman 12 pt; paragraph (head indent 72, first-line indent 0, text lists {disc} from 1 > {circle} from 1); also NSKern, NSStrokeColor
X8 fixture.html quote [V24 RTF: a paragraph head indent above 0]: html import: ABSENT (0/1; head indents: 0; quoted list items' head indents 36, 36, list levels 1, 1) | rtf read back: ABSENT (0/1; head indents: 0; quoted list items' head indents 36, 36, list levels 1, 1)
X8 fixture.html quote RTF attributes present: font Times-Roman 12 pt; paragraph (head indent 0, first-line indent 0); also NSKern, NSStrokeColor
X8 fixture.html code block [V24 RTF: fixed-pitch font on every line]: html import: present (1/1) | rtf read back: present (1/1)
X8 fixture.html code block RTF attributes present: font Courier 13 pt (fixed-pitch); paragraph (head indent 0, first-line indent 0); also NSKern, NSStrokeColor
X8 fixture.html features absent after the RTF read back: task item, quote
```

Passes when every V24 RTF attribute is present: the task item and the quote aren't, so it failed. The branch, quoted from section 8: "A2's RTF check keeps bold, italic, strikethrough, links and fixed-pitch; the list, task and quote features are judged in E2 instead".

Supplementary, not X8's call: fixture.html with each checkbox input as V14's box and `<del>` as `<s>`, which is V24's HTML shape (`testX8SupplementaryV24ShapedHtml`). It separates a fixture difference from an NSAttributedString loss:

```
X8 supplementary V24-shaped task item [V24 RTF: a list item whose text starts with V14]: html import: present (2/2; first character after the list marker: U+2610, U+2611; in a text list: [true, true]) | rtf read back: present (2/2; first character after the list marker: U+2610, U+2611; in a text list: [true, true])
X8 supplementary V24-shaped quote [V24 RTF: a paragraph head indent above 0]: html import: ABSENT (0/1; head indents: 0; quoted list items' head indents 36, 36, list levels 1, 1) | rtf read back: ABSENT (0/1; head indents: 0; quoted list items' head indents 36, 36, list levels 1, 1)
X8 supplementary V24-shaped features absent after the RTF read back: quote
```

So the task miss comes from fixture.html's checkbox inputs, which the HTML import drops, and the quote miss from NSAttributedString itself: a `<blockquote>` paragraph comes back with no head indent, and only the list items inside it are indented, by their list.

## X5: is Ctrl-Opt-Cmd-V free on his Mac? Passed

Command: `swiftc -O probes/loop1/x5-hotkey.swift -o probes/loop1/build/x5-hotkey && probes/loop1/build/x5-hotkey <seconds>`. The probe registers V11's hotkey with `RegisterEventHotKey` as the app would (no options), installs a `kEventHotKeyPressed` handler, and logs each press it receives. It has no window, so nothing on screen comes from it.

The first three runs (from 2026-11-16 19:26, 20:28 and 22:29 AST) each registered with status 0 and ran out before Muwuso was at the Mac, with no presses logged. The fourth run, which took the presses:

```
2026-11-17 12:00:01 AST InstallEventHandler status 0; RegisterEventHotKey(kVK_ANSI_V, controlKey|optionKey|cmdKey, options 0) status 0 (noErr: registered)
2026-11-17 14:37:06 AST x5-hotkey received Ctrl-Opt-Cmd-V
2026-11-17 14:37:18 AST x5-hotkey received Ctrl-Opt-Cmd-V
2026-11-17 14:37:20 AST x5-hotkey received Ctrl-Opt-Cmd-V
2026-11-17 14:37:21 AST x5-hotkey received Ctrl-Opt-Cmd-V
```

Then stopped with `pkill -x x5-hotkey` (exit 143), which releases the hotkey with the process.

Muwuso pressed it once each with Slack, his browser, Finder and the Claude app frontmost, a text field focused where there was one, and answered on the X5 panel card: "Nothing on screen reacted in any of the four apps (A)".

Passes when it registers and only the probe reacts: it registered with status 0, the probe logged all four presses, and nothing else reacted.

## X6: does the Services item show without a Settings change? Passed

Command: `probes/loop1/x6-service/x6.sh install`. It builds `SlackfmtX6Probe.app` from `x6-service/` (an accessory app whose Info.plist declares §6's item: `NSMenuItem` "Copy for Slack", `NSMessage` copyForSlack, `NSSendTypes` public.html, public.rtf and public.utf8-plain-text, an empty `NSRequiredContext`), signs it as V12 does (App Sandbox, hardened runtime, ad hoc), copies it to `~/Applications`, registers it with `lsregister -f`, opens it once, then runs `/System/Library/CoreServices/pbs -update` and reads pbs's list back. macOS 27.2.1 (26B131).

```
Identifier=com.anoraq.slackfmt.x6probe
CodeDirectory v=20500 size=476 flags=0x10002(adhoc,runtime) hashes=4+7 location=embedded
Signature=adhoc
{"com.apple.security.app-sandbox":true}
installed ~/Applications/SlackfmtX6Probe.app; pbs -update exit 0
```

pbs's entry for the probe after the update (`pbs -dump`):

```
NSBundleIdentifier = "com.anoraq.slackfmt.x6probe";
NSBundlePath = "~/Applications/SlackfmtX6Probe.app";
NSKeyEquivalent = { };
NSMenuItem = { default = "Copy for Slack"; };
NSMessage = copyForSlack;
NSPortName = SlackfmtX6Probe;
NSRequiredContext = { };
NSSendTypes = ( "public.html", "public.rtf", "public.utf8-plain-text" );
```

Before the install, `pbs -dump` named the probe 0 times. `defaults read pbs NSServicesStatus` held no entry for it, before or after, so nothing in System Settings turned the item on or off.

Muwuso opened TextEdit, typed made-up words, selected them, opened TextEdit > Services and answered on the X6 panel card: "Copy for Slack is listed in TextEdit's Services menu (A)".

Passes when it's listed: it was, with no Settings change.

Then `probes/loop1/x6-service/x6.sh uninstall`:

```
uninstalled; pbs -update exit 0
0
```

The 0 is `pbs -dump`'s count of lines naming the probe after the uninstall.

## X3: does Slack still read slack/texty when public.html and public.rtf sit beside it? Passed

Command: `cd probes/loop1/JSCProbe && swift run x3-write`. It puts one pasteboard item with all four of V24's types on the general pasteboard: the pickle holding core's Delta of fixture.md (V3, V22), public.html as fixture.html (Appendix E, read from the precedent clone at run time), public.rtf as that HTML through NSAttributedString, and the plain-text stand-in. The fixture's HTML keeps two hard breaks and an `<ol start>` that the Delta drops, so the paste shows which type Slack read.

The first write, at 6:50 pm AST, was replaced by Muwuso's own copies before he pasted (changeCount 399, then 407 when checked). The second write, at 7:10 pm AST:

```
x3-write test: changeCount 407 -> 408; one item holding org.chromium.web-custom-data 2792 bytes (Delta sha256 44482180ccb3ec6c3c87ffe4489c2af88f2d1ce175d2223cb9ace334d8283c49); public.html 937 bytes; public.rtf 4220 bytes; public.utf8-plain-text 498 bytes
read back: changeCount 408 types org.chromium.web-custom-data, public.html, Apple HTML pasteboard type, public.rtf, NeXT Rich Text Format v1.0 pasteboard type, public.utf16-external-plain-text, CorePasteboardFlavorType 0x75743136, public.utf8-plain-text, NSStringPboardType
```

Muwuso pasted it into a Slack desktop message box, unsent, and sent a screenshot of the draft (2026-11-17, about 7:11 pm AST; the screenshot is kept off the branch because it shows Appendix A's text). What it shows, by type:

- The first paragraph's two hard breaks are gone and the lines run together, as in the Delta. public.html and public.rtf keep them as line breaks.
- Bold, italic, strikethrough and the link are formatted, with the link's address hidden. The plain text would show the address in brackets.
- The ordered list is numbered from 1, as the Delta's `list: ordered` gives it. public.html's `<ol start>` would number it from 3.
- The quote's bar sits on its first line only, with its bulleted list outside the quote, as the Delta's ops give it. public.html nests the list inside the `<blockquote>`.
- The nested bullet, the inline code and the code block are Slack's own composer blocks.

Passes when it pastes Slack's format: every difference between the Delta and the other three types came out as the Delta has it, so Slack read slack/texty with public.html and public.rtf beside it.

The numbered list and the quoted list are X4's question, which measures them from Slack's own copy.

## X4: can Slack's Delta carry a list start number and a quoted list? Failed

Command: `cd probes/loop1/JSCProbe && swift run x4-decode watch 21600`, started at 7:13 pm AST. It watches the general pasteboard and, for each new copy, prints its types, decodes org.chromium.web-custom-data by V3 and prints each op's attributes without its text. The full slack/texty JSON goes to a file outside the repo and into the handback only. `swift run x4-decode <label>` reads a single copy the same way.

Muwuso typed made-up text in his own DM's message box in Slack desktop, copied it with ⌘A ⌘C, and sent nothing. The watcher saw three copies, all from Slack, and was stopped with `pkill -f "x4-decode watch"` (exit 143) once he answered.

Copy 1, the numbered list starting at 3:

```
x4 copy-1: changeCount 412
x4 copy-1: item 0 types: public.utf8-plain-text, org.chromium.internal.source-rfh-token, org.chromium.web-custom-data, org.chromium.source-url
x4 copy-1: org.chromium.web-custom-data 204 bytes
x4 copy-1: decodes by V3: yes, 2 entries: public.utf8-plain-text (16 UTF-16 units), slack/texty (40 UTF-16 units)
x4 copy-1: slack/texty parses as JSON with 1 ops
```

It decoded. Its one op has no attributes: no list attribute and no start number. The item numbers are typed text. Muwuso's answer on the X4 card: "When I pressed 1. it automatically turned it into a list when I started with 3. it just kept plain text same for the next line I had to manually add 4. and a space". Slack's composer makes an ordered list only from "1. ", so its Delta has no way to carry a list that starts at 3. What it copies for one is each item's number and ". " as text with no list attribute, which is D1's form for an ordered list.

Copies 2 and 3, the quote holding a bulleted list. Copy 2 was taken with one bullet and copy 3 with two, so copy 3 is the finished draft:

```
x4 copy-2: changeCount 413
x4 copy-2: item 0 types: public.utf8-plain-text, org.chromium.internal.source-rfh-token, org.chromium.web-custom-data, org.chromium.source-url
x4 copy-2: org.chromium.web-custom-data 448 bytes
x4 copy-2: decodes by V3: yes, 2 entries: public.utf8-plain-text (17 UTF-16 units), slack/texty (160 UTF-16 units)
x4 copy-2: slack/texty parses as JSON with 4 ops
x4 copy-2: op 1 newline x1: blockquote=true
x4 copy-2: op 3 newline x1: border=1, list="bullet"
x4 copy-3: changeCount 414
x4 copy-3: item 0 types: public.utf8-plain-text, org.chromium.internal.source-rfh-token, org.chromium.web-custom-data, org.chromium.source-url
x4 copy-3: org.chromium.web-custom-data 632 bytes
x4 copy-3: decodes by V3: yes, 2 entries: public.utf8-plain-text (28 UTF-16 units), slack/texty (242 UTF-16 units)
x4 copy-3: slack/texty parses as JSON with 6 ops
x4 copy-3: op 1 newline x1: blockquote=true
x4 copy-3: op 3 newline x1: border=1, list="bullet"
x4 copy-3: op 5 newline x1: border=1, list="bullet"
```

Both decoded. The quote's lead line carries `blockquote: true`. Each bullet inside the quote carries `list: "bullet"` with `border: 1` and no `blockquote` attribute. Muwuso's answer on the X4 card: "The bullets sat inside the quote with the bar beside them (A)". So Slack's Delta does carry a quoted list, by an attribute neither V22 nor D1 names: `border: 1` on the list line.

Passes when Slack's own Delta shows both, and D1 is that encoding: it shows the quoted list but has no start number, so X4 fails. The branch taken, from §8's X4 row:

> D1: each ordered item starts with its number, starting at n and counting up, then ". " as text, with no list attribute; each line of a quoted list starts with its V15 marker as text, with the blockquote attribute and no list attribute (the attribute carries the quote, so V15 adds the one "> ")

For the hub: the branch's ordered half matches what Slack itself copies for a list starting at 3. The branch's quoted-list half differs from Slack's own encoding, which keeps `list: "bullet"` and marks the quote with `border: 1`. Whether a Delta built that way pastes back into Slack as a quoted list wasn't measured here.
