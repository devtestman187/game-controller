job: M14 bugs9 b017-stick-text: the floating-sticks switch text is unreadable (B-017)
pub: no
stop: after it.
read: controller_app/lib/src/ui/stick_dialog.dart · controller_app/lib/src/ui/settings_sections.dart (_SticksSection) · packages/party_host/lib/src/text/settings_text.dart · the phone app's theme (grep ThemeData, ToyLook, ListTileTheme, SwitchListTile in controller_app/lib and packages/party_host/lib) · controller_app/test/stick_mode_test.dart (how the dialog is pumped)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Owner row B-017 (iPhone 16 Pro Max, build m14.3): "When attempting to enable floating sticks, you cannot read the text. The text is white on a light background." The switch is SwitchListTile 'Floating sticks' plus its subtitle, in the Sticks dialog (stick_dialog.dart) and in Settings (settings_sections.dart). There is no screenshot you can read.
Design:
1 TEST FIRST, new file controller_app/test/stick_text_contrast_test.dart (must fail on the old code): pump the stick dialog and the Settings sticks section the way the app does (its real theme and look, light AND dark system brightness if the app follows it), and for the 'Floating sticks' title, its subtitle line and the dialog's other text, compute the effective text colour (resolved from the widget tree: DefaultTextStyle / the Text's own style via the ListTile's resolved style) and the colour of the surface behind it (the dialog or page background); assert a contrast ratio of at least 4.5. First find which text ends up white-ish (ListTile takes its colours from ListTileTheme / the Theme's textTheme / the switch's own theme, not from the look's ink) and let the test capture that.
2 Fix the cause in the theme or at the widgets (prefer one place that fixes every ListTile in the phone app, such as a ListTileTheme with the look's ink colours, over per-widget colours). Keep the look's palette (use look.colors.ink and paper or the existing equivalents).
3 Run flutter test in controller_app once (quiet reporter) and fix what you break.
in the report: start with `## Summary` (at most 30 lines, within its first 40 lines): the cause you found (or "not found, here is what the test measured"), the fix, the contrast numbers before and after, test results with counts you saw, decisions, anything not done. End with `## Hand-over`. Do not claim a test passes unless you ran it in this job and saw it.
tests-first: the new test file must fail on the old code.
rules: aim for 80-150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · tests first: each new test file must fail on the code as it was (the runner checks this) · write only inside allow: · stage nothing yourself · never use git add -A
allow: docs/briefs/m14/bugs9/b017-stick-text-report.md · controller_app/lib/src · controller_app/test
check: format analyze phone
report: docs/briefs/m14/bugs9/b017-stick-text-report.md
