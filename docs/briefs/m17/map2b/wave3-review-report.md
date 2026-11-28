# map2b wave3 review: f3 (shared city art test helper)

## Summary

small fixes
Counts: must 0 · should 3 · could 4
1. The report says review findings 4 and 9 are addressed; the same board and wait copies remain in three other test files.
2. The new timeout branch, the only new behaviour, has no test; "the existing tests are the proof" cannot reach it.
3. `untilBuilt` takes four arguments; f3.md:10 specifies three, and the job went on without stopping.

## Findings

- **should** docs/briefs/m17/map2b/f3-report.md:9 "Review findings 4 … and the test part of 9 … are addressed" is not true: packages/party_host/test/city/art/city_painter_test.dart:89 still has its own `_untilBuilt` with no timeout, and `_boardFor` is still copied at city_painter_test.dart:41, city_scene_test.dart:15 and city_overlay_painter_test.dart:22 → list these as open in the report and the status row, or name the job that takes them.
- **should** packages/party_host/test/city/art/city_art_support.dart:56 the timeout branch (lines 56–61) is new behaviour with no test, so the tests-first exemption rests on tests that never reach it → add a test whose trigger never builds and expects the `TestFailure`; pass the timeout in as a parameter (five parameters, the limit) so the test does not wait 5 s of real time.
- **should** packages/party_host/test/city/art/city_art_support.dart:46 `untilBuilt` has four parameters, but f3.md:10 specifies `untilBuilt(tester, cache, trigger)`; the job changed the contract and asked only in its Question 2 → Claude amends f3.md to the four-argument form, or drops `size` in a later brief.
- **could** docs/briefs/m17/map2b/f3-report.md:24 self-check 4 says "only the four files in allow are changed"; allow lists three test files, and the report is the fourth → say "the three files in allow, and this report".
- **could** packages/party_host/test/city/art/city_art_support.dart:59 the failure message prints the Duration as `0:00:05.000000` → print `${untilBuiltTimeout.inSeconds} seconds`.
- **could** packages/party_host/test/city/art/city_art_support.dart:31 `starts.take(players)` silently gives 8 districts for players above 8 and an empty board for 0; the brief says players 2–8 → assert the range in `boardFor`.
- **could** docs/briefs/m17/map2b/f3-report.md:26 says the unchanged tests run every look "via forEachLook"; only city_map_view_test.dart uses `forEachLook`, and city_frame_test.dart covers both looks through `HostLook.values` (city_frame_test.dart:221) → name each file's method.

## Decisions to confirm

- packages/party_host/test/city/art/city_art_support.dart:46: the four-argument `untilBuilt`. The size is needed for the map view's early return; confirm it, or amend f3.md. The report does not list it as a change to the brief's contract.
- packages/party_host/test/city/art/city_map_view_test.dart:51: the empty trigger means the wait relies on `pumpHostLook` having requested the image. If that stops, the test waits 5 s and fails with the timeout message (loud, not silent).
- packages/party_host/test/city/art/city_art_support.dart:57: the 5 s bound is real time, and guidelines §9 says no real time in tests. It was inherited from the old map view copy and now also applies to the frame test; the owner decides between keeping it and a fake-time bound.
- packages/party_host/test/city/art/city_art_support.dart:31: `take(players)` clamps silently. The report's Decisions do not list it.

## Could not check

- `dart analyze`, `dart format`, `tools/mine.sh` and the "24 tests passed" claim: docs/briefs/m17/map2b/run.log:57 records only "f3 finished: result 0", with no output for these checks. I did not run them, and this review changed no code.
- docs/briefs/m17/map2b/run.log:16-17 "fails on the old code" entries are dated before f3 started (05:06) and cover other jobs; run-findings.md has no f3 entries. No runner evidence exists for the f3 tests.
- packages/party_host/test/city/art/city_art_support.dart:12 `phonePortrait` doc, "the smallest portrait room the host is drawn in": not verifiable from the files I read.
- That a `TestFailure` thrown in `Future.timeout`'s `onTimeout` fails the test: not run.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

docs: wave 3 review of the f3 test helper job

Review of f3 against its brief and the guidelines: no code changed.
Findings: 0 must, 3 should, 4 could. The report overstates findings 4 and 9
(three board copies and one untimed wait remain), the timeout branch has no
test, and untilBuilt takes four arguments where the brief says three.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

map2b wave3 review of f3: small fixes (0 must, 3 should, 4 could). Open: a test for the untilBuilt timeout, the untilBuilt signature in f3.md, and the leftover board and wait copies in city_painter_test.dart, city_scene_test.dart and city_overlay_painter_test.dart.

## Delete

- none