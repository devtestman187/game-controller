job: wave2-789 n9e — Resume on the host's pause card is in the look's `good` colour
stop: The phone pad's Start/Resume pill is NOT touched (owner question open). No other host button changes.
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/ui/pause_menu_widgets.dart:55-95 · packages/party_host/lib/src/ui/host_button.dart:95-135 (HostButton has `fill:`; null is paper; lit is focus) · packages/party_host/test/host_focus_ring_test.dart:200-225 and packages/party_host/test/pause_menu_test.dart (could break) · packages/party_host/test/support/all_looks.dart · owner decision (plan item 9e): Resume in one colour, default `good`.
changes: resume fill good (a style argument; no symbol, string or key changes)
turns: 35
expected-min: 20
do:
1 Tests FIRST, new file packages/party_host/test/pause_resume_colour_test.dart: show the pause card (pump the pause menu widget the way pause_menu_test does) in the menu look and the TV look (pumpHostLook); the button `pauseResume` has a resting background of look.colors.good; `pauseQuit` stays paper.
2 pause_menu_widgets.dart: pass `fill: ToyLookScope.of(context).colors.good` to the pauseResume HostButton. A lit Resume still takes the focus fill.
3 Fix pinned tests that break (host_focus_ring_test, pause_menu_test): grep for 'pauseResume' first.
4 Before finishing run `dart analyze` on the files you changed and fix every info.
allow: packages/party_host/lib/src/ui/pause_menu_widgets.dart · packages/party_host/test/pause_resume_colour_test.dart · packages/party_host/test/host_focus_ring_test.dart · packages/party_host/test/pause_menu_test.dart
check: format analyze
report: docs/briefs/m16/wave2-789/n9e-report.md
