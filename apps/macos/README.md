# Slackfmt

A menu bar app for macOS. Copy anything, click the # in the menu bar, and the clipboard holds Slack's own paste format, with a formatted HTML and RTF copy and readable plain text beside it.

It runs this repo's converter (`packages/core`) inside macOS's JavaScript engine. It's sandboxed, opens no network connection and asks for no permission but notifications.

## Use

- Click #, press ⌃⌥⌘V, or choose Services > Copy for Slack on selected text.
- Right-click or Option-click # for the menu.

A full menu bar holds new items behind its overflow arrow. ⌘-drag # out from there to keep it in view.

## Build

```bash
npx pnpm@10.30.1 install --frozen-lockfile --ignore-scripts   # from the repo root: core's dependencies and esbuild
apps/macos/scripts/build.sh                                    # build/Slackfmt.app; IDENTITY=<sha1> signs with another certificate
apps/macos/scripts/install.sh                                  # copies it to /Applications
```

## Test

```bash
npx pnpm@10.30.1 test            # core, and the fixtures' references (apps/macos/Tests/reference.test.ts)
cd apps/macos && swift test      # the app's parts, and the bundle against the references
```

`WRITE_FIXTURES=1` on both writes the fixtures and references again. `acceptance/` holds the harness's scripts and each row's result; `swift build -c release --product slackfmt-accept` builds the harness, which posts real clicks and keys.

## Hooks

`--convert-now` (exit 0 converted, 2 nothing converted, 1 error), `--test-throw`, `--specimen`, `--state-log`, `--reset-first-run`.
