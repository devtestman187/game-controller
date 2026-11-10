# M14 m1: mock-ups of the party night's screens

Job: `docs/briefs/m14/m1-mockups.md`. Gate: after it. **Status: done.**

Three changes, all in `docs/design`: the look's parts moved into `mockup-parts.js` (loaded by both pages),
`look-mockups.html` cut down to its frames and drawing exactly what it drew before, and a new
`party-mockups.html` with fifteen frames of the party night's screens, for the owner's OK before c1, b2, c2 and c3.

## Files changed

| File | What changed |
| --- | --- |
| `docs/design/mockup-parts.js` (new, 303 lines) | The palettes `PAL`, the colours `C`, `T`/`FX`/`uid`/`defs`, the colour helpers, the primitives and `svg`, the Shape Race board (`PIECES`, `boardSide`, `clockChip`), the worker (`arrow`, `worker`), the Arena's parts (`marble`, `flag`, `bumper`), the phone's (`pad`, `faces`, `phone`, `toggle`), and the renderer: `renderFrames(F)` and `startPage(F)` with `?frame=N`, `?theme`, `?fx=0` and the four header buttons. All moved text is unchanged from M13's page except the render function's name and its `F` parameter. |
| `docs/design/look-mockups.html` (218 lines, from 507) | `<script src="mockup-parts.js"></script>` before its own script; the eleven frames and `raceTV` stay, and the page ends in `startPage(F);`. Nothing else changed. |
| `docs/design/party-mockups.html` (new, 435 lines) | The party night's page: the same head and style as M13's (figcaption 1280 wide), a Sunny/Night and Effects on/off bar, one `<figure>` per frame, and `?frame=N&theme=sunny|night` for one frame alone with no header. Its own parts: a star, a coin, a paw, a crown, an award rosette, a cat face, a robot head, a cat shadow, confetti, the Playroom/Pinball/Toy Factory/Spinning Tops/Block Castle fields, a map card, a scoreboard row and `scoreFrame`, and a joined-player row. |
| `docs/briefs/m14/m1-mockups-report.md` (new) | This report. |

## How item 1 was checked (the page must draw exactly what it drew before)

No JavaScript engine exists on this PC: `node` and `python` are not installed, and `dart`, browsers and
`powershell` all need approval I don't have, so the before/after script the brief offers could not be written and
run. It was checked by reading and by checksums instead:

1. **The moved blocks are byte for byte the old ones.** `git show HEAD:docs/design/look-mockups.html | tr -d '\r'`
   and `cat mockup-parts.js | tr -d '\r'` were cut to the block ranges below and compared with `md5sum`; each pair is
   equal:
   - palettes, colours and `T`/`FX`/`uid`/`defs`: HEAD 34–44 ↔ parts 6–16 — `ac10fe74af73b914e36b978cbd3d8fa1`
   - colour helpers: HEAD 46–50 ↔ parts 18–22 — `b377a89d644c378e38c9aebc72c6523f`
   - primitives and `svg`: HEAD 52–145 ↔ parts 24–117 — five ten-line chunks all equal (`c89b68f3…`, `3cb0b64d…`,
     `cc582663…`, `cc1c57fb…`, `65179ecf…`)
   - the Shape Race board: HEAD 147–193 ↔ parts 119–165 — `59268cd4e67e6125eb401ef58e0babc5`
   - the worker: HEAD 367–430 ↔ parts 167–230 — `3a01cacb11282107e47c3948d006bbc1`
   - the Arena's marble, flag and bumper: HEAD 276–294 ↔ parts 233–251 — `03c1c3e51666ac45cc04b45a15bf6193`
   - the phone's D-pad, faces and frame: HEAD 310–328 ↔ parts 254–272 — `a3e33c7080d8ec7e0ef2bd92ddeb53e8`
   - `toggle`: HEAD 451–454 ↔ parts 273–276 — `06e238ce67fa2079c38a8b8484e844d7`
2. **The frames are untouched.** `git diff --stat` is 2 insertions, 291 deletions: the insertions are the
   `<script src="mockup-parts.js"></script>` line and `startPage(F);`. There are six hunks (`@@ -30`, `-273`, `-307`,
   `-364`, `-448`, `-478`), and every deleted line is one of the blocks above; no line inside `raceTV` or any of the
   eleven `F.push` frames is deleted (the only frame text in the diff is the context that follows each block).
3. **The renderer does the same.** The old `render()` statements — the `out` reset, the `frame` filter, `uid = i * 1000;
   defs = []`, `svg(w, h, draw())`, the `figure` markup, the `.bar button` toggles — moved verbatim into
   `renderFrames(F)`; the old start-up block (theme, fx, the `single` class and header removal, the four button
   handlers) moved into `startPage(F)` with the same order, and `document.fonts.ready.then(…)` then a first render
   are unchanged. The only differences are the function's name and `F` being a parameter.

With the same `PAL`, `C`, helpers, frame list and render statements, every frame / theme / effects setting produces
the same SVG text as before.

## The frames of `party-mockups.html`

TV frames are 1280×720. Phone frames are 816×384 files holding a 780×360 screen, as M13's. The brief's ten items
that say "and a second frame" become separate figures, so the page has fifteen; the brief's item 11 (the maps) is
figure 15.

| # | Size | What it shows |
| --- | --- | --- |
| 1 | TV | The game picker with three cards. **Party night** (crown, three award rosettes, "3 or 5 rounds, points, awards") has the focus ring; Shape Race and the Arena are unchanged. Stats and Back under them, the D-pad hint bottom right. |
| 2 | TV | The night's **start card**: "Rounds" with **3 rounds** focused and "5 rounds"; "The night's three awards" as three cards — Sharpshooter (fewest wrong drops), Best Helper (most carries home together), Coin Collector (most coins picked up), each a rosette; "The cat visits the side that's ahead." with the cat's face; "Pick round 1" with two big buttons, Shape Race and Bumper Round. |
| 3 | TV | **Shape Race in a night**, 1 vs 1: two boards; a "+2" pop-up and a star beside the piece just snapped; each side's points beside its badge with a star (Mia 7, Dad 5); on the right the cat has come — its ink shadow lies on the target triangle and its paw is clipped by the frame's edge, with "A: shoo the cat". |
| 4 | TV | The **scoreboard**, "Round 2 of 3": four rows in total order, each with the place, the badge (colour and number), the nickname, a star and the total, and the round's "+7". Mia 21 (+7), Dad 18 (+5), Sam 14 (+4) and Ada 14 (+2) share third as "3=". The two game buttons under it. |
| 5 | TV | The **same before the last round**: the same rows with no round's points, and the focus-coloured banner "Last round: double points!" between the header and the rows. |
| 6 | TV | An **award reveal**: Cat Catcher with the cat's face and two paw prints, "Two winners" (badges Dad 2 and Ada 4), "Shooed 3 cats", "Most cats shooed in the night", and "+3 points". Confetti at the edges. |
| 7 | TV | The **final scoreboard**: "Final scores", the winner's row in the focus colour under a crown, totals 34 / 30 / 21 / 19, confetti, and a focused "Back to games". |
| 8 | TV | The **Arena's waiting card** over the dimmed Playroom field: Bumper (focused) and Race; the code 4821; "Press A when you're ready."; Mia ✓, Dad ✓, Sam ✗; the map cards Playroom, Pinball, Toy Factory, Spinning Tops, Block Castle (each a small sketch) and "Surprise me". |
| 9 | TV | The same card with **Robo**: one joined phone (Mia ✓), Robo with its antenna head and ✓, "Robo joins you", "Robo:" Easy (focused) / Medium / Hard, and Pinball, Toy Factory and Surprise me. |
| 10 | TV | The **Bumper Round** on the Playroom field: three field coins (one sparkling, so not takable), a gold coin (inner star) in the last 15 s, a coin just dropped (arrow from the dizzy marble), the shove's burst and speed lines, the dizzy marble's three stars; the top bar with "Bumper Round", Playroom, "0:14" in the warning colour, each player's badge with a coin icon and count, and "A: dash". |
| 11 | Phone | A **joined phone's result in a night**: the last board dimmed behind, "You win!", Mia and 0:58, "+12 points", the standings in short (Mia 12, Dad 9, Sam 5) and "Waiting for the host to pick what's next." |
| 12 | TV | The **best times board**: "Best times", "Shape Race · Tree · Easy", the top three with a star on the first — 1 Mia 0:58 (focus colour), 2 Dad 1:06, 3 Sam 1:24 — and Back. |
| 13 | TV | A **Shape Race results card with "New record!"**: the boards dimmed, "Left wins!", the "New record!" chip with sparkles, Left 0:58 4/4 and Right — 3/4, Rematch focused, Change teams, Back, confetti. |
| 14 | Phone | The phone's **settings with the Nickname field**: "Nickname", "Mia" with a caret and "3 / 10", Save, "Up to 10 characters: letters, numbers and spaces.", "Shows next time you join.", and the preview row "Mia … on the TV". |
| 15 | TV | The **four new maps as sketches**, 2×2: Pinball (lane stripes, spring clusters, two spinners), Toy Factory (three belts with arrows, crates, yellow edge), Spinning Tops (round rug, ring of tops, walled island with four doors, goal behind it), Block Castle (short walls and doorways, a loose maze). Springs are the red round bumpers; the race goal is drawn in each. |

## Decided while drawing (the brief left these open)

- **Two frames for item 5** — the award reveal and the final scoreboard — so each is a whole TV picture; likewise the
  second frames of items 4, 6 and 9. The frame count (15) and the maps as figure 15 follow from that.
- **The focus** on the picker is on Party night, the card the owner is reviewing, not on Shape Race as in M13.
- **The picker's buttons** are Stats and Back; Puzzle settings stays with the puzzle pick.
- **Award lines** are the qualifiers of section 6, shortened to two short lines: "Fewest wrong drops", "Most carries
  home together" (kept on one line here), "Most coins picked up".
- **The cat's colour** is not named by the design; I chose a soft grey-violet (`#9A8BB0`) so it reads in both palettes.
  Its shadow is the ink at 30% over the target outline (a still picture can't put a shadow under a piece), and the paw
  is drawn at the frame's edge, clipped, as if the cat were just out of sight.
- **Robo** is drawn as a head with an antenna and eyes beside its name instead of a numbered badge, and its level
  buttons sit under its row; the design's 7a says no number for it.
- **No meaning by colour alone**: the gold coin carries an inner star, the sparkling coin its sparkles, the dropped coin
  an arrow from the marble that dropped it, the ready row a ✓ (not a green dot), the tie a "3=", the crown the winner,
  every belt its arrows, and every badge its number.
- **The numbers are made up but consistent**: 21/18/14/14 after round 2, 34/30/21/19 at the end, 0:58 the record,
  4821 the code (as M13's pages). Totals and the round's points are separate columns so the scoreboard can show both.
- **The Bumper field** uses Playroom's wall and spring positions (section 7b's first map) without a goal pad, since the
  Bumper Round has none; coin and marble positions are illustrative, not playable data.
- **Phone frames** are 816×384 files with a 780×360 screen inside, as M13's, and `phone()` draws the shell.

## Could not be drawn

- **Sound**: the cat's meow, `fanfare`, `celebration` and `new_record` are cues, not pictures.
- **Movement**: the cat's walk and bat, Robo steering, a marble's roll; only still moments are drawn. Sparkles stand
  for the 1 s of a new coin, and the belts' arrows are still with effects off (the page draws both).
- **The PNGs**: no browser can be started here, so `docs/design/look-mockups/m14-*.png` are not saved. Per the brief,
  Claude saves them from this page in Sunny and Night for each frame.

## Self-check (docs/review-rules.md part A, items 4 and 5)

4. **Stay in the job's folder.** Only the four files in `allow:` were written (`git status --short`); the three modified `tv_test_app/windows/flutter/generated_*` files were already modified in the working tree and were not touched.
5. **Stop rather than overstep.** Nothing outside `allow:` was needed and no brief rule contradicted the design; the one choice left open (item 5's "and" — one frame or two) is made as two frames and named above.

## Checks run

- `git diff --stat -- docs/design/look-mockups.html` → 2 insertions, 291 deletions; `git diff -U3` read in full.
- The eight block checksums above (`md5sum` after `tr -d '\r'`), all equal.
- `wc -l`: `mockup-parts.js` 303, `party-mockups.html` 435, `look-mockups.html` 218 — under the brief's 900.
- Balanced text: `tr -cd` counts give 512/512 parentheses, 497/497 braces, 220/220 brackets, 676 double quotes,
  108 backticks, and 679 apostrophes = 666 string delimiters + the 12 in the double-quoted notes + 1 escaped in a
  single-quoted note. All files read line by line after writing.

## Questions and suggestions

1. Is two frames for item 5 (award, then final scoreboard) right, or would one frame showing the award over the final
   scoreboard be clearer to the owner?
2. The picker's Party night line "3 or 5 rounds, points, awards" has no `HostText` string yet; c1 will need one. Same
   for "Party night", "Final scores", "Bumper", "Robo:" and "Surprise me" — is that c1's string table work, or should
   the words differ?
3. Should the cat's paw be fully inside the board's edge (as drawn for the shadow) rather than clipped by the frame?

## Commit message

```
design: M14 party night mock-ups drawn from M13's parts

Move the look's palettes, colours and drawing helpers out of look-mockups.html into
mockup-parts.js, loaded by both pages; look-mockups.html draws what it drew before (the eight
moved blocks are byte for byte the same).
New party-mockups.html: fifteen frames, TV at 1280×720 and phone at 816×384, one figure each,
?frame=N&theme=sunny|night for one alone; words from docs/design/party-night.md and host_text.dart.
Frames: the picker's Party night card, the start card, Shape Race in a night with the cat, the
scoreboard and its last-round banner, an award, the final scores, the Arena's waiting card and
Robo's, the Bumper Round, a joined phone's result, best times, a new record, the nickname field and
the four new maps.
```

## Status row

M14 m1 done: mockup-parts.js shared by both pages (eight moved blocks byte for byte, look-mockups.html draws what it drew before) and party-mockups.html with fifteen frames (Sunny/Night, effects on/off, ?frame=N); open: the owner's OK before c1/b2/c2/c3, and Claude saves the m14-* PNGs (no browser here).

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted, with fixes in m1b. Checked: `look-mockups.html` draws M13's eleven frames exactly as before (Claude
screenshot each frame in Sunny and Night from the old page and the new with headless Chrome: 22 of 22 identical),
and saved all fifteen new frames in both palettes. The frames follow the design; the owner sees them after m1b.
- **Fix in m1b**: frame 3's "+2" belongs beside the piece just snapped, and the cat's shadow on the tray piece it is
  going for (A little never touches a placed piece); springs are drawn red, which is the Arena's hazard colour; the
  badges lack the accessory the app's badges draw since M13.
- Questions: 1 (the third card on the picker) as drawn; 2 (`HostText` strings) are c1's; 3 (the paw clipped by the
  frame) is fine, it reads as the cat just out of sight.
- The owner's new finish celebration (design section 3a) adds two frames in m1b.
