job: M14 m1: mock-ups of the party night's new screens, for the owner's OK before they are built (docs/design/party-night.md section 10)
pub: no
stop: after it.
read: docs/design/party-night.md (all of it: the screens are described in sections 3–9 and listed in section 10) · docs/design/look-mockups.html (M13's mock-up page: its palettes `PAL`, colours `C`, and drawing helpers `toy`, `txt`, `svg`, badges, buttons, cards, the worker and the marbles) · docs/design/look-mockups/ (the M13 pictures, to match) · docs/design/look-and-sound.md sections 1–5b (the look) · packages/party_host/lib/src/ui/host_text.dart (the words the host uses today) · docs/PRD-v2.md "Party requirements" G1–G5, G9, G10 and C20

The owner reviews the new screens before any of them is built, as in M13. Claude's design:
1. **Share M13's drawing parts, don't copy them.** Move the palettes, colours and every drawing helper out of `look-mockups.html` into `docs/design/mockup-parts.js`, loaded by both pages. `look-mockups.html` must draw exactly what it drew before (same SVG text for every frame, theme and effects setting: compare its `out.innerHTML` before and after with a small script you write and delete, or by reading; say how you checked).
2. **A new page, `docs/design/party-mockups.html`**, the same shape as `look-mockups.html`: a header with Sunny/Night and Effects on/off, one `<figure>` per frame, and `?frame=N&theme=sunny|night` drawing one frame alone with no header, so Claude can save each as a PNG.
3. **The frames** (each 1280×720 for the TV unless it says phone; phone frames 780×360 landscape as M13's phone frames):
   1. The game picker with a third card, **Party night**, beside Shape Race and the Arena.
   2. The night's **start card**: "Party night", "3 rounds" (focused) / "5 rounds", the three awards drawn (pictures, names, one line each, e.g. Sharpshooter, Best Helper, Coin Collector), "The cat visits the side that's ahead", then "Pick round 1" with two big buttons, Shape Race and Bumper Round.
   3. **Shape Race in a night**, 1 vs 1: a "+2" pop-up with a star beside a piece just snapped, each side's points beside its badges, and the cat's warning on the right side: the paw at the edge and the shadow on its target piece.
   4. The **scoreboard**, "Round 2 of 3": four players in order, each row a badge (colour and number), nickname, star icon and total, the round's "+7"; two players tied share a place; the two game buttons under it. And a second frame: the same before the last round, with the banner "Last round: double points!".
   5. An **award reveal** (Cat Catcher: picture, name, two tied winners' badges and nicknames, "Shooed 3 cats", "+3"), and the **final scoreboard** with the winner's crown, confetti and "Back to games".
   6. The **Arena's waiting card**: the pairing code, three phones joined (badges and nicknames), two with a ✓ ready, "Press A when you're ready", the mode buttons Bumper / Race, and the map cards (Playroom, Pinball, Toy Factory, Spinning Tops, Block Castle, each a small sketch of its field) with "Surprise me". And a second frame: one player joined and **Robo** beside them (antenna, robot icon, "Robo joins you"), with "Robo: Easy / Medium / Hard".
   7. The **Bumper Round** on the Playroom field: three coins (one sparkling), a gold coin, a dizzy marble (stars round it), a shove, the clock "0:14" in its warning colour, and each player's coins beside their badge with a coin icon.
   8. A **joined phone's results card** in a night (phone): the last frame dimmed behind, "You win!", the side's time, "+12 points", the standings in short, "Waiting for the host to pick what's next."
   9. The **best-times board** (a puzzle's top 3: time, nicknames) and a Shape Race results card with "New record!".
   10. The phone's settings with the **Nickname** field (phone): up to 10 characters, "Shows next time you join".
   Four sketches of the new maps on one TV frame (11): Pinball, Toy Factory, Spinning Tops, Block Castle as section 7b describes them (springs as round bumpers, belts as strips with arrows), so the owner sees the idea before the maps job draws them for real.
4. Words from the design and `host_text.dart`, short and common (G5). No information by colour alone: every badge has its number, every coin its icon, every belt its arrows.

tests: none (a design page). Check by reading the SVG and by the before/after comparison in item 1.

in the report: the frames with their numbers and what each shows; how item 1 was checked; anything in the design you could not draw or had to decide (say what you chose).
self-check: docs/review-rules.md part A, items 4 and 5, one line each.
rules: write only inside this job's folder · install nothing · no code outside docs/design · keep each file under 900 lines (the pages are drawings, not app code) · don't touch the M13 PNGs in docs/design/look-mockups/ (Claude saves the new PNGs)
allow: docs/briefs/m14/m1-mockups-report.md · docs/design/mockup-parts.js · docs/design/look-mockups.html · docs/design/party-mockups.html
report: docs/briefs/m14/m1-mockups-report.md
