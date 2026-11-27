# night2a f2 report: one public type per file for the three pickers

## Summary

- Split `night_pickers.dart` (three public types) into one type per file under `packages/party_host/lib/src/night/`: `shuffle_picker.dart` (ShufflePicker), `playlist_picker.dart` (PlaylistPicker), `rotating_chooser.dart` (RotatingChooser). Each file keeps its own imports and dartdoc, copied verbatim.
- `night_pickers.dart` now holds one plain `//` comment line and three `export` lines. No importer changed; the test still imports `night_pickers.dart`.
- `RotatingChooser` dartdoc now says "in the order of `playerIds`" (was "in the order the players joined").
- `night_pickers_test.dart`: the three `played.add(next!)` lines now follow an explicit `if (next == null) fail('no pick');` and use the promoted `next`. Added one test: ten draws in a row from the four-variant pool, checking no repeat while fewer than four distinct variants have been played, and that the first four draws cover the pool.
- Baseline before the move: `flutter test packages/party_host/test/night_pickers_test.dart`, 13 tests, all passed.
- After the change: `tools/mine.sh` reports 5 files formatted, party_host analyzed with no findings, 14 tests passed (13 old + 1 new).
- Pure refactor: tests-first exempt (move with no behaviour change; the existing tests prove it before and after).

Decisions:
1. Library comment is `//`, not `///`. A `///` comment above `export` directives triggered `dangling_library_doc_comments`; a `library;` directive would also work but adds a line the brief did not ask for.
2. The `!` on `played.add(next!)` in the `generate` helper (old test line 56) had no `expect` before it. The review finding named it, so I fixed it the same way. The brief's item 3a only names the ones after an `expect`.
3. The ten-draw test checks "no repeat until all four were played" as the rule is documented on `ShufflePicker.next`: while fewer than four distinct variants have been played, the draw is not in `played`. After the first four draws the implementation only avoids the last variant, so the test does not assert no-repeat over draws five to ten.
4. `probe-f2.patch` was not applied. It adds three stub files (`*Probe` classes) that would collide with the real files I wrote; I read it as the runner's probe, not as a change for this job.

## Self-check (review-rules part A)

1. Host setups: not applicable to the change itself (no UI or host wiring); the picker logic is host-independent. Shown by: the existing 13 tests plus the new ten-draw test pass in `night_pickers_test.dart`.
2. Kept state: the pickers hold no state (const classes; `played` and `playerIds` come from the caller). Nothing starts or ends. Shown by: the existing tests, unchanged in behaviour.
3. Combinations with pause menu, host away, player away, "Get ready", dropped link, results, leaving: not applicable; no provider or UI touched.
4. Folder and allow: all changed files are inside the listed `allow:` set plus the report.
5. Stop: no stop needed; no file outside `allow:` needed changing.
6. Looks: not applicable; no widget changed.

## Computed test values

- Baseline: 13 tests passed on the untouched file.
- After: 14 tests passed (`tools/mine.sh`).
- The new test uses `Random(7)` and the existing `_pool` of four variants. I did not print the draw sequence, so the report has no seed-specific draw values; its expectations are structural (no repeat before four distinct, first four cover the pool).

## Hand-over

Files changed:
- `packages/party_host/lib/src/night/night_pickers.dart`: now only a `//` comment and three `export` lines.
- `packages/party_host/lib/src/night/shuffle_picker.dart`: new; ShufflePicker moved here with its imports and dartdoc.
- `packages/party_host/lib/src/night/playlist_picker.dart`: new; PlaylistPicker moved here with its imports and dartdoc.
- `packages/party_host/lib/src/night/rotating_chooser.dart`: new; RotatingChooser moved here, dartdoc says "in the order of `playerIds`".
- `packages/party_host/test/night_pickers_test.dart`: explicit null checks in three helpers; one new ten-draw test.
- `docs/briefs/m17/night2a/f2-report.md`: this report.

Checks:
- `flutter test packages/party_host/test/night_pickers_test.dart` on base: 13 passed.
- `tools/mine.sh`: first run failed on one analyzer info (`dangling_library_doc_comments` on `night_pickers.dart:1`); fixed; second run OK (5 files formatted, party_host analyzed, 14 tests passed).

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

night2a f2: one public type per file for the three pickers

Split ShufflePicker, PlaylistPicker and RotatingChooser out of night_pickers.dart
into their own files under night/, so each file has one public type (guidelines §3).
night_pickers.dart now only re-exports them, so importers are unchanged.
RotatingChooser's doc says the order is that of playerIds, not the join order.
The test drops the bang on played.add(next!) and adds a ten-draw no-repeat test.
No behaviour change: the 13 existing tests pass before and after.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2a f2 (done): the three pickers each have their own file (one public type per file), night_pickers.dart re-exports them, the ten-draw no-repeat test is added, party_host tests pass (14). Open: the lib file-size and other wave-2 findings are untouched here.

## Delete

- none

## Questions

1. The review's `d2d` and other wave-2 findings on `night_director.dart` are outside this job; were they meant to go in a separate job?
2. Should `probe-f2.patch` be applied by the runner as a probe, or was it meant for this job? I did not apply it because it adds stub files with the same names as the new ones.
3. The "no repeat until all four were played" wording: if you meant no repeat over the second pass too, that is a behaviour change in `ShufflePicker` (it currently only avoids the last variant after the first full pass) and needs a design decision, not a test.
