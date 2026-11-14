# M14 bugs3 s1-progress-bar — report (B-001)

## Summary

**Root cause.** The bar is a bar of the clock: every place that draws it (one-board HUD, split screen's
strip or gap, phone HUD, phone panel's `progress`) divides the time left by the limit. A round ends the
moment the last piece goes in, so the clock always has time left and the bar never fills (3/8 of the way
in the test frames). Not a wrong total, rounding, twins or snapped-only pieces: `placed` was not in it.

**What changed, by file.**

- `lib/src/snapshot.dart`: `PuzzleSnapshot.isComplete` — `placed == pieces.length`.
- `lib/src/board_hud.dart`: one shared `_barFill(board, done, timeLimitS)` (all of it when the picture is
  done, else the clock's share; null without a limit); the one-board HUD uses it.
- `lib/src/match_painter.dart`: the strip/gap bar and the phone HUD's bar use `_barFill` (old
  `_barFraction` gone); the split bar is the round's (full once either side finishes), a phone's whole
  view reads the round's, a side camera its own.
- `lib/src/puzzle_status.dart`: the panel's `progress` is 1 once that side's picture is done; its text
  still says the time left (PRD v2 P6).
- `test/progress_bar_test.dart`: new tests, one per layout plus the panel. (All under `packages/puzzle_game`.)

**Decisions.** 1. The bar stays a bar of the clock while the round runs and goes full only at the finish,
rather than becoming a bar of pieces placed: the design calls it the time bar (design section 5). 2. The
split bar is the round's: full when either side finishes, since the race is then decided. 3. The panel
fills too: its comment already reads "how far the game has gone". 4. No snapshot or protocol field changed
(`isComplete` is derived on the device), so an older phone or host behaves as before.

**Not done.** A bar of pieces placed during play is a design change (design section 5, PRD P6), left for
Claude; a time-up loss still leaves the bar empty, which is right.

**On a device.** Play a solo Shape Race, place the last piece: the bar under the clock full at once and on
the win screen. Same in a 1v1 race, and on a joined phone: HUD bar and panel bar full, text still the time.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** The bar is drawn from the snapshot in every setup the code has (TV/PC host, host
   phone on "Play on this phone", joined phone, one board and split); tested at TV size (solo, co-op, race)
   and phone size. An older phone or host draws the same, since no field changed in the snapshot or protocol.
2. **When kept state starts and ends.** Nothing is held or timed by this change: the fill is computed each
   frame from the snapshot's clock and pieces, so it starts full on a fresh clock, drains with the clock,
   and stays full after the finish (the locked pieces stay). With no round there is no painter, so no bar.
3. **How a new state combines.** The rule reads only `placed == pieces.length`, which pause, host away, a
   player away and get ready never change: the bar keeps its fill through each, and the results keep it full
   (tested by the `finished` frames; the `stopped` board of a losing side keeps its clock's share).
4. **Stay in the job's folder.** Only the six files named in the brief's `allow:` were written; the
   suite's own picture tests rewrite `docs/design/*.png` and the Windows plugin files as they run, which
   this job did not edit (see the note at the end).
5. **Stop rather than overstep.** Nothing needed outside `allow:`; no stop.

## Test values (computed)

The bar's fill is measured as the rightmost `good` pixel of a captured frame, against a full-clock frame of
the same layout (`trayBoard(clockMs: 120 s)`), so no layout constant is copied into the test.

| layout | frame | bar's full end (px) | old rule, 45 s of 120 left | new rule |
| --- | --- | --- | --- | --- |
| solo, `PuzzleView` 960x540 | track x 16..156 world at scale 6 | 933 | 410 (3/8 of 840 px from 96) | 933 |
| co-op (`MatchView`, 2 players, one board) | as above | 933 | 410 | 933 |
| race (`MatchView`, seed 3, 960x540) | gap bar, 10 world units = 60 px, 480 ± 30 | 509 | 471 | 509 |
| phone (`MatchView`, 852x393, seed 3, side camera) | HUD rows from `PuzzleCamera.hudPlace` | 212 | 84 | 212 |
| phone panel (`puzzleStatusFor`, `timeLimitS` 10) | 5 frames/s x 50 = 5 s elapsed, `timeLeftS` 5.0 | 1.0 | 0.5 | 1.0 |

Each threshold: the mid-round frame must be more than 50 px (solo, co-op) or 10 px (race, phone) short of
the full end; the finished frame within 2 px of it. All five tests fail on the code as it was (410, 410,
471, 84 and 0.5) and pass now.

## Questions and suggestions

1. If the owner meant a bar of the picture's progress rather than of the clock, that is a design change to
   design section 5 and PRD v2 P6 — Claude's call, not made here.
2. The winning side's own clock in a race stops with time left; if a later brief wants the *loser's* bars
   to read their own clock too, the same `isComplete` is the seam.
3. `git status` shows `docs/design/*.png` and `tv_test_app/windows/flutter/generated_*` modified: the
   picture tests write those PNGs and the Flutter tool rewrites the Windows registrant when a suite runs.
   This job wrote none of them and cannot revert them (git commands that change files are forbidden here),
   so Claude should check them before the commit.

## Commit message

Shape Race: fill the bar all the way once the picture is done

The bar was a bar of the clock (time left / limit), so a round that ended
early left it part way and it never filled.
Add PuzzleSnapshot.isComplete and one _barFill rule: full when every piece
is placed, else the clock's share; the one-board HUD, the split strip or
gap, the phone HUD and the phone panel's progress all use it.
Tests: one per layout plus the panel, against a full-clock frame.

## Status row

M14 bugs3 s1: B-001 fixed — the Shape Race bar is full when the last piece is placed and stays full on the win screen (one board, co-op, split screen, phone HUD and phone panel), with five new tests; open: no design decision on a pieces-placed bar.

## Delete

- none
