# pr-shape — proposals for the owner's two change requests (report only)

Job: M14 bugs3 pr-shape. No code was changed; the only file written is this one.
Read for it: docs/design/party-night.md §2 and §13; docs/PRD-v2.md "Milestone 14" and the
"Puzzle results" row of "What it records"; the code each item names.

## Summary

- **B-009 (repeats):** today the next-puzzle pick (`puzzle_screen.dart:152-160`) draws from the
  level's puzzles with an unseeded `Random()` and excludes the puzzle just played only after a
  rematch (`avoidPuzzleId`, `puzzle_screen.dart:277`), so with the 6 Medium puzzles a repeat by the
  third round is 20% and by the fourth 36% on that path, and 1/6 a round on the join path, which
  passes no guard (`join_screen.dart:293`). **Pick:** a shuffled
  bag per level, kept in the host's prefs (`puzzleBag`), so a level plays every puzzle once before
  any repeats, across app restarts, and a new puzzle joins the bag as soon as a build adds it.
  Risk: with 6 puzzles a level becomes recognisable after a full cycle (the same 6, reshuffled).
- **B-012a (metrics):** nothing measures moving vs placing today; the PRD's "time carrying each
  piece" was never built. **Pick:** two new per-player numbers in `player_result`, `moveS` and
  `placeS`, split by the drop's position tolerance, plus a `level_…` round tag; both arrive in the
  uploaded summary's `gameStats` with no report change, but the per-player table needs adding work —
  "moving", "placing" and a derived share (B-012a below), as nothing in `packages/metrics` reads
  `gameStats` keys today. Risk: the split is a proxy — turning a piece
  in mid-board counts as moving, so a careful child who lines up away from the outline is
  undercounted; `rotatingS` already separates turning.
- **B-012b (harder):** **Pick:** a real **Hard** level (10–12 pieces, 3–4 big, every non-circle
  turned, half starting ≥90° off, ≤2 repeated pairs) and per-level default clocks (Easy 120 s,
  Medium 150 s, Hard 210 s), leaving Easy's and Medium's rules untouched — so "Medium is easy" is
  true and no existing puzzle file changes or fails `check`. Risk: on the same board 12 pieces may
  fall under the 8.5 mm piece floor and be refused, capping Hard at 10; 210 s is an estimate until
  B-012a's numbers exist.
- **B-012c (M16):** jigsaw-style interlocking pieces, a per-puzzle difficulty number and a ramp-up
  order are left for M16: the shape model, not the rules, is the work.
- Conflicts: the PRD's "Puzzle results" row already promises carry time that was never built
  (B-012a makes it true rather than adding to it); party-night §13/g1 and the schema refuse
  `Level.hard` "until it has rules" (B-012b gives it rules, so those lines change); the design has one
  clock, not one per level (B-012b keeps the host's setting and only makes it a value per level).
- Computed values used below: 20% / 36% repeat odds; 6 rounds per bag of 6; 1.0 s and 0.5 s from
  60 and 30 steps of 1/60 s; clocks 120 / 150 / 210 s; the 8.5 mm piece floor.
- Checks: `tools/check.sh format` — PASS (report only; no Dart changed).

## Decisions (low-usage mode)

- B-009: the bag lives in the host's prefs, not in memory, because the TV app is closed between
  games far more often than between rounds, and the prefs pattern already exists (`best_times.dart`).
- B-009: a hand-picked puzzle does not draw from the bag; an explicit choice is a repeat by intent.
  The "not the one just played" guard reaches only the rematch button (`puzzle_screen.dart:277`), and
  a hand-picked choice keeps its `puzzleId` so it never re-draws: the bag's rule that the id just
  played moves to the end is what keeps it out of the next random pick, on the join path too, which
  passes no guard.
- B-012a: two raw seconds rather than one "share", so the report can compare levels and modes
  without dividing per round, and a round that ends early still contributes a readable pair.
- B-012b: leave Medium's piece counts alone and add Hard, because retuning Medium means growing all
  six Medium files in the same job and re-pinning their renders; the owner's "Medium is easy" reads
  as "keep it as the step below".
- B-012b: one clock per level as defaults with the host's override kept, because the game reads one
  `timeLimitS` and a rules change there would touch every puzzle test for no gain.

### B-009 — every puzzle of a level once before any repeats

**Today:** `PuzzleScreen._pick` (`party_host/lib/src/ui/puzzle_screen.dart:152-160`) draws from
`library.ofLevel(level)` minus the round just played (line 277) with an unseeded `Random()` (line 89),
so the previous puzzle is excluded only after a rematch (`_rematch`, line 277, is the one caller that
passes `avoidPuzzleId`): with the 6 Medium puzzles round 3 repeats round 1's puzzle 20% of the time,
and four rematched rounds hold a repeat 36% (all-new = 0.2·0.8 + 0.8·0.6 = 0.64). The join path
(`join_screen.dart:293`, and every night round that comes back from the scoreboard) passes no guard,
so there a repeat is 1/6 a round and four rounds hold one 42% of the time (1 − (5/6)³ = 0.42).
**Change:** a shuffled bag per level: a draw pops the next id; an empty bag refills with every id of
the level, reshuffled and the id just played moved to the end, so no cycle opens with the puzzle just
finished. The bag is saved on the host in the prefs (`puzzleBag`, `{level: [id, …]}`) beside
`bestTimes` (`best_times.dart:109-123, 151`), so the order survives the app closing; ids a build no
longer ships are dropped on load and ids it adds are shuffled into the current bag, so a new puzzle
is seen before any repeat.
**Interplay:** one bag per level, so Easy, Medium and Hard rotate independently and switching level
neither repeats nor resets; a night's Shape Race rounds use the same bag (a 5-round night in one
level plays 5 of its 6). The Look never touches it: `LookChoice` changes colour only
(`look_choice.dart:25-28`), no puzzle has a per-look variant, and nothing in the bag comes from the
palette, so Auto turning Night at 19:00, or a restart at night, leaves the order alone.
**How and tests:** a new `party_host/lib/src/puzzle_bag.dart` (a pure `PuzzleBag` and a
`PuzzleBagNotifier` over `prefsProvider`, ~70 lines, after `best_times.dart`); `_pick` asks it for the
level, the library's ids and a passed-in `Random`, keeping `avoidPuzzleId` as the second guard. Tests:
6 draws give 6 different ids; the 7th differs from the 6th; a one-puzzle level always returns it; a
saved bag reloads in its order; an added puzzle is drawn within the cycle; a removed id is dropped; a
hand-picked round does not draw.
**Files:** `puzzle_bag.dart`, `puzzle_screen.dart`, `providers.dart` if the provider lives there, tests;
**risk** as in the Summary (an in-memory bag loses the order on every restart).

### B-012a — measure the time spent moving against the time spent placing

**Today:** each player counts pickups, snaps, wrong drops, turning time, overshoots, carries, cats
shooed, help calls and solo big-piece carries (`puzzle_player.dart:23-41`), sent as `player_result`
(`puzzle_report.dart:37-57`); each number becomes a per-player count/mean/max in `gameStats`
(`session_recorder.dart:108-116`, `session_player.dart:111-113`), which is what the report reads.
Nothing separates moving the worker from placing the piece; the PRD's "time carrying each piece"
(PRD-v2.md:203) was never built.
**Measure**, per player per round, in seconds: `moveS` — holding a piece that is not within
`positionTolerance` of any outline it could fill, plus walking with empty hands; `placeS` — holding a
piece that near one of its outlines (the angle may still be wrong): aiming, turning and the drop.
`rotatingS` stays; a turn at the outline is a subset of `placeS`. The two sum to the round's clock for
that player (solo, team, or a race side up to the finish), so the owner's observation (a five-year-old
spends about 2 minutes on a Medium puzzle, most of it moving) should show as `moveS` well over 60 s.
**Where in the stats:** both go into `player_result`, so they arrive as `puzzle` `gameStats` entries
(mean and max per round) in the uploaded summary, and the per-player report table gains "moving" and
"placing" plus a derived share (`mean moveS / mean (moveS + placeS)`). Also add the round tag
`level_easy|medium|hard` from `PuzzleSession._endTags` (`puzzle_session.dart:184-190`, the game knows
its puzzle's level) with `RoundTag.level` and a row group in `report_games.dart:12-56`, so levels are
compared the way maps and modes are; today only the puzzle id reaches `round_end`.
**Files:** `puzzle_player.dart`, the carry step (`puzzle_carry.dart:103`), `puzzle_report.dart`,
`puzzle_session.dart`, `round_tags`, `report_games.dart`, tests, PRD row 203; **risk** as in the Summary.
**Tests:** 60 steps holding away from the outline → `moveS` 1.0 s (60 × 1/60); 30 steps over the
outline → `placeS` 0.5 s; a snap adds no time; a race side finishing at 40 s has `moveS + placeS` = 40 s
± one step; a `player_result` with both keys lands in `gameStats`; the round's tag is `level_medium`.

### B-012b — a real Hard level, and a clock per level

**Today:** Easy 4–5 pieces, exactly 2 turned, no repeated shape; Medium 6–8, ≥2 turned, 1–2 big, ≤1
repeated pair (`puzzle_rule_levels.dart:3-21`, docs/levels.md:125-133). `Level.hard` is refused
(`puzzle.dart:92-98`, `puzzle.schema.json:30-32`, `puzzle_rule_levels.dart:66-68`, `level.sh new`). One
clock for every level, `timeLimitS` 120 s (`settings.dart:20`, host range 30–600 at line 76); turned
pieces start at least 30° off (`start_angles.dart:15`).
**Change:**
1. **Hard**, a real level: **10–12 pieces**, **3 or 4 big**, **every non-circle piece turned** (≥6),
   **at least half starting ≥90° off**, at most **2** repeated shape pairs. The 8.5 mm piece floor
   (`minPieceMm`, `piece_size.dart:18`) and the tray rules decide the count, so a 12-piece picture
   whose smallest piece is under 8.5 mm is refused by `check` and drops to 10.
2. **A per-level start angle:** 30° as today on Easy and Medium, **90° on Hard**.
3. **A clock per level, as a default:** Easy **120 s** (unchanged), Medium **150 s** (+25%, so a
   five-year-old has slack past today's 120 s limit), Hard **210 s** (12 pieces is 1.5× today's largest
   Medium of 8; at 15–20 s a piece that is 180–240 s). The Puzzle settings screen shows three Time
   limit rows (30–600 s, 15 s steps) and the round takes its level's value.
**What does not change:** Medium's pieces, turn rules and files stay — the six Medium puzzles play as
they do, which is what "Medium should be easy" asks for; only its default clock moves from 120 s to
150 s (Easy's 120 s and every existing file are untouched). **Files:** `puzzle.dart`,
`puzzle_rule_levels.dart`, the schema, `tools/level.sh`, `docs/levels.md`, `start_angles.dart`,
`settings.dart` (or a per-level map in `puzzle_settings_provider.dart`), `puzzle_settings_screen.dart`,
`host_text.dart`, new Hard files (a content job), tests.
**Tests:** the rule book with the new limits; a 9-piece Hard file and a Hard piece starting 30° off are
refused; `check` green on every existing puzzle; defaults 120/150/210 s, a saved 90 s wins; the size
test over the new puzzles. **Risk:** as in the Summary (piece floor may cap Hard at 10; 210 s unproven).

### B-012c — left for M16: interlocking pieces, difficulty numbers, a ramp

- **Jigsaw pieces (tabs and blanks):** every piece is a convex polygon or a circle
  (`piece_shape.dart:1-56`), and the picture is implied by outlines on the board, with the pieces'
  shapes matching them. Interlocking pieces need outlines with tabs and blanks, a picture drawn under
  them, a fit test that reads a tab against a blank (today's fit is a position and angle tolerance),
  new painters for the outlines and the trap for pieces that share a shape. That is a picture-and-
  rendering change across the rules, the painters, the fit rule and the level format, not a level
  rule: M16.
- **A difficulty number per puzzle** (an optional field in the level file, 1–5) and a "Next puzzle"
  that steps up gently, both only worth it at 3 or more puzzles per level — which is M15's plan of
  9 puzzles, 3 per level (PRD-v2.md, Milestone 15).
- **Beyond 12 pieces or a second axis of hardness** (per-piece rotation speed, no clock on Hard):
  wait for B-012a's numbers, which say whether the cost is moving or placing.
- **Content rebalance:** today the library is 12 puzzles (6 Easy, 6 Medium); with three levels
  M15's "3 per level" means 3 each (9 files) or a larger set. That is the owner's call, not this
  job's.

## Questions

1. B-012b: is "Medium should be easy" met by leaving Medium as it plays and adding Hard (my pick),
   or does the owner want today's Medium puzzles themselves grown (each gains a piece or two) so
   Medium sits harder, with the five-year-old then playing Easy?
2. B-012b: is 10–12 pieces and 210 s the right shape for Hard, or should Hard first ship at 10
   pieces / 180 s and grow once B-012a's moving-vs-placing numbers are in?
3. B-009: should a hand-picked puzzle (the family chooses Castle) also be counted as played in the
   bag, so "Any Medium" never follows it?
4. B-012a: is `moveS` allowed to include walking with empty hands (my pick: yes, it is "moving
   character around"), or should the two numbers cover only the held piece?

## Self-check (review-rules part A)

1. Every host setup: no code changed; the bag is host-side state, so a TV host, a phone host on
   either setting and a joined phone see the same drawings; nothing goes over the wire.
2. Kept state: the bag starts empty and fills on the first draw; it ends never (a prefs key), and
   with no round running it is only read on a draw.
3. New state combined: nothing pauses, hides or waits; a bag draw happens once, when a round's
   puzzle is chosen, beside the existing night and pause owners.
4. This folder only: the only write is this report.
5. Stop rather than overstep: nothing needed outside `allow:`; no blocking contradiction found.

## Commit message

M14 bugs3: proposals for no-repeat puzzles and a harder Shape Race

Report only, no code. Answers the owner's two changes: a shuffled bag per level, kept in the host's
prefs, so every puzzle of a level plays once before any repeats (today the pick only avoids the
previous puzzle: a repeat by the fourth round is 36% with six Medium puzzles); and a real Hard
level (10–12 pieces, 3–4 big, every non-circle piece turned, half starting 90° off) with per-level
default clocks (Easy 120 s, Medium 150 s, Hard 210 s), leaving Easy and Medium exactly as they
play. Also proposed: two per-player timing numbers, `moveS` and `placeS`, so the stats show moving
the worker against placing pieces, with a level tag for the report. Jigsaw pieces and a per-puzzle
difficulty number are left for M16. Values, files and risks are in
docs/briefs/m14/bugs3/pr-shape-report.md.

## Status row

B-009 and B-012 (bugs3 pr-shape) are proposed in full: a shuffled per-level bag saved on the host, `moveS`/`placeS` player timings with a level round tag, and a Hard level with a clock per level (120/150/210 s). Open: the owner's OK (and the four questions), then the metrics job, the Hard-level rules job and the Hard content job.

## Delete

- none
