# M12 step 3b — G3 report: game_kit and the Arena on a GameSession

**Status: done, stopped at G3.** `packages/game_kit` is new; the Arena runs on it; every check the brief names passes
(`tools/check.sh format analyze protocol connection metrics kit arena puzzle host phone tv`: all PASS). `puzzle_game`,
`party_host`, `tv_test_app` and `controller_app` are untouched (G4 is next; s3c gets the phone's `FrameView`).

## Files changed (line counts; **>300 flagged**, tests 500)

| File | Lines | Why |
| --- | --- | --- |
| `packages/game_kit/pubspec.yaml` | 26 | new package, `resolution: workspace`, `connection` + `protocol` (plan §1) |
| `packages/game_kit/analysis_options.yaml` | 8 | `puzzle_game`'s file verbatim (120-col formatter) |
| `packages/game_kit/lib/game_kit.dart` | 9 | exports the four source files |
| `packages/game_kit/lib/src/game_module.dart` | 44 | `GameModule`, `GameViewer`, `GameSnapshot` (+ `toJson`, `lerpTo`), `ViewContext` |
| `packages/game_kit/lib/src/game_registry.dart` | 22 | `GameRegistry([modules])`, `moduleFor`, duplicate id throws |
| `packages/game_kit/lib/src/game_session.dart` | 263 | the loop: accumulator, latch, frames, `drawn`, `dispose` |
| `packages/game_kit/lib/src/hosting_settings.dart` | 40 | `simStepS` = 1/60, `frameRateHz` 60 (20–60), `maxPlayoutFrames` 2 (0–4), `ranges` |
| `packages/game_kit/test/session_test.dart` | 167 | 11 tests (plan §5 + the latch) |
| `packages/game_kit/test/registry_test.dart` | 19 | 3 tests: by id, unknown id, duplicate id |
| `packages/game_kit/test/support/fake_game.dart` | 69 | `FakeModule`/`FakeViewer`/`FakeSnapshot`/`CounterSession` |
| `packages/test_game/lib/src/arena.dart` | **487** (was 695) | the snapshot block moved out; rules untouched; no new code |
| `packages/test_game/lib/src/arena_snapshot.dart` | 276 | 206 lines moved verbatim, then `lerpTo` (+ `implements GameSnapshot`) |
| `packages/test_game/lib/src/arena_session.dart` | 115 | `ArenaSession`; `PlayerFeed`, `feedsOf`, `arenaGame`, `arenaLayout` moved here |
| `packages/test_game/lib/src/arena_module.dart` | 44 | `arenaModule`, `arenaSetup = {}`, `ArenaViewer` |
| `packages/test_game/lib/src/arena_view_widgets.dart` | 201 | `ArenaBoard`, `ArenaField`, `ArenaHud`, `_PlayerRow`, `ArenaBanner` |
| `packages/test_game/lib/src/arena_painter.dart` | 141 | `ArenaPainter(snapshot, roster)`, moved from `arena_view.dart` |
| `packages/test_game/lib/src/arena_roster.dart` | 11 | `ArenaRoster` typedef and `arenaRosterOf` (Q5) |
| `packages/test_game/lib/src/arena_view.dart` | 74 (was 439) | thin: Ticker → `advance`, `setState`, post-frame `drawn`, `ArenaBoard` |
| `packages/test_game/lib/test_game.dart` | 10 | exports the module, session and snapshot files |
| `packages/test_game/pubspec.yaml` | 28 | `game_kit: path: ../game_kit` |
| `packages/test_game/test/arena_snapshot_test.dart` | 59 | 4 `lerpTo` tests |
| `packages/test_game/test/arena_session_test.dart` | 108 | 5 session tests |
| `pubspec.yaml` | 26 | `- packages/game_kit` after `metrics` (one line) |
| `tools/check.sh` | 117 | `kit` on the `Checks:` line and the array (after `metrics`) |
| `docs/dev-tools.md` | 404 | the `kit` row and "all eight test suites" (two lines) |
| `pubspec.lock` | – | unchanged: `game_kit` adds no new third-party dependency |
| `docs/briefs/m12/s3b-g3-report.md` | 183 | this report |

Only `arena.dart` is over 300 (and over the 400 lib limit; see *Review*). Every new lib file is ≤ 276; the longest
test file is 167.

## `packages/game_kit`

`GameSession` (contract §3) owns time, input, frames and the view. `advance(elapsed)` takes the gap from the Ticker,
clamps it to `maxCatchUpS` (0.1), samples `host.players` and `host.gamepad` **once per advance**, counts the advance
for `frames`/`late` (players only, late when the gap is over `lateFrameMs` 25 and it isn't the first), then runs
`step(simStepS)` while the accumulator holds a step, bumping `stepCount` and re-taking `current` after each.

- **The input latch (Q3)**: `_sample` adds every button in the newest sample into `_pendingButtons`;
  `input(id)` returns the newest sample with those buttons ORed in; after each step `_pendingButtons[id]` is set to a
  copy of the newest sample's buttons (a copy — `GamepadState.buttons` is an unmodifiable set, so the first version
  threw on assignment). A press seen and cleared inside one no-step advance therefore reaches exactly one step, and
  the step after it sees the release. Analogue values are always the newest sample.
- **Frames**: the first step fixes `_frameStartMs`; a step publishes when
  `k = floor((atMs - startMs + frameSlackMs) / (1000 / frameRateHz))` rises, and only while `host.hasViewers`; the
  frame carries `n = stepCount - 1`, `at = round(atMs)`, the snapshot, the sounds not yet sent, `acks` from
  `host.inputSeq` and the roster from `host.players` (`nickname ?? ''`, see Q3 below).
- **`drawn()`** reports `received_to_drawn` once per fresh input, not after a stall (`rawS > stallS` 0.1).
- **`dispose({finished})`** sends `view_end` once (`finished`/`quit`) and stops everything; `paused` sends nothing and
  resuming doesn't catch up but calls `resumed()`.

## The Arena

`ArenaView` keeps its constructor, `game` test hook and `paused`; it creates an `ArenaSession` in `initState`, drives
`advance` from its Ticker, draws `session.current`, calls `session.resize` from the `LayoutBuilder` and always disposes
with `quit` (Q7). `ArenaSession.step` sets the arena layout once per player (again after a resume), records
`round_start` on the first step with players in a new round, runs `game.update(simStepS, …)` with the latched inputs,
and per event haptics, `sound`, `onEvent` and the record; the step that flips playing → won records `round_end`
(`timeS`, `modes`, `winner`) and `frames`. `dispose` records the final `frames` if any.

`ArenaSnapshot`/`ArenaPlayerView`/the `snapshot()` extension moved verbatim (Q6), then gained `toJson`, `lerpTo` and
`ArenaPlayerView.lerpTo`. `lerpTo` returns `this` at t ≤ 0 and `next` at t ≥ 1, lerps the sprites' x/y, cooldown and
aim (an aim kept when only one side has one), `roundTimeS`, `breakLeftS` and the hazards pairwise, and takes every
discrete field (`round`, `phase`, walls, goal, start, winner, best, radii, flags, counters) from `a`; only `a`'s
players are iterated, so a player only in `b` isn't drawn.

Drawing takes an `ArenaRoster` (`Map<String, ({int number, String name})>`): the TV builds it from `host.players`, the
viewer from the frame's `pl`. `ArenaPainter` uses `Color(playerColor(number))` (from `protocol`), with `0xFF5AAAFF`
for an id the roster doesn't know.

## Computed values (as the tests assert them)

| What | Value | Pinned by |
| --- | --- | --- |
| 60 × 16 ms advances | 57 steps | `session_test` |
| 90 × 16 ms advances | 86 steps | `session_test` |
| One 100 ms advance | 6 steps, `atMs` 17, 33, 50, 67, 83, 100, `n` 0–5 | `session_test` |
| Frames over those 57 steps at 60/30/20 Hz | 57 / 29 / 19 | `session_test` |
| A 2 s advance (clamp 0.1 s) | 6 steps; they use the accumulator exactly (6 × 1/60 = 0.1) | `session_test` |
| Latch | press set and cleared in one no-step advance → 1 step sees it, the next sees the release | `session_test` |
| `round_end.timeS` | `stepCount × 1/60` at the step the round flipped | `arena_session_test` |
| Arena lerp at 0.5 | x 0.1 → 0.3 is 0.2; cooldown 0 → 0.5 is 0.25; `roundTimeS` 2 → 4 is 3 | `arena_snapshot_test` |

**Deviation from plan §5, one line.** "2 s advance → 6 steps, next 16 ms adds 1" doesn't hold: 6 steps consume
exactly 0.1 s, so the next 16 ms adds nothing and the one after it adds the 7th step. The test asserts the real
behaviour (6, then 6, then 7) and explains why.

`frameSlackMs` (0.001) is new, not in the plan: `at` is a double built from the host's clock, so rounding alone can put
a step a hair before its send time and a 60 Hz frame would be dropped (29 frames instead of 57). It is a named
constant with its reason, not a magic number.

## Move proof (`tools/review.sh --strings`)

```
strings: 8 removed, 21 added, 85 unchanged or moved
```

The 85 are the moved code, including every string of the old `arena.dart` snapshot block. The 8 removals are all in
the old `arena_view.dart` and their text is unchanged in their new homes: `'hud-${f.id}'` → `'hud-$id'` (and the other
three keys), `'${feed.number}'` → `'${entry.number}'` (the painter), and the two banner strings, which now interpolate
a pre-formatted `timeS` (`'Goal! $timeS s'` where `timeS = lastTimeS.toStringAsFixed(1)`) instead of inlining the
`toStringAsFixed` call. The 21 additions are `game_kit`'s and the new Arena files' own texts (`assert` messages,
module ids, viewer error).

## Checks

| Check | Before | After |
| --- | --- | --- |
| format | PASS | PASS |
| analyze | PASS | PASS |
| protocol | 102 tests | 102 tests (untouched) |
| connection | 223 tests | 223 tests (untouched) |
| metrics | 38 tests | 38 tests (untouched) |
| kit | – (no package) | **14 tests** (11 session + 3 registry) |
| arena | 30 tests (20 `arena_test` + 10 `arena_view_test`) | **39 tests** (30 + 4 snapshot + 5 session) |
| puzzle | 62 tests | 62 tests (untouched) |
| host | 44 tests | 44 tests (untouched) |
| phone | 262 tests | 262 tests (untouched) |
| tv | 22 tests | 22 tests (untouched) |

No existing test needed a new expected value: every value `arena_view_test` and the upstream `host`/`tv` tests assert
(`Hits 1`, the wall bump at step 11, the goal at ~step 152, the record counts) still holds on the new step count,
exactly as plan §5 predicted.

## Review

`tools/review.sh`: **1 fail, 29 note**.

- The fail is `size packages/test_game/lib/src/arena.dart:1 487 lines (lib limit 400)`. It is line 1, which this job
  never touched, and it was 695 before: the plan (§0, §2) already predicted ~489 and its rule is "`arena.dart` only
  shrinks". Splitting the remaining rules to get under 400 would be a rules change, which the brief forbids, so I left
  it; G4 can decide (Q1 below).
- The 29 notes are the pre-existing style notes of the moved code: `_updatePlayer` 42 lines (`arena.dart:360`, already
  there), `ArenaPainter.paint` 50 and 51 lines and its numeric literals (moved from `arena_view.dart`), and the numeric
  literals of `arena_snapshot.dart`/`arena_view_widgets.dart` (moved constants and sizes). No note is on a line of
  `game_kit` or on new logic.

## Questions and suggestions

1. **`arena.dart` stays at 487 (>400, review FAIL on line 1).** The plan predicted it and the brief says it may only
   shrink; is a later job (G4 or a rules-splitting job) to bring it under 400, or is the size FAIL accepted until then?
2. **Plan §5's "2 s advance → 6 steps, next 16 ms adds 1"** is off by one advance; the report and the test use the
   real behaviour (6, 6, 7).
3. **A nameless player in the viewer**: the frame's roster carries `nickname ?? ''`, so `ArenaHud` labels that row
   `'P1 '` with a trailing space. The TV today has the same shape (`P$number $name`). Suggest trimming in s3c when
   `FrameView` lands, or leave it for consistency.
4. **`arenaSetup`** is an empty map, and `ArenaViewer.build` only draws when the snapshot is an
   `ArenaSnapshot` — a version match is the reader's job (s3c). Worth pinning in s3c's `FrameView` test.
5. **The three `tv_test_app/windows/flutter/generated_plugin*` files** show as modified in `git status` but
   `git diff` is empty (line endings only); `s3b-g1-report.md` records them dirty before this job. I touched none.

## Commit message

```
Add game_kit and run the Arena on a GameSession

- packages/game_kit: GameSession with the approved input latch, the fixed
  1/60 s steps, the frame schedule and drawn(), plus HostingSettings,
  GameModule/GameViewer/GameSnapshot/ViewContext and GameRegistry.
- The Arena moves onto it: ArenaSession runs the rules and records, the
  thin ArenaView only draws, arena_snapshot.dart holds the snapshot with
  lerpTo, and the drawing code takes an ArenaRoster.
- Root workspace, tools/check.sh (kit) and docs/dev-tools.md gain the
  package; 14 kit tests and 9 new arena tests, no existing value changed.
```

## Status row

| 3 Sessions, frames, playout, stages | s3b G3 done: `packages/game_kit` (GameSession with the input latch, fixed 1/60 s steps, frames, `drawn`, `HostingSettings`, the module/viewer/snapshot/registry interfaces; 14 tests, `kit` check) and the Arena moved onto it (`ArenaSession`, thin `ArenaView`, `arena_snapshot.dart` with `lerpTo`, `arena_view_widgets.dart`, `arena_painter.dart`, `arena_module.dart`; 39 arena tests). All 11 checks pass. `arena.dart` 695 → 487, still over 400 (review FAIL on line 1, plan-predicted). Next: G4 (Shape Race, the puzzle session and module) |

## Delete

- none
