# slackfmt, muwusomkochi's fork

Checklist: https://claude.ai/artifact/TTr4gnsDJnYws7ksPd8cNc

A fork of cauethenorio/slackfmt for a macOS menu bar app (apps/macos) that turns the clipboard into Slack's own paste format with one click. Converter fixes go on their own branches off upstream main and go back as PRs; main carries the app and docs/.

Spec: docs/PRD.md (rev 1, ratified 2026-10-30 @ 260735399ccbf1582198d75f35ae6b0387e815e1) with its values table, docs/DS.md and docs/direction.md. Record: docs/engagement.md.

Build line (precedent ruling 158): nothing starts building (a build session, a paste line or a dispatch) before G3 is recorded in docs/engagement.md with its sha. Read the record before any build work; if G3 isn't recorded there, stop and say so.
