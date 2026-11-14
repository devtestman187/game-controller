# M14 cleanup1 — review of the run

## Summary

Verdict: **one fix batch**. The run changes no behaviour (one typing/guard change, one test seam, one `@visibleForTesting`, two constants, one test swap, docs); what is open is evidence and nits.
Counts: must 1 · should 2 · could 8.
The five that matter most:
1. The new board-cache test is on record as passing on the job's base tree (`run-findings.md:1`); the run's own new batch rule 1 (`docs/flash-framework.md:78`) says only runner evidence counts, so this is the batch's one open must.
2. `sound_loop.dart` now holds three public types in 298 lines (seam plus adapter), against the guidelines' one-public-type and ~300-line rules; the next sound change has no room.
3. c2's self-check claims the cache "ends on `dispose`" and there is no dispose anywhere on that path.
4. The `!` in `game_screen.dart:354` (`_result!`) survived a job whose point was removing exactly that shape beside a guard.
5. The protect test's effect case cannot fail for any change to `SoundLoop`, so its name claims coverage it has not got.
No fix in this run changes behaviour, so no tracker row needs "Fixed, unverified: needs device check"; B-004's loop protection keeps the one the STATUS already carries. The owner questions are those already open there, unchanged.

## Findings

- **must** docs/briefs/m14/cleanup1/run-findings.md:1 `board_cache_state_test` is logged as passing on the code the job started from, so the committed test proves nothing about the key's hint, ready or glow fields by itself → have Claude redo the key-removal check (the worker's was uncommitted) or close the line under c2's written `tests-first: exempt`, and say which (from: c2-board review).
- **should** packages/party_host/lib/src/sound_loop.dart:227 the seam added `LoopAudioEngine` and `SoLoudLoopEngine` as two more public types in a 298-line file, against guideline §3's one public type per file and the ~300-line limit → move the interface and adapter to `src/audio_engine.dart` or record the exception in `docs/code-health.md` in this batch (from: c3-sound review, across jobs).
- **should** docs/briefs/m14/cleanup1/c2-board-report.md:67 self-check A2 says the cache "ends on `dispose`", but `view.dart` has no `dispose` override and `board_cache.dart` has no dispose method → say the cache lives as long as the view's `State` (or add the dispose, which no brief asked for) (from: c2-board review).
- **could** packages/puzzle_game/lib/src/board_hud.dart:85 the board's bar still insets its fill with a bare `_barHeight / 4` while the same inset is now `_barFillInsetShare` in the same library (`phone_hud.dart:78`) → use `_barHeight * _barFillInsetShare` (from: c2-board review).
- **could** packages/puzzle_game/lib/src/phone_hud.dart:65 `_clock` still divides by a bare `1000` while the same library defines `_msPerSecond` (`board_hud.dart:17`) → use `_msPerSecond` (from: c2-board review).
- **could** packages/puzzle_game/test/board_cache_state_test.dart:37 the test's body runs lines 38-99 (62 lines), over the brief's "no function over 60 lines" → move the `draw` closure and the board helpers to top-level functions in the same file (from: c2-board review).
- **could** packages/party_host/lib/src/ui/game_screen.dart:354 `_result!` has no proof on the line before it (guideline §2 type escapes); only the arm and `_stage` prove it indirectly → guard it with the same local-and-return shape c1 used for `_game` (from: c1-screen review).
- **could** packages/party_host/test/sound_loop_protect_test.dart:87 the "an effect playing alongside the loop is not protected" test cannot fail: the fake records only calls `SoundLoop` makes, and the loop never receives the effect's handle → keep it only as a named statement of the seam's contract (rename) or drop it and its `startEffect` helper (from: c3-sound review).
- **could** docs/briefs/m14/cleanup1/c1-screen-report.md:21 the size claim "`_stageBody` about 34 lines" is 38 by count (`game_screen.dart:329-366`) → correct it if the figure is quoted anywhere (from: c1-screen review).
- **could** docs/briefs/m14/cleanup1/run-findings.md:2 the c4-nits review wrote no report and `flash-c4-nits-review.log` is not on disk, so the run's only docs-only job has no independent check → accept c4 on this review's own read of its three files, or re-run its review (from: run-findings).
- **could** packages/party_host/test/sound_loop_protect_test.dart:14 the test file landed in commit 3fcbb8c, where `LoopAudioEngine` does not exist (it comes in 69ebd59), so that history step does not compile → commit a job's test with its seam next time (history only; nothing to change in the tree) (from: c3-sound review).

## Open questions

1. c1's brief names `PartyNight?` from `party_night.dart`; the code uses `NightState?` from `night_state.dart` — accept the code and name the state type in future briefs.
2. The results arm now returns early for a null `_game`, so it drops `ArenaResults` where the old `_field()` dropped only the field — accept (unreachable: results are entered only after `_start`/`_again` set `_game`) and add one comment line saying so.
3. The glow's age in the still key re-records a finished board about 150 times during the 2500 ms celebration — leave it; a coarser age is a design change for its own brief, and the old code rebuilt every frame anyway.
4. The seam as an interface plus an adapter, rather than `SoLoud? engine` — confirm it as the pattern for later audio seams; it is what lets the protect test exist.
5. Keep the effect test as documentation of the seam's contract, or drop it — either is safe; renaming it "the seam never sees an effect's voice" keeps the suite honest.
6. Unify the two bars' fill inset in one constant although it now lives in `phone_hud.dart` — yes, in this batch: both files are parts of one library, so `board_hud.dart` sees `_barFillInsetShare`.
7. c2's test uses "one `BoardCache`, a painter per frame" instead of the brief's "one cached painter" — accept; `PuzzlePainter` holds its snapshot, as the review confirmed.
8. Did Claude actually see the key-removal failure the c2 brief's `tests-first` line describes — if not, run it now (two minutes) and close the must; if yes, record it in `run-findings.md` and close the line.
9. Does the new batch rule 1 bind the briefs written before it (c2 and c3 both rested on worker-run proofs) — state that it binds from the next batch, and accept c2 only under its written exemption.
10. B-004's trade-off (protecting the music voice) and the loop check under load remain the owner's, as `docs/briefs/m14/STATUS.md` says — no change from this run; keep both open.

## Numbers against targets

- `board_cache_state_test.dart` test body: 62 lines (38-99) against the brief's "no function over 60 lines" — over by 2.
- c1 report's `_stageBody` "about 34" against 38 measured (`game_screen.dart:329-366`) — figure wrong; the 60-line limit is met either way.
- `sound_loop.dart` 298 lines against the guideline's ~300 — at the edge, 2 lines of room; the briefs' 380-line stop was met.
- `game_screen.dart` 370 lines against c1's 380 brief limit — met; against the guideline's ~300 it is past, and `docs/code-health.md` has no size row for it (the file grew 5 lines in this run).
- c4's premise "over-long line" measured 103 columns against the brief's 120 — the premise was wrong, the re-wrap to the doc's ~80 is harmless.
- `arena_piece_painter.dart` 294, `docs/code-health.md` 104, `board_cache.dart` 204, `board_hud.dart` 89, `phone_hud.dart` 232 — all inside their limits.
- Quoted suite totals (host 402, puzzle 403, arena 219) were not re-measured here and no brief sets a target for them; c1's 399 and the reviews' 402 are consistent (c3's 3 tests landed in the same commit).

## Could not check

- I ran no suite and no `tools/check.sh`; every test total above is the reports'.
- The worker's uncommitted `StaticBoardKey` edit and its failing output: not in the tree, and reproducing it means changing code, which this review does not do.
- Whether the c2 test would fail on the pre-95da0ac code (a checkout or edit).
- c4's independent review: no report was written and `docs/briefs/m14/cleanup1/flash-c4-nits-review.log` is not on disk.
- The owner's tracker rows and the B-004 device behaviour.
- The dirty `tv_test_app/windows/flutter/generated_plugin*` files and PNGs in `git status`: they predate the run and were left alone.

## Commit message

Review the cleanup1 run: one must, two shoulds, eight coulds

The run changes no behaviour: a typed stage body with the old null guard,
a SoundLoop engine seam with a protect test, @visibleForTesting on the
cache's onRecord, two named constants and a real cache-state test. The
batch's one must is that test's evidence: run-findings records it passing
on the job's base tree, and the run's own new tests-first rule wants
runner proof. Two shoulds: the seam's two extra public types in a 298-line
file, and c2's self-check claiming a dispose that does not exist. The rest
are nits in the same files: two bare numbers, a 62-line test body, _result!,
a test that cannot fail, and a size figure that is wrong.

## Status row

M14 cleanup1 run reviewed: one fix batch (1 must — c2's test proof; 2 should; 8 could), no behaviour change; open: B-004's trade-off and its device check.

## Delete

- none
