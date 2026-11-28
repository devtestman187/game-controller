# map2b f3 report: shared board, size and wait helpers for the city/art tests

## Summary

- New shared test helper `city_art_support.dart`: `boardFor(players)`, `standardBoard()` (8 districts), `tvSize`, `phonePortrait`, `standardDistricts`, `untilBuiltTimeout` (5 s), and `untilBuilt(tester, cache, size, trigger)`.
- `untilBuilt` returns at once when the image at `size` is already built; otherwise it listens, runs `trigger`, and waits. A build that does not finish within 5 s fails the test with `the static image at <size> was not built within 0:00:05.000000`.
- `city_frame_test.dart`: its `_standardBoard`, `_untilBuilt`, `_tvSize` and `_phonePortrait` duplicates are deleted; it imports the helper. Its tests are unchanged.
- `city_map_view_test.dart`: its `_boardFor`, `_untilImageBuilt` (with its own copy of the wait and timeout), `_tvSize`, `_phonePortrait`, `_imageBuildTimeout` and `dart:async` import are deleted; `_pump` calls `untilBuilt`. Its tests are unchanged.
- No lib file changed. Review findings 4 (duplicate board helper) and the test part of 9 (wait with no timeout) are addressed. The unbounded-size item in the lib is not touched.
- Checks: `tools/mine.sh` OK, 24 tests in packages/party_host passed, 3 files formatted, analyze clean. `dart format` reported 0 changed. A line-length and TODO/print/BISECT grep over the three files found nothing.
- Test counts before and after: I did not count them separately; mine.sh ran 24 tests in total for the package-level touched set.

## Decisions

- `untilBuilt` takes the size as a parameter so the map view can keep its "already built, return at once" check. The frame test passes `tvSize`, which is safe because its cache is new for each test.
- The map view's trigger is an empty lambda: the view requests its image during `pumpHostLook`, so the helper only waits. A one-line comment in `_pump` says so.
- The timeout is a `TestFailure` thrown from `Future.timeout`'s `onTimeout`, so the message names the size and the limit, not a generic `TimeoutException`.

## Self-check (docs/review-rules.md part A)

1. Host setups: not affected; test helpers only. Covered by the unchanged tests in both files, run by mine.sh.
2. Kept state: the helper keeps no state; the listener is removed in `finally`. Covered by mine.sh (frame and map view tests).
3. Combinations: not affected by this change.
4. Folder and allow: only the four files in allow are changed.
5. Stop rather than overstep: none needed.
6. Every look: unchanged tests still run every look via `forEachLook` and every size in the map view test; no look-sized widget was changed.

## Questions

1. The 5 s timeout path has no test of its own. A test that never builds would wait 5 s in the real run, so a fake cache or a shorter injected timeout would be needed. Do you want that in a later job?
2. `untilBuilt` takes `size` as a fourth parameter. Is that OK, or should the frame test pass a size it does not need?

## Suggestions

- The `_eightPlayers` constant in city_map_view_test.dart duplicates `standardDistricts`. It was left as is because it names the test's own count; merging them is a small follow-up.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

test: share the city art board and wait helpers in one test file

Move the eight-district board builder, the TV and phone-portrait sizes and
the image wait into city_art_support.dart. city_frame_test.dart and
city_map_view_test.dart drop their duplicates. The wait now fails the test
after 5 s with a message instead of hanging when the static image never builds.
No behaviour of the existing tests changes.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

map2b f3 done: shared city art test helper (boards, sizes, untilBuilt with a 5 s timeout) used by both city art tests; open: a test for the timeout path, and the unbounded-size item in city_map_view.dart (lib, not in this job).

## Delete

- none
