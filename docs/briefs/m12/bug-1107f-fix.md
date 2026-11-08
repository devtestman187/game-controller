job: m12 bug 1107f fix G4 — no focus highlight on the host phone's touch menus; screen titles below the phone's bar
stop: after G4.
read: docs/briefs/m12/bug-1107f-shot.png (the owner's iPhone, look at it as an image: "Any Easy puzzle" ringed, "Shape Race" running into the mode buttons) · docs/design/m12-host-touch.md · packages/party_host/lib/src/ui/{host_button,games_screen,puzzle_settings_screen,stats_screen,stats_screen_widgets,join_screen,join_screen_widgets,pause_menu,away_card,puzzle_screen,puzzle_screen_widgets,game_screen,controller_menus}.dart · packages/party_host/lib/src/providers.dart · controller_app/lib/src/host/{host_screen,host_games,host_overrides}.dart · controller_app/lib/src/ui/{controller_screen,controller_top_bar,top_bar_metrics}.dart · docs/coding-guidelines.md

The owner (build 4, iPhone, "Play on this phone"):
1 "UX elements show as highlighted in the new touch-only menus. This is confusing as there is no way to change the highlighting. It should be removed and a button should only highlight while it's pressed if possible."
2 "the 'Shape Race' text is almost cutting off at the control selection at the top."

Claude's cause: (1) the TV's focus ring (autofocus + the `WidgetState.focused` side and fill, copied in host_button, games_screen, puzzle_settings_screen, stats_screen_widgets) shows on a touch screen too. (2) the host screens' own AppBar is drawn under the phone's bar (`HostGames` fills the area behind it), so its title meets the bar's mode labels and its back arrow is likely hidden under the P1 chip. Confirm both, or say what you found instead.

Claude's rules (approved):
A Touch-first hosts (the phone in "Play on this phone" and "Show on this device"): no focus look until a pad moves the focus. A press through `ControllerMenus` (a joined phone's pad working the menus) shows the focus look; the next touch anywhere on this phone hides it again. While a button is pressed by touch it shows the highlighted look (the fill and the ring) and drops it on release. The TV and the Windows app: unchanged, the focus look shows from the start.
B One seam in party_host says the host is touch-first (default false, so the TV is unchanged); the phone app overrides it. One shared focus-and-press style for every host button, replacing the four copies; nothing reads the platform.
C On the phone (both host choices), a host screen's title bar (back arrow and title) sits below the phone's bar, never under it, and its back arrow is visible and works. The round's screen keeps drawing behind the bar as today (the board and HUD don't move). The TV unchanged. Every host screen with a title bar, today's and future ones, gets this from one place (a shared title bar or a seam), not per screen.

do:
1 Rules A and B. Sweep every focusable thing on the host's screens, cards and menus (buttons, chips, list rows, the pause menu, the away card, the results' buttons) and list them in the report with what each shows now.
2 Rule C. Say in the report how much height the menus lose on the iPhone 852x393 and whether every menu screen still fits without scrolling there (the level list, join, settings, stats, results).
3 Redraw the level list as the owner saw it (852x393, the "Play on this phone" bar, no pad) into docs/briefs/m12/bug-1107f-after.png from a golden-style widget render, so Claude can see it.
tests (each failing first): touch-first: no focus look on first show; a ControllerMenus press shows it; a touch hides it; a pressed button shows the highlight and drops it on release. TV (not touch-first): the focus look on first show as today. The phone's host screens: each menu screen's title bar sits below the bar's rect and meets none of its parts; the back arrow is hit-testable and pops; the round's board rect is unchanged. Existing tests: list any old → new.
in the report: test counts before and after, the files changed, the sweep table, the height numbers, Questions if any.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the bug's reason · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m12/bug-1107f-fix-report.md · docs/briefs/m12/bug-1107f-after.png · packages/party_host · controller_app/lib · controller_app/test · tv_test_app/test
check: format analyze host phone tv
report: docs/briefs/m12/bug-1107f-fix-report.md
