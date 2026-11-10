job: M14 m1b: three fixes to the party night's mock-ups and two new frames for the finish celebration (docs/design/party-night.md sections 3a, 7b, 10)
pub: no
stop: after it.
read: docs/design/party-night.md sections 3, 3a, 5, 7b, 10 · docs/briefs/m14/m1-mockups-report.md (what each frame is) · docs/design/party-mockups.html · docs/design/mockup-parts.js · docs/design/look-and-sound.md sections 5a (the worker's faces and arms) and 5b (characters)

Claude's review of m1 found three things to fix, and the owner asked for a new moment (Nov 9, 2026: "once a shape race puzzle is complete, can we show an animation or special effect around the puzzle showing that it's completed? Right now a card just covers the picture"). Claude's design:
1. **Frame 3 (Shape Race in a night)**: the "+2" pop-up sits beside the piece just snapped on the board (the sun, with its sparkle), not by the tray. The cat's shadow lies on the exact piece it is going for, a loose or tray piece (A little never touches a placed piece): put it on the right side's tray triangle, not on an outline on the board. Keep the paw at the edge; clipped by the frame is fine.
2. **Springs are not red.** Red round discs are the Arena's hazards. Draw a spring as a yellow coil under a green cap (top-down: a green disc with an ink edge and a yellow ring under it, two short coil lines showing), in frame 15's Pinball, in the map cards of frames 8 and 9, and anywhere else a spring appears. Hazards stay as they are.
3. **The badges**: keep the number, and add the player's accessory as the app's badges do since M13 (look-and-sound 5b: player 1 round ears, 2 an antenna with a ball, 3 a bow, 4 a cap; ink and paper only, on top of the disc). Draw one small `accessory(kind, x, y, size)` part in `mockup-parts.js`, used by every badge on the party page. Don't change `look-mockups.html`'s frames.
4. **Two new frames for the finish celebration** (section 3a), both TV 1280×720, added after frame 13 so the numbering of 1–13 holds and the nickname and maps frames move to 16 and 17:
   - **14, "Picture complete!"**: one board (solo, Tree), the picture finished: a ring of stars bursting from the board's edge, confetti falling round the board (not over the picture), the picture's outline with a soft warm rim, two pieces mid-pop (one at 110%), the worker cheering (arms up, happy face). No card yet.
   - **15, the results card with the photo**: the finished picture as a framed photo in the card (cream frame, ink edge, small shadow, tilted about 3°), beside "Done! 0:58", "4/4", "New record!" and the buttons (Play again focused, Back), over a dimmed, empty board area.
5. Then update the report's frame table and the page's captions.

tests: none (a design page). Claude saves and checks the PNGs.

in the report: what changed in frames 3, 8, 9 and the maps frame; the two new frames; the accessory part's signature.
self-check: docs/review-rules.md part A, items 4 and 5, one line each.
rules: write only inside this job's folder · install nothing · no code outside docs/design · keep each file under 900 lines · `look-mockups.html` must still draw exactly what it drew (only add to `mockup-parts.js`; don't change the existing parts' output) · don't touch the PNGs (Claude saves them)
allow: docs/briefs/m14/m1b-mockups-report.md · docs/briefs/m14/m1-mockups-report.md · docs/design/mockup-parts.js · docs/design/party-mockups.html
report: docs/briefs/m14/m1b-mockups-report.md
