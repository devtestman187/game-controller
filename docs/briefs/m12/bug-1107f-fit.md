job: m12 bug 1107f fit G4 — the phone's menus fit without scrolling again
stop: after G4.
read: docs/briefs/m12/bug-1107f-fix-report.md (yours: the height table and Questions 1–5) · docs/briefs/m12/bug-1107f-after.png · packages/party_host/lib/src/ui/{host_screen,games_screen,join_screen,join_screen_widgets,puzzle_settings_screen}.dart · packages/party_host/lib/src/providers.dart · controller_app/test/host_title_bar_test.dart · packages/party_host/test/host_title_bar_test.dart

Claude's answers: Q1 win the room back, by D and E below · Q2 keep the label's font family · Q3 stats stays TV-only, unchanged · Q4 a panel is not a button: leave it · Q5 not here (Claude logs it in code-health).

do:
1 D: where the phone's bar is above (`hostBarHeightProvider` > 0), a screen with nothing to go back to (the game picker) shows no title bar: its body starts right under the phone's bar. The TV keeps the picker's "Play" title bar as today.
2 E: where the phone's bar is above, the menus' outer padding below the title bar goes from 24 to 12 at the top (the sides and bottom stay 24). One place decides it, not each screen.
3 At 852x393 on "Play on this phone": the game picker, the level list and both sides of the join screen fit without scrolling (maxScrollExtent 0); the settings page may scroll as it always did. Report the new height table (before = your last table's "after").
4 Delete controller_app/test/bug_1107f_after_test.dart and controller_app/test/probe_metrics_test.dart once the new picture is drawn: redraw docs/briefs/m12/bug-1107f-after.png (the level list) and add docs/briefs/m12/bug-1107f-picker.png (the game picker), both 852x393, the same way as before.
tests (each failing first): the picker on the phone has no title bar and its body starts at the bar's bottom; the picker on the TV keeps its title bar at 0; the picker, the level list and both join sides have maxScrollExtent 0 at 852x393 on the phone; the menus' top padding is 12 on the phone and 24 on the TV.
in the report: test counts before and after, the files changed, the height table.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1107f-fit-report.md · docs/briefs/m12/bug-1107f-after.png · docs/briefs/m12/bug-1107f-picker.png · packages/party_host · controller_app/test
check: format analyze host phone tv
report: docs/briefs/m12/bug-1107f-fit-report.md
