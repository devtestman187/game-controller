# night2d report (inline batch, no runner)
Base efa5a8a9, code commit 13cf65e0 (text). Range efa5a8a9..tip (tip named in STATUS and the hand-back). Wall time about 25 min.

## 1 Text (committed, 13cf65e0)
The tv-word guard (tools/tv-word-check.sh, run by tools/tests/tv-word-test.sh) forbids a bare "TV" in user text, so "the TV" became "the screen". Final string, exact:
"This phone and the screen have different versions of Thumb Party. Update the Thumb Party app on this phone and on the screen, so both are the same version."
Length under 200 (test pins it). Files: packages/party_host/lib/src/text/phone_text.dart, packages/party_host/test/phone_text_test.dart. tv-word-test 21/21, phone_text_test green, analyze clean. Release notes: no change (night2c's notes already list "Clearer update the app message"). Owner can choose "the TV" only by changing the guard.

## 2 Proof (no commit)
Test: packages/party_host/test/night_pick_test.dart:236 (assert at :256). Change: in night_pick_provider.dart _votePick, replaced `ref.read(nightVoteProvider.notifier).takeResult(round)?.variant ??` with `null ??` (sed), then:
- `flutter test test/night_pick_test.dart --plain-name "the vote picker plays the game"` FAILED: "Expected: Variant:<bumperRound:toy-factory> Actual: Variant:<bumperRound:pinball>" at test\night_pick_test.dart 256:7.
- `git checkout packages/party_host/lib/src/night/night_pick_provider.dart` restored it; `flutter test test/night_pick_test.dart` then "+19: All tests passed!"; git status showed no diff. No new test needed. Caveat: the failure relies on the test's random seed; the fallback pick differed.

## 3 Notes
Owner answers recorded in docs/briefs/m17/night2c/REVIEW.md ("Owner answers (Nov 27)"); R7 note in docs/code-health.md "night2d notes". mine.sh untouched.

## 4 M17a coverage baseline (tools/coverage.sh at 13cf65e0)
TOTAL 93.3 % (23327 / 24990 lines). controller_app 93.7, tv_test_app 92.0, connection 92.5, game_kit 96.4, metrics 98.5, party_host 90.7, protocol 92.1, puzzle_game 95.9, test_game 96.9, toy_look 88.1. assets: no coverage.
coverage.sh exit 1: one flaky test in packages/connection, choice_round_test.dart "inProcess a shop round: a player away past the grace has the Save +2 default set and can pick again before the end" (Expected {phone-1}, actual {phone-1, phone-2}); it ran while the machine was loaded and the same suite passed 491/491 in the full check. Unexplained, a timing flake candidate; open item (code-health not yet written). The coverage script rewrites tracked coverage_all_test.dart files; restored with git checkout.

## Check
tools/check.sh: All checks passed (426s, 1 cached), rc=0 (check.log).

## Findings / REVIEW counts
night2c REVIEW open: must 1 -> now proved closed; should 10, could 10 (owner questions answered above). night2d adds no findings.
Proposed lessons: 0. Hand-fixes: none (no runner). Fixed, unverified: none (text only; check on device at BP2).

## Cost
  0.9451     21 main transcripts                         opus $0.9451 rows sum $2.3049 driver: calls 21, largest context 141789 tokens, longest wait 13 min 
Driver calls: ~30; waiters: thumb-haiku 13 + 11, thumb-wait 3 calls (plus 1 haiku wait).

## Process sweep
proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)
no background command of mine is still running
