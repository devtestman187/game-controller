# M12 step 3b — G1 report (plan only, no code)

**Status: done, stopped at G1.** The plan is `docs/briefs/m12/s3b-g1-plan.md` (242 lines, limit 250). No file outside
the two allowed ones was touched.

## What I read

- `docs/briefs/m12/s3b-g1.md`, `docs/coding-guidelines.md`, `docs/design/m12-sessions.md` (§0, §3, §4, §5),
  `docs/briefs/m12/s3-g0-survey.md` (answers 1–6, 10, 11, Conflicts), the keep-in-mind parts of
  `docs/project-notes.md`, `docs/briefs/m12/STATUS.md`, and `s3a-g2-report.md` Q6 (the size test).
- Arena: `test_game/lib/src/{arena,arena_view}.dart`, `test/arena_view_test.dart`; Shape Race:
  `puzzle_game/lib/src/{play_view,match,snapshot,settings,view,library,game}.dart`, `test/view_test.dart`,
  `rules_test.dart:501-520`, `match_test.dart:1013-1072`.
- Screens and their tests: `party_host/lib/src/ui/{game_screen,puzzle_screen}.dart`,
  `test/{game_screen,puzzle_screen,puzzle_results,pause_menu,games_screen}_test.dart`, `test/support/host_harness.dart`,
  `tv_test_app/test/keyboard_player_test.dart`.
- s3a's landed surface: `connection/lib/src/{game_host,memory_game_host,game_types,server_game_host}.dart`,
  `connection.dart`, `protocol/lib/src/{view,codec}.dart`; `pubspec.yaml`, `tools/check.sh`, the sibling pubspecs and
  `analysis_options.yaml` files.

## Files changed

- `docs/briefs/m12/s3b-g1-plan.md` — new: the plan, the brief's sections 1–8.
- `docs/briefs/m12/s3b-g1-report.md` — this report.

## Computed values (please check these against the rules)

**Steps from 16 ms pumps.** `steps(n) = floor(0.96 n)` because `1/60 = 0.0166667 s`. Today the same run is `n`
updates of 0.016 s, so the simulated time is up to 1 % shorter (a whole step at most).

| Pumps | Steps now | Simulated | Today | Advances with no step |
| --- | --- | --- | --- | --- |
| 60 | 57 | 0.950 s | 0.960 s | 1, 26, 51 |
| 90 | 86 | 1.433 s | 1.440 s | 1, 26, 51, 76 |
| 30 | 28 | 0.467 s | 0.480 s | 1, 26 |
| 63 (paused) | 0 | – | – | all |

**Frames at the three rates**, over those 57 steps (unit test, fake clock):

| `frameRateHz` | Interval | Frames | Rule |
| --- | --- | --- | --- |
| 60 | 16.667 ms | 57 | every step (`k` rises by 1) |
| 30 | 33.333 ms | 29 | steps 1, 3, 5, …, 57 |
| 20 | 50 ms | 19 | steps 1, 4, 7, …, 55 |

Comparing in doubles matters: with int `atMs` the 60 Hz case gives 29, because 17 → 33 < 33.667 skips a frame.

**`at` inside one advance.** `advance` of 100 ms with `host.nowMs` 100 runs 6 steps; their `atMs` are 17, 33, 50, 67,
83, 100 (back to front), gaps 16/17 ms. A 2 s advance is clamped to 0.1 s → 6 steps with `atMs` 1917…2000.

**Arena values from the rules (unchanged by the move):** field 960×540, `unit` 540, speed 0.55 × 540 = 297 px/s,
`playerRadius` 0.032 × 540 = 17.28 px. Walking left from x 67.2 to the 17.28 clamp is 49.92 px = 0.168 s = step 11
(today update 11); the goal (inflated left edge 0.851) is 750 px = 2.52 s ≈ step 152 → the 400-pump loop exits at
about pump 159 (today 158), well inside the cap.

**The 4-player frame size.** The real boat board is 6 pieces (`puzzles/boat.json`), two boards and 4 players:
about 240 bytes a board, 490 a `MatchSnapshot`, and a `FrameMessage` (n, at, snd, 4 acks, 4-name roster) adds about
200–250 → roughly **700–750 bytes**, against the 2500-byte budget. It is an estimate; the test prints the measured
length (s3a's synthetic 20-piece frame was 2011).

**Test counts.** No test is added to or removed from an existing file: `view_test` 7, `arena_view_test` 10,
`game_screen_test` 6, `puzzle_results_test` 4, `puzzle_screen_test` 2, `pause_menu_test` 2, `games_screen_test` 1,
`keyboard_player_test` 1 all keep their counts (the plan's §5 table says what each may assert differently: none).

**Estimated file sizes** (plan §1, §2): every new file is under 300 by estimate; the largest are
`game_kit/test/session_test.dart` (~270), `arena_snapshot.dart` (~270) and `puzzle_report.dart` (~80). After the
moves: `arena.dart` 695 → ~489, `arena_view.dart` 451 → ~180, `play_view.dart` 340 → ~110, `snapshot.dart` 189 → ~265;
`game.dart` (732) and `view.dart` (439) are not touched.

## Not sure about

- **The step counts are computed from the accumulator, not run.** The parts I would re-check first at G3: the first
  advance (elapsed 0 → no step) and the exact frame counts in the 60/30/20 Hz tests.
- **The frame-size estimate** (700–750) is arithmetic from the field widths, not a measurement.
- **`arena.dart` after the move is ~489**, still over the 400 hard limit (it is 695 today). The move shrinks it as the
  brief asks, and the leftover is tech debt like the other over-400 files; a later split of `ArenaGame`'s round rules
  from the field geometry is the obvious seam.
- **The `at` "back to front" ordering** assumes a step's `at` is `nowMs − accumulator` after that step, as §3 says;
  if the session instead took `nowMs` once per step, the values would drift.

## Suggestions

1. The `GameSession` input latch (§6 R1) is the one piece of behaviour the contract doesn't spell out. If it is
   rejected, the alternative is to accept that a one-frame press can be lost on a host that doesn't hold presses, and
   then the view tests need MemoryGameHost to mimic `ServerGameHost`'s 50 ms hold.
2. `HostingSettings` could carry `lateFrameMs`/`stallS` (section 4 of m12.md's list is "added by the steps that use
   them"), which would keep the views from having a second place to tune; I left them as `GameSession` constants
   because the contract's field list is fixed.
3. `arena_session.dart` will hold `arenaGame` and `arenaLayout`; `party_host/lib/src/session_recorder.dart:8` already
   duplicates `'arena'` as `arenaGameName` — worth merging in a later cleanup (not this job).
4. The frame size test could also check a one-board match, so the 2500 budget is covered for both shapes.

## Checks run

- `wc -l docs/briefs/m12/s3b-g1-plan.md` → 242 (limit 250).
- Every `file:line` in the plan was re-checked with `grep`/`sed` against the working tree (e.g. `arena_view.dart`
  `:56`, `:59`, `:112-115`, `:155-167`, `:220-294`, `:328-451`; `play_view.dart` `:145-147`, `:171-174`, `:195-203`,
  `:216-246`, `:250-302`, `:305-335`; `game.dart:315`, `arena.dart:334`, `snapshot.dart:161`, `arena.dart:578`).
- Every path the plan links to exists (`s3b-g1.md`, `m12-sessions.md`, `s3-g0-survey.md`, `coding-guidelines.md`).
- No code was changed, so no `dart format`, `analyze` or test run applies to this gate.
- `git status --porcelain`: only `docs/briefs/m12/s3b-g1-plan.md` and `s3b-g1-report.md` are new from this job. The
  three dirty `tv_test_app/windows/flutter/generated_plugin*` files were written at 00:09:24, before I touched
  anything (I ran no `flutter` command); left alone.

## Commit message

```
Plan the M12 sessions, thin views and game modules

The G1 plan for step 3b: a new game_kit package (GameSession, the module,
viewer, snapshot and registry interfaces, the hosting settings and the kit
check), the move map of both views' ticks into ArenaSession and
PuzzleSession with the new file each piece goes to, the fixed-step timing
and frame schedule, both modules with the puzzle setup and every
snapshot's lerpTo table, the test map with the step counts each pumped
test now sees, the behaviour risks and their mitigations, eight questions
for Claude, and the G3/G4 split. No code changes.
```

## Status row

| 3 Sessions, frames, playout, stages | s3b G1 plan done ([s3b-g1-plan.md](s3b-g1-plan.md), 242 lines): game_kit files, both tick move maps, timing and frame schedule, modules and `lerpTo`, the test map (no expected values change), 8 open questions. Next: G3 = game_kit + the Arena |

## Delete

- none
