job: M14 bugs11 b021-fix-phone-test: two could-fixes in the lone-night phone test, and a comment
pub: no
stop: after it.
read: packages/party_host/test/arena_touch_solo_night_test.dart · packages/party_host/test/arena_touch_ready_test.dart (`setUpAll(loadLookFonts)` at line 19) · packages/party_host/test/solo_arena_card_test.dart (lines 59-62) · packages/party_host/lib/src/ui/night_start_screen.dart (line 74)
decide: low-usage mode: never stop for a question. Make the safest choice that fits and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
tests-first: exempt test-only hardening of behaviour that already works, plus a comment

1 `arena_touch_solo_night_test.dart:40`: after the one-second pump also expect `arenaWaitingCard` to still be there (as solo_arena_card_test.dart:61-62 does).
2 Same file: import support/toy_fonts.dart and add `setUpAll(loadLookFonts);` as arena_touch_ready_test.dart does.
3 `night_start_screen.dart:74`: the comment says "as Shape Race's join screen does for two"; say "for two or more".
in the report: `## Summary` (8 lines max).
rules: aim for 30-60 turns · write only inside allow: · stage nothing yourself · never use git add -A
allow: packages/party_host/test/arena_touch_solo_night_test.dart · packages/party_host/lib/src/ui/night_start_screen.dart · docs/briefs/m14/bugs11/b021-fix-phone-test-report.md
check: format analyze host
report: docs/briefs/m14/bugs11/b021-fix-phone-test-report.md
