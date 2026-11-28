## Summary
Split `frame_probe.dart` into one public type per file, and made `CityFrameHook` call `setState` only when the summary text changes. The `window` doc now says the oldest frames are dropped first. Tests: `tools/mine.sh` OK, 12 tests in party_host pass after the change. The new rebuild test fails on the old hook (checked with `flutter test --plain-name`), so it is a real red-first test.

Changes:
- `frame_stats.dart` (new): `FrameStats`, doc kept.
- `city_frame_hook.dart` (new): `CityFrameHook` and its State, plus `_microsPerMs`, which only the hook uses. `_record` adds the frames, builds the summary, and calls `setState` only when it differs from `_shown`. `_shown` starts as the summary of an empty probe, so the first paint matches the old one.
- `frame_probe.dart`: keeps `FrameProbe` and its three constants; imports `frame_stats.dart`; no re-export. The `window` doc now reads "Once the window is full, the oldest frames are dropped first."
- `city_frame_test.dart`: imports `city_frame_hook.dart` and `frame_probe.dart`; adds the test "frames that leave the shown text unchanged do not rebuild the hook".

Decisions:
- Test imports: the brief lists three files, but the test uses no name from `frame_stats.dart`, so the analyzer would flag it as an unused import. I imported the two it uses.
- Rebuild counting: `debugOnRebuildDirtyWidget` (a Flutter debug hook), set in the test and restored in teardown. A wrapper widget cannot count the hook's own rebuilds, because the child is the same widget instance and is skipped on rebuild.
- The new test sits in `city_frame_test.dart`, as the brief names it. The worker rule says new tests go in a new file; I followed the brief.

Test values (the 10 ms frames are the test's input):
- One 10 ms frame: avg 10.0 ms, p95 10.0 ms, dropped 0. This changes the text from the zero summary, so it rebuilds.
- Three more 10 ms frames: the same text, so no rebuild. Test expects the rebuild count to stay at its value after the first frame.
- Old hook, red run: `Expected: length <2>, Actual: length 3`. The count is not one per frame in this harness; the first frame gave 2 callbacks. I did not dig further.

## Self-check (docs/review-rules.md part A)
1. Host setups: the hook is not mounted on any host. `dispose cancels the stream subscription` and the stream test cover the injected path; the scheduler path is unchanged.
2. Kept state: `_shown` starts at the empty summary and changes only in `_record`; `dispose` still cancels the subscription (existing test).
3. Combinations (pause, away, get ready, dropped link, results, leaving): not applicable; nothing mounts the hook.
4. Stayed inside `allow:`: yes; four files, no others touched.
5. Stops: none.
6. Looks: the text style is unchanged (`labelSmall` from the theme). Existing tests run the hook at 1920x1080 and 360x640. Not checked under both the menu and TV looks; the style did not change.

## Checks
- `tools/mine.sh`, first run (red, after adding the test): fail on the test-file compile error (analyzer: the callback takes `(Element, bool)`). Fixed.
- `tools/mine.sh`, second run (red): fail on the new test only, as intended.
- `flutter test ... --plain-name "frames that leave"` on the old hook: fail, `Expected length <2>, Actual length 3`.
- `tools/mine.sh`, final run: OK, 4 files formatted, 1 package analyzed, 12 tests pass in party_host.

## Hand-over
- The hook still has no mount, so the new rebuild rule has no effect on a device yet.
- Open question: the old hook's red count of 3 (see Test values). Whether the test's count is clean enough to trust as a regression guard.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

party_host: split frame_probe.dart, hook rebuilds only on text change

Split FrameStats and CityFrameHook out of frame_probe.dart so each
file holds one public type (review must-fix). CityFrameHook now calls
setState only when its summary text changes, so frames that leave the
shown numbers as they were do not rebuild it. Reworded the FrameProbe
window doc: the oldest frames are dropped first once the window is full.
Added a rebuild test that fails on the old always-setState hook.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

map2b f1: frame_probe.dart split into frame_probe, frame_stats and city_frame_hook; hook rebuilds only when its text changes (red-first test); open: the hook is still not mounted, and the test's rebuild count is not one per frame (not dug into).

## Delete
- none
