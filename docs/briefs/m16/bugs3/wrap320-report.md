# wrap320 report: the join line wraps on a narrow phone

## Summary

What changed:
- `_YourCharacter` moved to `controller_app/lib/src/ui/your_character.dart` as public `YourCharacter` (no behaviour change in the one-row case). `connect_panels.dart` now imports it and uses `const YourCharacter()`.
- The row is now a `LayoutBuilder`: if the one-row width fits `constraints.maxWidth`, today's Row; otherwise a centred Column with the badge-and-text row and the Change button under it.
- The key `changeCharacter` is kept.
- Tests added to `connect_identity_gap_test.dart` (new cases only; the existing three are unchanged).

Measured (from test runs in this job):
- Panel width at 320x640 (menu look): 109.8 px (the right panel is that narrow there).
- Panel width at 393x852 (portrait): 142.2 px. The one-row width the rule computes is 294 px, so the line wraps there.
- 360x640: the test prints `wrapped`.
- 320x640 menu and TV look: Change sits below the line; the line and Change are centred within 1 px of each other (the test checks it); both stay inside the panel box.
- 852x393: one row, same centre y within 2 px, 8 px gap (test passes).
- Manual address row (connect_screen.dart:348), not touched, overflow at 320x640: **39 px** in the menu look (measured before the fix, unchanged by it); **109 px** in the TV look. The app bar (connect_screen.dart:102) also overflows by **45 px** at 320x640 in the TV look. Both are outside this job.

Decisions:
- Smallest allowed join text width: 8 body-size ems (`_joinTextMinEms = 8.0`, about eight letters at 15 px). Below that the text ellipsises before the line wraps.
- Change's width estimate: `TextPainter` of "Change" in `look.type.button` at body size, plus 12 px per side (`_changeSidePx`, Material's text button side padding). This is an estimate; the real label style comes from the theme.
- The phone-look and TV-look badge slot is 44 px (40 px diameter + 4 px headroom), the same as before.
- The "block centre" for the wrap check is (badge left + text right) / 2, which is how the wrapped line is centred.
- The 320x640 tests drain the layout exceptions from the other rows and check the join line by geometry (it must sit inside the YourCharacter box). Exception matching could not separate the join line's overflow from the other rows', because the test framework merges pending exceptions into one "Multiple exceptions" message.

Test counts: `tools/mine.sh` run last: `OK 9 tests controller_app`, format and analyze clean (3 files formatted, 1 package analyzed).

## Hand-over

Files changed:
- `controller_app/lib/src/ui/your_character.dart` (new): public `YourCharacter`, with the LayoutBuilder wrap rule.
- `controller_app/lib/src/ui/connect_panels.dart`: `_YourCharacter` removed and replaced by `YourCharacter` (import added; `labels.dart` and `settings_screen.dart` imports kept; unused `ToyBadge`, `ToyCharacter`, `toyAccessoryHeadroom` dropped from the `show` list).
- `controller_app/test/connect_identity_gap_test.dart`: new cases for 320x640 (menu and TV), 852x393, 393x852, 360x640; helper functions; import of `your_character.dart`.
- `docs/briefs/m16/bugs3/wrap320-report.md` (this file).

Checks: `tools/mine.sh` passes on the final run (`OK 9 tests controller_app`, format and analyze clean). Earlier runs in this job: one with the new tests failing before the fix, and one with the analyzer's directive-order info, fixed.

Things I was not sure about:
- The brief said 393x852 should stay one row. At that size the panel is only 142 px wide, and the rule says the row cannot fit, so the line wraps. I changed that test to assert the wrap and named it for the 142 px panel. If the owner wants one row at 393x852, the connect screen's portrait layout needs changing; that is outside this job.
- `tools/mine.sh` reported "churn: reverted 22 generated file(s)" on my first run. The working tree had 22 modified generated files (PNGs, `generated_plugin_registrant.*`, `generated_plugins.cmake`) before I started. I did not touch them, but the revert may have changed them. Please check them.
- The Change width uses an estimate (see decisions); a device check would confirm the wrap threshold.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

bugs3 wrap320: join line wraps Change under the text on narrow phones

On a narrow phone the join line and its Change link could not fit one row,
and the row overflowed. Now, when the one-row width (badge slot, gaps, the
text at 8 body ems, Change with its padding) exceeds the panel width, Change
moves onto its own line under the text, centred. Wider phones keep one row.
_YourCharacter moved to your_character.dart as YourCharacter. Tests cover
320x640 (menu and TV), 852x393, 393x852 and 360x640.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- M16 bugs3 wrap320: done: join line wraps Change under the text at narrow widths (LayoutBuilder rule, YourCharacter moved to your_character.dart), tests pass. Open: the address row (connect_screen.dart:348) overflows 39 px at 320x640 (menu) and 109 px (TV), the app bar (connect_screen.dart:102) 45 px in TV; the 393x852 portrait panel is 142 px wide, so the line wraps there (owner decision); Change width is an estimate, needs a device check.

## Delete

- none
