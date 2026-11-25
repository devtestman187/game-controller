# c3 report: volume slider test pins the semantic formatter

## Summary

- Changed `packages/party_host/test/volume_semantics_test.dart`: inside the existing `forEachLook` loop (menu and TV look), for each of `soundVolume` and `musicVolume` the test now reads the `Slider` widget's `semanticFormatterCallback`, asserts it is not null, and asserts that calling it with 0, 30 and 100 returns `HostText.percent` of those values (`0%`, `30%`, `100%`).
- No lib change. `look_and_sound_section.dart` is back to its committed state (`git diff --stat` on that file is empty).
- Mutation check (item 2): with the `semanticFormatterCallback` line deleted from `look_and_sound_section.dart`, `tools/mine.sh` FAILED both palette tests ("the Sunny palette…" and "the Night palette…"). Line restored by hand; `tools/mine.sh` then passed (OK 2 tests).
- `tools/mine.sh` on the test change with the lib intact: OK, 2 tests (the Sunny and Night palettes, each run in both looks).
- Test counts seen: 2 tests before the lib mutation and 2 after restore; the mutation run reported both failing.

## Decisions

- Restoring the lib line was done with an Edit, not `git checkout`, because the worker rules forbid git commands that change anything. The end state is the same as the committed file.
- The callback is called as `formatter?.call(...)` after `expect(formatter, isNotNull)`, so no `!` is needed.
- Per item 6 (every look): the new assertions run inside the existing loop, so they cover the menu and TV look for both palettes.
- Self-check (review-rules part A): item 1 (host setups) is not affected by this test change, which only adds slider assertions on the Sounds and Music screen. Item 2 (kept state) not affected. Item 3 (combinations with pause menu, host away, etc.) not affected. Item 4 (folder and allow-list): only the test file changed. Item 5 (stops): none needed. Item 6 (every look): covered as above; no fixed pixel height added.

## Questions

1. The mutation run failed at the first new assertion (the null check) or at the value checks; I did not separate the old assertion on its own. REVIEW.md:117 says the original reads-the-percentage test passes on the old code because Flutter's default formatter also reads the percentage. That is not verified here, and the new assertions are what pin the callback itself.
2. Should the callback also be checked for the phone and TV "Play on this phone" setups? The brief scopes this to the slider only, so I did not add them.

## Suggestion

- A shared helper for the "callback returns percent" check would remove the duplicated loop if more volume sliders are added. Not done: one caller today.

## Commit message — a draft

Pin the volume slider's spoken-value formatter in the test

The volume test passed on the old code because Flutter's default slider
formatter also reads the percentage on a 0-100 range. Inside the existing
per-look loop, the test now checks that each Sounds and Music slider has
its own semanticFormatterCallback and that it speaks 0%, 30% and 100%.
Removing the callback from look_and_sound_section.dart now fails both
palette tests. No lib change.

## Status row

c3 done: volume semantics test now pins the slider's semanticFormatterCallback (0/30/100 percent) in both looks; mutation check fails without it, passes with it. Open: confirm the old assertion alone passes on the old code (REVIEW.md:117, not separately run).

## Delete

- none

## Hand-over

- Files changed: `packages/party_host/test/volume_semantics_test.dart` (new assertions); `docs/briefs/m16/close/c3-report.md` (this report).
- Checks: `tools/mine.sh` PASS (format, analyze, 2 tests) with lib intact; mutation FAIL as expected; restored, `tools/mine.sh` PASS again.
