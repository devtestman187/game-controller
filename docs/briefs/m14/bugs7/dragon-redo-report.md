# M14 bugs7 dragon-redo — two dragon candidates

## Summary
The shipped `dragon` reads as a heap of blocks: rects and regular triangles laid out as separate
features, so no outline survives at a glance. Both candidates redraw it the other way round: a cartoon
dragon seen from the side, the head at one end with an open snout and a horn, a wing above the back, a
spiky tail at the other end and two legs below — 10 or 11 compact polygons that each look like one part.

| candidate | pose | pieces | turned | big | pairs | smallest piece |
| --- | --- | --- | --- | --- | --- | --- |
| a | standing, facing right | 10 | 10 | 4 | 0 | horn, 14.0 wide |
| b | flying, facing left | 11 | 11 | 4 | 1 (the two identical legs) | horn, 14.0 wide |

Both are `"id": "dragon"`, `"level": "hard"` and pass `checkPuzzle` in full (ids, kinds, held, colours,
level rules, turned count, tray over seeds 0–199, span, phone size): `flutter test
--dart-define=puzzleId=<id> test/puzzle_check_test.dart` printed
`the rule book over dragon-a` / `dragon-b` then `+1: All tests passed!`, and both render. At a glance
each reads as a dragon: blue head over red jaw with a yellow horn, purple wing (a) or purple + sand
wings in a V (b), green haunch and orange body, slate neck, brown spiked tail, two legs.

- `docs/briefs/m14/bugs7/dragon-redo/candidate-a.json` — the pieces; sheet `candidate-a-sheet.png`
  (81724 bytes, same bytes as `docs/design/puzzles/dragon-a.png`, which **Delete** removes).
- `docs/briefs/m14/bugs7/dragon-redo/candidate-b.json` — the pieces; sheet `candidate-b-sheet.png`
  (85493 bytes, same as `docs/design/puzzles/dragon-b.png`, which **Delete** removes).

**Recommendation: candidate a** — the clearer silhouette at a glance (one head high at the right end of
a rising neck, the tail curled low at the left, a wing that is clearly neither), one piece lighter, no
repeated shape pair at all, and two legs in different colours (steel, sand) where b's are identical.

Nothing is shipped: the two puzzle files and their renders were scaffolding for the kit and are under
**Delete**, so `packages/` and `docs/design/` end byte-identical to the start. Not done here: I cannot
delete them, so `tools/check.sh puzzle` stays red on both files until the script does (see Checks).

## Kit used
`tools/level.sh` would not run in this job's sandbox: `tools/level.sh`, `tools/level.sh --self-test`,
`dart tools/level_new.dart --help` and `dart --version` were all refused. So, as the brief allows, I ran
the exact commands the kit's table prints, from `packages/puzzle_game`:

- `flutter test --dart-define=puzzleId=dragon-a test/puzzle_check_test.dart`
  → `the rule book over dragon-a` … `+1: All tests passed!`
- `flutter test --dart-define=puzzleId=dragon-a test/puzzle_render_test.dart`
  → `wrote ../../docs/design/puzzles/dragon-a.png (81724 bytes)` / `All tests passed!`
- `flutter test --dart-define=puzzleId=dragon-b test/puzzle_check_test.dart`
  → `the rule book over dragon-b` … `+1: All tests passed!`
- `flutter test --dart-define=puzzleId=dragon-b test/puzzle_render_test.dart`
  → `wrote ../../docs/design/puzzles/dragon-b.png (85493 bytes)` / `All tests passed!`

`tools/level.sh new` could not run either, so the two temporary files were written by hand from
`puzzles/_template.json` with the same fields (`$schema`, `format`, `id`, `name`, `level`, `notes`,
`pieces`), under the ids `dragon-a` and `dragon-b`, and their lines were added to `index.json` by hand so
that the library-wide tests would also cover them.

## Checks
- `tools/check.sh format puzzle`, with both temporary ids listed in `index.json` →
  `PASS format (2s)`, `FAIL puzzle (436 passed, 2 failed)`. The two failures are the library-count
  assertions only (`hard_library_test` "the library has six Hard puzzles": got 8; `library_test` "six
  puzzles at each level, in the order the brief names"), i.e. exactly the two temporary ids. Every
  per-puzzle test over the candidates — schema, colours, measures, start table, rule book — passed.
- `tools/check.sh format puzzle`, final tree (`index.json` back to its 18 ids) →
  `PASS format (2s)`, `FAIL puzzle (435 passed, 3 failed)`. The three failures are `library_test`
  "the whole library has no issues", `puzzle_check_test` "the rule book over the whole library" and
  `puzzle_new_test` "the new puzzle passes the rule book unchanged"; I re-ran `library_test` alone and its
  message is only `puzzles/dragon-a.json is not listed in index.json. Add "dragon-a" after the last
  puzzle of its level.` (and the same for `dragon-b`). All three go away when **Delete** removes the two
  files; I cannot delete files, so I cannot show a green run myself.
- Side effect to know about: the puzzle suite re-renders every design sheet, so those runs rewrote the
  committed PNGs in `docs/design/puzzles/`. They were already modified before this job (uncommitted work
  from earlier jobs, same byte sizes as `HEAD`) and the renders are deterministic; `git status --short`
  for `docs/design/puzzles` still lists the same 12 modified files plus my two untracked `dragon-a/b.png`.
- Not mine and untouched: `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
  `generated_plugins.cmake` were already modified when the job started.

## Decisions
- **Side-view pose, not a scatter of features.** The shipped dragon fails because its parts sit where a
  diagram would put them. Both candidates put every part on one horizontal axis, neck rising at one end,
  tail at the other, so the outline itself is the drawing.
- **Polygons, not rects.** A turned rect is a box with four straight edges, which is exactly what made
  the old dragon look like blocks; a generic polygon is a body part. The cost is known and accepted: a
  generic polygon's start error is a random 90–180°, so its tray box can grow to its diameter, where a
  rect's box is fixed. The rule book tries the tray over 200 start seeds and both candidates pass.
- **10 and 11 pieces is the practical ceiling for a readable dragon.** Every part needs roughly 14–20
  units to clear the 8.5 mm floor on the narrowest phone, and the tray (50×68 usable) holds about this
  many such boxes; denser drawings failed the tray checks in my attempts.
- **Pieces stay compact round their own centre** (max radius 7–10 units). A long thin piece is cheap on
  the board and expensive in the tray, so the long body is a rounded 18×14 blob and the length of the
  dragon comes from the layout, not from one long piece.
- **The head is a story in three pieces:** blue head, red jaw set about 10 units lower with a gap between
  them so the snout reads as open, and a yellow regular-triangle horn above. b mirrors the same three
  pieces to face left.
- **Colours come from the shipped dragon's proven set** (green, blue, purple, slate, brown, silver,
  steel, orange, yellow, red, sand), which keeps the 0.15 board distance safe. One pair broke the 0.08
  piece distance in a first draft of a — `steel` 0.07 from `silver` — so a's front leg became `sand`.
- **b's two legs are deliberately the same shape** (identical polygons) and take the one repeated pair
  the level allows; the colour-pair rule exempts same-shape pieces, so steel + silver are fine there.
- **`index.json` was listed while checking and restored afterwards**, so the delivered tree matches the
  start; listing it for good would break the library once **Delete** removes the two files.

## Self-check (review-rules part A)
1. **Every host setup** — n/a: two JSON proposals outside the library, no code, no build, no host.
2. **When kept state starts and ends** — n/a: nothing is held, timed or remembered.
3. **How a new state combines with the others** — n/a: no state, no input, no pause.
4. **Stay in the job's folder** — yes: only `docs/briefs/m14/bugs7/dragon-redo*`,
   `packages/puzzle_game/puzzles/dragon-{a,b}.json` (+ the `index.json` line, restored) and
   `docs/design/puzzles/dragon-{a,b}.png` were written.
5. **Stop rather than overstep** — I did not delete the temporary files (no permission: they are in
   **Delete**), did not edit any code or doc outside the job's folder, and did not propose a third
   candidate or ship anything.

## Questions and suggestions
1. Is the sandbox refusing `tools/level.sh` expected in worker jobs? I used the commands its table prints,
   so the rule book and the renderer ran, but the kit's own wrapper and `--self-test` were not exercised.
2. Which candidate does the owner want? I recommend a; if b wins, its one repeated pair and the extra
   piece are what to look at on the smallest phone.
3. When a candidate is picked, the follow-up is a one-line `index.json` change plus the render (and
   dropping the `notes` sentence that points at the job folder) — outside this job, whose **Delete**
   removes what would otherwise ship here.
4. `docs/levels.md` could say plainly that a generic polygon's tray box can reach its diameter because
   its start angle is random, while a turned rect's box is fixed. Any picture that needs many organic
   parts (animals, dragons) pays tray rows for it, and that is what limits the piece count to ~11.

## Commit message
Add two dragon candidates for the dragon-redo job

Candidate a is a standing dragon facing right, candidate b a dragon in
flight facing left; both are side views with a head (open snout and horn)
at one end, a wing above the back, a spiked tail at the other end and two
legs. a is 10 pieces / 4 big / 0 repeated pairs, b is 11 pieces / 4 big /
1 pair, every non-circle piece turned, id "dragon" at Hard, and both pass
the rule book over seeds 0-199. Nothing ships: index.json is back to its
18 ids and the temporary puzzle files and renders go with the job. The
sheets are in docs/briefs/m14/bugs7/dragon-redo/ for the owner to pick.

## Status row
Dragon redo: both candidates drafted, checked and rendered — done; the owner's pick, the `index.json` line and the shipped render are open.

## Delete
- packages/puzzle_game/puzzles/dragon-a.json
- packages/puzzle_game/puzzles/dragon-b.json
- docs/design/puzzles/dragon-a.png
- docs/design/puzzles/dragon-b.png
