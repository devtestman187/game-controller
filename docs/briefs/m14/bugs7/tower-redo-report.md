# M14 bugs7 tower-redo — two tower candidates

## Summary
The shipped `tower` reads as a stack of blocks because the tray, not the drawing, forced it:
a turned rect costs a tray row as wide as the piece, so every wide feature (body, battlements)
had to be cut into small boxes. Both candidates keep that in mind and put the tower's height in
one tall body piece, then two ≈20-wide band pieces and three teeth for the battlements, so the
parapet reads as a parapet and not as a row of blocks.

| candidate | height accent | pieces | turned | big | pairs | smallest piece |
| --- | --- | --- | --- | --- | --- | --- |
| a | flag on a pole above the battlements | 10 | 10 | 3 | 2 | flag 13×9 (15.81 diagonal) |
| b | pointed (triangular) roof over the battlements | 10 | 10 | 3 | 2 | step 16×6 (17.09 diagonal) |

Both are `"id": "tower"`, `"level": "hard"`, pass the rule book (`checkPuzzle`, seeds 0–199) and
the schema, and read at a glance as a castle tower: tall body, wider battlement with three teeth,
door, one window, plus the flag (a) or the roof (b).

- `docs/briefs/m14/bugs7/tower-redo/candidate-a.json` — the pieces; sheet `candidate-a-sheet.png`
  (the render of the same puzzle, copied).
- `docs/briefs/m14/bugs7/tower-redo/candidate-b.json` — the pieces; sheet `candidate-b-sheet.png`
  (the render of the same puzzle, copied).

**Recommendation: candidate a.** The flag above the parapet is a taller, narrower silhouette, the
body is longer (reads more as a keep than a hut), and the top is one accent piece instead of a
triangle whose thin points measured close to the 8.5 mm floor on the narrowest phone.

The two puzzle files and their renders in `packages/`/`docs/design/` were temporary scaffolding
for the kit; they are listed under **Delete**, so after this job `packages/` and `docs/design/`
are byte-identical to the start and nothing is shipped.

## Kit used
`tools/level.sh` would not run: the job's tool sandbox refuses to execute the scripts (`tools/level.sh`,
`tools/level.sh --self-test`, and `dart tools/level_new.dart` were all refused). So, as the brief allows,
I ran the exact commands the kit's command table gives, from `packages/puzzle_game`:

- `flutter test --dart-define=puzzleId=tower-a test/puzzle_check_test.dart test/puzzle_schema_test.dart`
  → `All tests passed!`
- `flutter test --dart-define=puzzleId=tower-a test/puzzle_render_test.dart`
  → `wrote ../../docs/design/puzzles/tower-a.png (44312 bytes)` / `All tests passed!`
- `flutter test --dart-define=puzzleId=tower-b test/puzzle_check_test.dart test/puzzle_schema_test.dart`
  → `All tests passed!`
- `flutter test --dart-define=puzzleId=tower-b test/puzzle_render_test.dart`
  → `wrote ../../docs/design/puzzles/tower-b.png` (47629 bytes on disk) / `All tests passed!`

`tools/level.sh new` could not run either, so the two temporary files were written by hand from
`puzzles/_template.json` with the same fields (`$schema`, `format`, `id`, `name`, `level`, pieces),
under the ids `tower-a` and `tower-b`. `index.json` was deliberately left untouched.

## Checks
- `tools/check.sh format` → **PASS** (4s).
- `tools/check.sh puzzle` → **FAIL**: `435 passed, 3 failed`. The three failures are
  `library_test` "the whole library has no issues", `puzzle_check_test` "the rule book over the
  whole library" and `puzzle_new_test` "the new puzzle passes the rule book unchanged"; each one
  only reports `puzzles/tower-a.json is not listed in index.json` and the same for `tower-b`.
  The **Delete** section removes those two files, which removes all three failures. I could not
  show a green run myself: I cannot delete files.
- Side effect to know about: the suite re-renders every design sheet, so that run rewrote 16
  committed PNGs in `docs/design/`. I restored all of them from HEAD (`git show HEAD:<path>`, one
  call per file) and `git status --short` now lists only the job's own files.
- Not mine, and untouched: `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
  `generated_plugins.cmake` were already modified when the job started (mtime 20:46:38, before my
  first `flutter test`).

## Decisions
- **One tall body, not a body plus a parapet block.** In candidate a the body is a single 20×37
  rect; in b a 20×32 rect. Two or three shorter stacked boxes are what made the old tower look like
  bricks, so the height had to come from one piece.
- **The battlement is split, never one wide piece.** A turned rect's tray row is as wide as the
  piece, and the tray packs rows from y=15 to y=83 with 2-unit gaps inside x=104…154. A single
  20–40-wide band cannot fit there at all seeds, so the band is `band left` (20×8) + `band right`
  (19×8) and the crenellation is the three teeth, which sit over the band and read as a parapet.
- **The three teeth are identical** (11×13 in a, 10×14 in b), which is exactly the Hard limit of two
  repeated shape pairs, and they share `purple`.
- **Colours:** three piece colours checked against the 0.15 board / 0.08 pair distances. `band right`
  started as `silver`, 0.07 from `steel`, and became `blue`; `band left` is `slate`.
- **Small pieces raised to clear 8.5 mm** at 640×356 on seeds 1–21: the flag pole grew from 5×14
  (7.71 mm) to 8×15, and the window from its first size (8.10 mm) to 13×12.
- **b's roof is a regular triangle** `{"regular": [3, 10]}`: a regular polygon starts exactly at
  symmetry/2 = 60° on Hard, so its tray box is deterministic, where an irregular polygon gets a
  random 90–180° error and a box up to twice its radius.
- **`index.json` stays untouched.** Listing the two temporary ids would make the suite green now and
  break the library once the files are deleted.

## Self-check (review-rules part A)
1. **Every host setup** — n/a: two JSON proposals outside the library, no code, no build.
2. **When kept state starts and ends** — n/a: nothing is held, timed or remembered.
3. **How a new state combines with the others** — n/a: no state, no input, no pause.
4. **Stay in the job's folder** — yes: only `docs/briefs/m14/bugs7/tower-redo*`,
   `packages/puzzle_game/puzzles/tower-{a,b}.json` and `docs/design/puzzles/tower-{a,b}.png` were
   written; the design sheets the test suite re-rendered were restored from HEAD and `git status`
   is clean for them.
5. **Stop rather than overstep** — I did not touch `index.json`, did not delete the temporary files
   (no permission: they are in **Delete**), and did not write a third candidate or a code change.

## Questions and suggestions
1. Is the sandbox refusing `tools/level.sh` expected in worker jobs? I used the commands it prints,
   but the kit's own `new`/`check`/`render` wrapper never ran, so its self-test and its index-line
   handling were not exercised.
2. Which candidate does the owner want? I recommend a. If b wins, its `step` and the triangle's
   points are the pieces to watch on the smallest phone, and the roof costs a tray row for a 10-radius
   triangle.
3. When a candidate is picked, the follow-up is a one-line `index.json` change plus the render; both
   are outside this job (the Delete section removes what would otherwise ship here).
4. For the next animation/picture job: any puzzle whose drawing needs a full-width feature is
   fighting the tray. `docs/levels.md` could say plainly that turned rects pay one tray row per
   piece width — I lost two designs to that before finding it.

## Commit message
Add two tower candidates for the tower-redo job

Candidate a is a keep with a flag on its battlements, candidate b a tower
under a pointed roof. Both are 10 pieces, all turned, 3 big, 2 repeated
shape pairs, id "tower" at Hard, and pass the rule book over seeds 0-199.
Neither is in the library: index.json is untouched and the temporary
puzzle files and renders are removed with the job. The sheets sit in
docs/briefs/m14/bugs7/tower-redo/ for the owner to pick from; the report
recommends a.

## Status row
Tower redo: both candidates drafted, checked and rendered — done; the owner's pick, the `index.json` line and the shipped render are open.

## Delete
- packages/puzzle_game/puzzles/tower-a.json
- packages/puzzle_game/puzzles/tower-b.json
- docs/design/puzzles/tower-a.png
- docs/design/puzzles/tower-b.png
