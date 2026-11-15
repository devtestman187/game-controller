# M14 bugs8 b012c-1-hard-swap report

## Summary
The three Hard pictures the owner picked now ship: `dragon.json` is candidate a (a standing dragon
facing right), `tower.json` candidate b (a tower under a pointed roof), `tractor.json` candidate a
(a farm tractor facing left). Each file is the candidate, byte for byte, except its `notes`: one
sentence saying what the picture is, with the proposal / candidate / job-folder sentences dropped.
`index.json` is unchanged, so the ids, names, level and Hard order stay as they were.

Test first: the new `packages/puzzle_game/test/hard_swap_test.dart` pins each puzzle's piece ids in
drawing order, plus id, name, Hard level and the index's Hard order. It failed on the old library
(1 passed, 1 failed: dragon "at location [0] is 'body' instead of 'tail'") and passes now (2 passed).

Checks: `format` PASS; `host` 447 passed; `phone` 464 passed; **`puzzle` 439 passed, 1 failed** —
`split_layout_test` "phones layout every puzzle and seed puts the tray on top …" at tower seed 15:
the pieces wrap to two rows (28.5) in a one-row tray (19.0). That is **Blocked** (see below): the
new tower's row ends 2e-14 past `tray.width - trayGap` because the layout sizes the tray as
`right + trayGap` and `(right + 2) - 2` is not `right` in floating point. The fix belongs in
`lib/src/split_layout.dart` or `lib/src/tray.dart`, which are outside this job's `allow`.

Pins changed (old → new), all in `packages/puzzle_game/test`:
- `split_layout_test.dart` `overlaps['tower']`: `[0.25]` → `[0.0]`; the doc comment no longer says
  every Hard puzzle but the lighthouse overlaps on every seed.
- `tray_packing_test.dart` `visibleShare`: `0.45` → `0.50`; the comment named the old dragon's front
  leg (0.524) and tractor's ground (0.471) and now names the lighthouse's `tower top`, 0.518 (seed 0,
  flat, width 19.0), the lowest piece in the library.
- No other pin named the old shapes: `hard_library_test`, `library_test` and `rules_test`'s Hard
  lists are ids and order only, and the Medium/Hard limit tests build their own puzzles.

`docs/code-health.md`: the tray-packing entry now carries the new numbers and says the three redone
trays are unmeasured on a device, keeping the device-look recommendation.

## Kit used
`tools/level.sh` is refused by this sandbox (as the brief says), so I ran the commands the kit
prints, from `packages/puzzle_game`:
- `flutter test --dart-define=puzzleId=dragon test/puzzle_check_test.dart test/puzzle_schema_test.dart`
  → `+4: All tests passed!` (the same for `tower` and `tractor`, `+4` each).
- `flutter test --dart-define=puzzleId=dragon test/puzzle_render_test.dart`
  → `wrote ../../docs/design/puzzles/dragon.png (81724 bytes)` / `All tests passed!`
- `… puzzleId=tower …` → `wrote ../../docs/design/puzzles/tower.png (46891 bytes)`.
- `… puzzleId=tractor …` → `wrote ../../docs/design/puzzles/tractor.png (54738 bytes)`.

## Blocked
`packages/puzzle_game/test/split_layout_test.dart`, "phones layout every puzzle and seed puts the
tray on top with the crop centred below, and the pieces pack into the tray as wide as it is, a tray
gap apart where the row does not overlap": tower **seed 15** (`Expected: a value less than or equal
to <19.000000001000007>, Actual: <28.500000000000007>`, "the pieces overflow the tray by 9.5"); a
probe of seeds 16–19 shows **seed 18** the same. Root cause, measured: the tower's one-row tray is
127.24038105676658 wide, so its limit for the last box is 125.24038105676658, and the row's last
right edge (`tooth right`, dx 114.7403810567666 + 10.5) is 125.2403810567666, 1.4e-14 over, so
`packTray` wraps that piece into a second row. `_packedTray` sizes the tray as `right + trayGap` and
`packTray` compares against `width - trayGap`, and the round trip loses an ulp at this magnitude.
The old tower never landed on the boundary; this picture does. It is a lib change (outside
`allow`), e.g. give `_packedTray` a hair of slack (`right + 2 * trayGap`) or compare with an
epsilon in `packTray`, and the app would show the same two rows at those seeds. The tower's own pin
is `[0.0]` because every seed checked needs no overlap; nothing else in the suite fails.

## Computed values
- Tray packing, lowest visible share over the library, seeds 0–19, three widths: the lighthouse's
  `tower top`, **0.518** at seed 0, flat, width 19.0 (first piece under 0.55; 0.52 passes, 0.53
  fails). The floor is 0.50, i.e. the lowest multiple of 0.05 under the observed minimum, the same
  step the old 0.45 used under 0.471.
- Tower phone row: 127.24038105676658 wide at every seed, 19.0 high in one row; the world is
  131.24 × 102.00 units (aspect 1.287, under the 1.3 that would ask for overlap), and the smallest
  piece is 17.09 units (9.97 mm at 667×375).

## Decisions
- **`notes` in one sentence each**, dragon "A dragon seen from the side…", tower "A castle tower
  under a pointed red roof…", tractor "A farm tractor seen from the side…": the brief asks what the
  picture is and nothing about proposals, so the candidate/job-folder sentences went.
- **`overlaps['tower']` is `[0.0]`, not `[0.0, 0.25]`**: no seed checked needed an overlap; listing
  0.25 unobserved would loosen the pin. Seeds 0–17 were seen; 18 fails on the wrap and 19 is
  unobserved (the suite stops at the first failure).
- **Floor 0.50 rather than 0.55**: 0.55 is where the lighthouse's `tower top` fails, and the old
  floor was set one step under the minimum, so 0.50 keeps that intent without weakening it.
- **The failing split-layout test stays as written**: it is a rule ("the pieces fit their tray") and
  the failure is a real 1-ulp layout bug, reported rather than papered over with a tolerance.

## Self-check (review-rules part A)
1. **Every host setup** — the swapped puzzles run on both hosts through the same `PuzzleGame` and
   `SplitLayout`; no host-specific code, setting or test was touched, and the phone and host suites
   are green (464 and 447).
2. **When kept state starts and ends** — nothing new is kept: only the piece data changed. The start
   angles still come from `compactStartAngles` per seed, and the phone layout's angles are the ones
   the split match uses (proved by the existing split tests, which pass).
3. **How a new state combines with the others** — no state, input, pause or round change; a puzzle
   is still a data file with no code.
4. **Your folder only** — yes: the three puzzle JSONs, three design sheets, the new test, the two
   pin edits, `docs/code-health.md` and this report. `index.json`, `lib/`, the schema and every
   other PNG are untouched; the design sheets that were already modified at the start were
   rewritten byte-identically by the suite run (same file list as before the job: the 12 puzzle
   sheets plus the four `m13-*`, minus my three).
5. **Stop rather than overstep** — I did not edit `lib/` to fix the tray width, did not add a
   tolerance to a failing rule, and did not touch `index.json` or `docs/levels.md`.

## Hand-over
- **Fix the tray-width ulp** (Blocked above), then re-run `tools/check.sh puzzle`; the tower pin may
  then need seeds 19 (and 15/18 once they pack) re-checked for an overlap of 0.25.
- **Look at the three sheets** (`docs/design/puzzles/{dragon,tower,tractor}.png`, rewritten) on the
  smallest phone: the new pieces' tray is unmeasured on a device.
- The old Hard best times still sit beside the redone boards (already tracked, B-012).

## Questions and suggestions
1. Should `_packedTray` get the slack fix in a follow-up job, with the tower's overlap map
   re-verified over all 20 seeds? That is the one thing this swap could not close.
2. `docs/levels.md` could mention that a very wide tray row (127 units here, over a 47-wide board)
   is valid for the phone layout, since the world follows the tray, not the board.

## Commit message
Swap in the owner's picks for the Hard dragon, tower and tractor

Replace the three Hard pictures with the owner's picks: dragon candidate a
(a standing dragon facing right), tower candidate b (a pointed roof over
the battlements) and tractor candidate a (a farm tractor facing left).
Each file is the candidate as checked, with one sentence of notes; ids,
names, level and the index's Hard order are unchanged. A new
hard_swap_test pins each puzzle's piece ids in drawing order and failed on
the old files first. Two pins follow the new shapes: the tower needs no
tray overlap, and the visible-share floor rises from 0.45 to 0.50 because
the lowest piece is now the lighthouse's tower top at 0.518. The tower's
15th seed trips a one-ulp tray width in split_layout (open).

## Status row
Hard swap (dragon/tower/tractor to the owner's picks): files, notes, sheets, pins and the code-health entry done, host and phone green — open: `split_layout_test` tower seed 15 (and 18) overflow the tray by one row, a one-ulp tray width in `_packedTray` outside this job's allow.

## Delete
- none
