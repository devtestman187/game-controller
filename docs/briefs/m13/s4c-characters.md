job: M13 step 4c: characters, each player shown by a colour and an accessory instead of a number on the body, built so players can choose their own later (design section 5b; PRD L6)
pub: yes
stop: after it.
read: docs/design/look-and-sound.md sections 3, 4, 5a and 5b (all of 5b) · docs/briefs/m13/s4b-worker-report.md and docs/briefs/m13/s5-arena-look-report.md (and Claude's reviews at their ends) · packages/toy_look/lib · packages/puzzle_game/lib/src (worker_painter.dart, worker_pose.dart, puzzle_painter.dart, view.dart) · packages/test_game/lib/src (arena_painter.dart and its parts) · packages/party_host/lib/src/ui/player_badge.dart and every caller of `PlayerBadge` and `ToyBadge` · docs/review-rules.md · docs/coding-guidelines.md

Owner, Nov 8, 2026, on the worker with its number on its tummy: "Having the player number in the face doesn't look very good. Would it make more sense to have a unique color per character instead of character number?", then "Let's do color and an accessory. But we need to ensure the accessory is customizable in the future along with character customizations."

Claude's rules:
1. **The character value, in toy_look:**
   - `enum ToyAccessory { ears, antenna, bow, cap, tuft, crown }`.
   - `final class ToyCharacter` with `colourSlot` (1 to 6, the `player(n)` slot) and `accessory`, value equality, and `ToyCharacter.forPlayer(int number)`: the defaults in design 5b's table (1 ears, 2 antenna, 3 bow, 4 cap, 5 tuft, 6 crown; numbers above 6 wrap as `player(n)` does).
   - `Color colourIn(ToyColors colors)` gives its body colour.
   - It is the only place a player's number becomes a character, so a later milestone can hand painters a chosen character instead (PRD L7). Write that in its doc comment.
   - No protocol, snapshot or rules change.
2. **Accessories, drawn in toy_look:** `paintAccessory(Canvas canvas, ToyAccessory accessory, Offset bodyCentre, double bodyRadius, Color bodyColour, ToyLook look)`.
   - Each is a few simple shapes with the look's ink edge, on top of the body, never over the face (the eyes sit at about −0.3 radii):
     - **ears:** two round ears in the body's colour at ±0.6 radii, half in the body;
     - **antenna:** an ink stalk 0.6 radii tall with a `paper` ball;
     - **bow:** a `paper` bow at the top-right;
     - **cap:** a `paper` cap on top with a brim to the front;
     - **tuft:** three ink hair strokes on top;
     - **crown:** a small `paper` crown with three points.
   - Ink, paper and the body's own colour only, so any accessory suits any of the six colours, any colour added later, and both palettes.
   - Each silhouette differs from the others, so they read without colour.
   - The edge is the look's outline in pixels (use the canvas's whole scale, as 4a's `_pxPerUnit` does, when drawing in a scaled canvas).
3. **Where characters are drawn:**
   - **The worker** (puzzle_game): its body colour and accessory from `ToyCharacter.forPlayer(p.number)`; the number on its tummy goes, and its face stays as it is. Hops, leans and squashes carry the accessory with the body.
   - **The Arena's marble** (test_game): the same. Its number goes, and its eyes stay.
   - **The menus' badges:** `paintToyBadge`/`ToyBadge` take an optional `ToyCharacter`. With one, the badge's disc is the character's colour, keeps its number (the menus have room, and "P1" is how the phone and the words name a player), and wears the accessory on top. `PlayerBadge` in party_host passes `ToyCharacter.forPlayer(number)`, so the join screen, the pause card, the results and the away card show which worker is yours.
   - The phone pad's badge is step 8; leave it.
4. Every caller asks `ToyCharacter.forPlayer` once per player per paint, not once per shape.
5. **Sizes:** a badge's accessory may draw outside its box. A row holding badges must still have room above for it (check the join screen's rows and the pause card), and the fit tests must still pass.
6. **Cost:** no `TextPainter` on the worker or the marble any more. A badge keeps its one.
7. Files under 400 lines, functions under 60.

tests (each failing first):
- toy_look:
  - `ToyCharacter.forPlayer` for 1 to 6, and 7 wrapping to 1's;
  - value equality;
  - `colourIn` is `player(n)` in both palettes.
- **Each accessory, drawn on a 100 px body, in Sunny and Night:**
  - it puts ink above the body's top edge, or beside it for the ears;
  - it leaves the eye area (−0.45 to −0.15 radii) untouched.
  - The six silhouettes differ pairwise: compare their ink masks above the body; no two may share more than 70 % of their ink pixels.
- puzzle_game:
  - the worker's body has no ink in the tummy band any more (4b's worker_number_test inverted: the band is the body's colour);
  - each worker wears its player's accessory: there is ink above the body's top.
- test_game: a marble wears its accessory and shows no number.
- party_host: `PlayerBadge` passes `ToyCharacter.forPlayer(n)`, and a badge on the join screen has its accessory's ink above the disc.
- All existing tests pass (look, puzzle, arena, host, phone, tv). Change only pins of the old tummy number or the marble's number, and list each.

in the report: test counts before and after; the files changed; a table of the six accessories as built (shapes, colours); the silhouette comparison's numbers; any fit that needed room above a badge.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s4c-characters-report.md · docs/design/m12-mirror-169.png · docs/design/m12-mirror-iphone-stick.png · docs/design/m12-mirror-iphone.png · docs/design/m12-mirror-stick.png · packages/toy_look · packages/puzzle_game · packages/test_game · packages/party_host · controller_app/test · tv_test_app/test
check: format analyze look puzzle arena host phone tv
report: docs/briefs/m13/s4c-characters-report.md
