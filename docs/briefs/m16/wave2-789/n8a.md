job: wave2-789 n8a — item 8 contract: Home roles, anchors, highlight rule, showTips flag, strings
stop: No screen, no routing, no settings row, no consent change. New files only.
read: docs/briefs/templates/COMMON.md · controller_app/lib/src/providers/controls.dart:1-22 (saved-setting provider pattern) · controller_app/lib/src/providers/device.dart:10-20 (prefsProvider) · docs/briefs/m16/wave2-789/JOBS.md (the contract paragraph) · docs/briefs/m16/ux-review/APP-START.md:36-60 · owner decisions: marks 1-3 texts and the three role names as in APP-START; Q3 A: a missing saved key means show the tips.
changes: HomeRole · HomeFind · HomeAnchors · highlightedRole · showTipsProvider · ShowTipsNotifier · HomeText
turns: 35
expected-min: 20
do:
1 controller_app/lib/src/home/home_contract.dart: `enum HomeRole { join, play, display }` (declaration order is the fixed button order); `enum HomeFind { searching, found, none }`; `HomeRole? highlightedRole(HomeFind)` (found -> join, none -> play, searching -> null); `class HomeAnchors` with three final GlobalKey fields join, play, display, created in its constructor; a doc comment that states the contract paragraph of JOBS.md (navigation, Back, marks idle rule, consent entry points).
2 controller_app/lib/src/home/home_prefs.dart: key 'showTips'; `showTipsProvider` NotifierProvider<ShowTipsNotifier,bool>, build reads prefsProvider getBool('showTips') ?? true; `set(bool)` saves. Same pattern as controls.dart.
3 controller_app/lib/src/home/home_text.dart: `abstract final class HomeText` const strings: joinGame 'Join a Game', playHere 'Play here', displayHere 'Display here', foundNearby 'Found nearby', noScreenFound 'No screen found', searchAgain 'Search again', tapToAddName 'Tap to add your name', settings 'Settings', showTips 'Show tips', skip 'Skip', next 'Next', done 'Got it', tipJoin "Join a friend's game", tipPlay 'Play on this screen or host a game', tipDisplay 'Create and watch the game here. Control from another screen'. No whole word "TV" in any string.
4 Tests FIRST, new files controller_app/test/home_contract_test.dart and home_prefs_test.dart: role order, highlight rule for the three finds, anchors are three distinct keys, showTips is true with no saved key, set(false) saves and reloads false. Use SharedPreferences.setMockInitialValues and a ProviderContainer with prefsProvider overridden.
5 Before finishing run `dart analyze` on the files you changed and fix every info.
allow: controller_app/lib/src/home/home_contract.dart · controller_app/lib/src/home/home_prefs.dart · controller_app/lib/src/home/home_text.dart · controller_app/test/home_contract_test.dart · controller_app/test/home_prefs_test.dart
check: format analyze
report: docs/briefs/m16/wave2-789/n8a-report.md
