# slackfmt Mac app, mini DS (draft for the 2026-10-27 mockups panel)

Built from direction.md. Every value sits beside the PRD line it serves. The build session commits it as docs/DS.md in muwusomkochi/slackfmt.

## Tokens

| Token | Value | Serves |
|---|---|---|
| glyph.idle | SF Symbol `number`, template image, 16 pt in an 18 × 18 pt status image | R1, direction 5 |
| glyph.done | SF Symbol `checkmark` | R13 |
| glyph.nothing | SF Symbol `nosign` | R12 |
| glyph.fallback | If a symbol name is missing on macOS 14, a template PDF drawn at 16 pt, same name | build check |
| time.done | 1.0 s (±0.2) | R13, R32 |
| time.nothing | 1.5 s (±0.2) | R12 |
| motion.capsule.in | fade 120 ms, ease-out | R32 |
| motion.capsule.out | fade 200 ms, ease-in | R32 |
| motion.reduce | with Reduce Motion on, no fades: show, hold, hide | R32, accessibility |
| capsule.height | 36 pt | R32 |
| capsule.padding | 16 pt sides; 8 pt between the check and the text | R32 |
| capsule.radius | 18 pt (fully round) | R32 |
| capsule.material | NSVisualEffectView, material `.hudWindow`, follows light and dark | R32 |
| capsule.type | system font 13 pt, medium; check `checkmark` 13 pt, semibold | R32 |
| capsule.position | horizontally centred on the screen the pointer is on; bottom edge 72 pt above that screen's visibleFrame bottom (clears the Dock) | R32 |
| capsule.window | non-activating NSPanel, level `.statusBar`, ignoresMouseEvents true, canJoinAllSpaces, fullScreenAuxiliary | R17, R32 |
| menu.type | system menu font, standard NSMenu | R18 |
| app.icon | the hash, white, on a graphite rounded square (#1d1d1f), macOS icon grid | notifications |

## Components

1. Status item: idle, done and nothing states (glyph tokens, time tokens), VoiceOver label "Copy for Slack" (R22).
2. Done capsule: check plus "Copied for Slack" (capsule tokens).
3. Tooltip: the nothing-converted reason strings, PRD §6.
4. Menu: Copy for Slack · hotkey (greyed) · separator · Launch at login (tick) · separator · Check Slack's format · separator · Quit Slackfmt ⌘Q (R18 order, separators per direction row 3).
5. Notification: title "Slackfmt", body from PRD §6 (first run; check results).
6. Alert: the check result when notifications are off (R21), standard NSAlert, one OK button.
7. App icon: app.icon.

## Specimen

The mockups panel of 2026-10-27 is the specimen page. The build renders the same states in a debug window (`--specimen`), and T1, T4 and T16 check against it.

## Checks before it locks

1. Row 7 (nothing-converted) has no still: look at the build's own specimen of the nosign state beside system extras before RP1.
2. Confirm SF Symbols `number`, `checkmark` and `nosign` exist on macOS 14 (glyph.fallback covers it if not).
</content>
</invoke>
