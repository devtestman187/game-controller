# M14 a3: the finish celebration

Job: `docs/briefs/m14/a3-celebration.md`. Gate: after it. **Status: done.**
`tools/check.sh format analyze puzzle host phone tv` all pass; `tools/review.sh` reports 0 fail, 13 note (size and
numeric-literal notes, all on lines this job wrote or beside them).

## Files changed

| File | What changed |
| --- | --- |
| `docs/briefs/m14/a3-celebration-report.md` (new) | This report. |
| `packages/puzzle_game/lib/src/celebration.dart` (new, 207 lines) | The whole timeline as pure functions: `isRunning`, `popStartMs`, `popScale`, `glowAlpha`, `dimAlpha`, `starsOf`, `confettiOf`, and the records `StarBurst` and `Confetto`. Every constant of the moment lives here. |
| `packages/puzzle_game/lib/src/celebration_paint.dart` (new, 94 lines) | The drawing, a part of `view.dart`: `_paintGlow` (a blurred warm stroke round every locked piece, under the picture), `_paintStars` (the existing `_starPath`, so it is the awards' own star), `_paintConfetti` (rounded, turned bits in `_colours.player`). |
| `packages/puzzle_game/lib/src/view.dart` | `part 'celebration_paint.dart';` and the `celebration.dart` import. |
| `packages/puzzle_game/lib/src/puzzle_painter.dart` | `_finishAge`, `_popScale(i)` (the piece's placement order, its pop, 1 with the effects off); the paint order gains the glow under the picture and the stars and confetti over the field; `_piece` scales by the pop and takes the moving path while it pops. |
| `packages/puzzle_game/lib/src/match_painter.dart` | `_dimming(canvas, size, side)`: a race's losing board dims to 28 % ink over 600 ms while the other celebrates, in `_screen` and in `_phones`. |
| `packages/puzzle_game/lib/src/piece_moments.dart` | `_BoardMoments` notes `phase` and `finishedAtMs`; the class gains `finishAgeMs(board, nowMs)` (from a playing→finished transition, not from a board first seen finished) and `placeOf(board, piece)` (the locked pieces by the time each last changed, unseen ones first by index). |
| `packages/puzzle_game/lib/puzzle_game.dart` | `export 'src/celebration.dart';` |
| `packages/puzzle_game/lib/src/puzzle_events.dart` | `PuzzleEventKind.finished` now plays `celebration` by name (was `success`), with the design and s1 cited in a comment. |
| `packages/puzzle_game/test/celebration_test.dart` (new, 135 lines) | 7 tests: starts on the finish frame and not before; a view built after the finish does not celebrate; the pops follow placement 120 ms apart; the moment ends at 2.5 s; effects off is the still version; no star or bit crosses the picture; the glow breathes once and never flashes. |
| `packages/puzzle_game/test/celebration_paint_test.dart` (new, 76 lines) | 1 painted test: a 640×360 box, one square piece, the paint at 60 ms (0 `focus` pixels), 500 ms (over 40), and after 2.6 s (0 again). |
| `packages/puzzle_game/test/puzzle_session_test.dart` | The team finish expects `celebration` once for the round (not per side), and a new test holds the name: not before the picture is done, once after. |
| `packages/puzzle_game/test/view_test.dart` | The finish's sound expectation is `celebration`. |
| `packages/party_host/lib/src/ui/puzzle_screen.dart` | `_cardTimer` (a `Timer` of `Celebration.totalMs`), `_cardShown`, `_showCard()`; `_finished` shows the card at once when no side finished, else after the moment; the card takes the play view's `match`; `_play` key on the play view. |
| `packages/party_host/lib/src/ui/puzzle_screen_widgets.dart` | `_Results` gains `match` and builds one `_Photo` per side from its board and its field; a photo row above the side rows; `_Photo` (cream frame, ink edge, shadow, −3° tilt, shrink-in 1.25→1 over 260 ms) and `_PhotoPainter` (the round's pieces as they stood, in the field's board rect). |
| `packages/party_host/test/support/host_harness.dart` | `endRound` waits the celebration out (three 16 ms frames, then `Celebration.totalMs`, then a frame). |
| `packages/party_host/test/puzzle_results_test.dart` | Each inline results pump uses `endRound`; new test: the card is absent on the finish frame and at 2300 ms, appears at 2500 ms with `puzzlePhoto-left` and a time rather than "4 of 4 pieces placed". |
| `packages/party_host/test/puzzle_screen_test.dart` | The finished-puzzle test waits with `endRound`. |

No other file inside `allow:` changed, and nothing outside it.

## The timeline, in numbers

All times are milliseconds after the frame the board's `phase` becomes `finished`; all lengths are field units (the
field is 160 × 90, the board `Rect.fromLTWH(16, 13, 80, 72)`).

| Time | What happens |
| --- | --- |
| 0 | The finish is noted; the celebration starts. Glow 0. Stars appear at the board's edge (2.5 units out) at alpha 0; confetti alpha 1. The first-placed piece starts its pop. |
| 0–150 | The stars fade in (alpha = t/150). |
| 0–240 | The first-placed piece's pop: 1 → 1.10 at 120 ms → 1 at 240 ms (`1 + 0.10·sin(π·t/240)`). |
| 120·n | The piece placed (n+1)th starts its pop, so pieces 1, 2, 3, 4 pop at 0, 120, 240, 360 (last start capped at 2260, so its pop ends exactly at 2500). |
| 0–1200 | The stars drift out: `8·(1 − (1 − t/1200)²)` units, so 4 units by 600 ms and 8 by 1200. Radii 0.55, 0.85, 1.15 cycling; the 4 bright ones (`i % 4 == 0`) are gold `focus` with the ink edge, the rest pale `paper` with a `focus` edge. 14 stars, one every 2π/14 from the top. |
| 0–2500 | Confetti: 22 bits at most, falling 34 units/s from a frame 16 units round the board, swaying ±1.5, turning 90°/s from 37° steps, in the 6 player colours. A bit is skipped while its rect would overlap the board, so none is ever over the picture. |
| 900–1200 | The stars fade out (alpha = (1200 − t)/300) and are gone at 1200. |
| 0–2500 | The glow: `0.85·sin(π·t/2500)` — 0 at 0, 0.425 at 625, **0.85 at 1250**, 0.425 at 1875, 0 at 2500. A blurred stroked rim (blur 1.8 units, stroke 0.9 of it) in `star` gold round every locked piece, drawn under the picture. |
| 0–600 | A race's losing board dims: ink at `0.28·min(1, t/600)`. |
| 2000–2500 | Confetti fades out (alpha = (2500 − t)/500). |
| 2500 | The moment is over; the host's card timer fires and the results card appears with the photo. |

The workers' cheer is not new work: `_roundEnd` (a2/a1) already gives the side that finished the happy face, hands up
and the hop, from the same `finished` phase this age is measured from.

## The comfort rules (design 3a, G5), each checked

| Rule | How it is met | Shown by |
| --- | --- | --- |
| Nothing flashes | One brightness change in the whole moment: the glow's single sine breath, slope at most `0.85·π/2500 ≈ 0.00107` a millisecond, so ≤ 0.017 per 16 ms frame and ≤ 0.027 per 25 ms sample, and exactly one change of direction. Nothing is drawn as on/off. | `celebration_test`: the glow samples every 25 ms with \|Δ\| < 0.12 and one direction change. |
| Stars and confetti under a quarter of the screen | 14 stars, each inside a circle of radius ≤ 1.15: at most `14·π·1.15² ≈ 58` units². 22 bits of 1.2 × 0.65: at most 17 units². Together ≤ 75 units² of the field's 14,400 = **0.52 %**, and none of it over the picture. | `celebration_test`: 50 samples, 50 ms apart, every star and bit outside `boardRect.inflate(its radius)` and every bit's rect not overlapping the board. |
| Brightness changes at most once | The single glow breath above; the dim only darkens and then the card covers it. | `celebration_test`: the glow test. |
| Effects off: no pop, no motion | `popScale` is 1; stars stand still at 4 units (half the drift) at full alpha for the whole 2500 ms; no confetti is generated; the glow is a constant `0.85·0.55 = 0.4675` rim; the photo does not shrink (the tween starts at 1). | `celebration_test`: the effects-off test (star positions equal at 600 and 1800); `puzzle_painter`'s `_popScale`; `_Photo`'s `motion`. |
| Stars and the frame appear and go (effects off) | Stars stand still and then vanish with the moment at 2500; the photo is simply there. | The same effects-off test. |
| The card comes after it, never on top | The card's timer is the moment's own length, and only when a side finished. | Host: the new results test (absent at 2300 ms, present at 2500). |

## Where it runs

- **One board (solo, team) and either side of a race**: `PuzzlePainter`, for every board the match draws.
- **The losing side of a race**: no celebration (its board never finished); it dims, hears nothing extra, and the
  card still shows its picture as it stood.
- **The host**: the card waits 2500 ms after `_finished` when a side finished; at time-up it appears at once, as before.
- **A joined phone**: it draws its own `PuzzlePlayView` from the same snapshot, so the celebration is driven by the
  same finish age — no protocol or host change. Its result card is `controller_app`'s own (`result_card.dart`), which
  is outside this job's `allow:` and so does not show the photo yet (see Questions).
- **A mirror**: unchanged (it never showed the board's finish, and a finish does not change the mirror's frame).
- **Outside the finish**: the only change to a picture is `_popScale`, which is 1 whenever no finish was seen; the
  mirror, the tray, the cat and the points drawing are untouched.

## Tests

Before → after (`tools/check.sh`): puzzle **349 → 358** (9 new), host **320 → 321** (1 new; three existing results
tests now wait out the moment through `endRound`), phone **445** (unchanged), tv **21** (unchanged).

Each new test was written and run before its behaviour existed, and failed for the missing behaviour:

| Test | Failed first with |
| --- | --- |
| `celebration_test`: starts on the finish frame, not before | `finishAgeMs` did not exist; then the age was 0 at the finish frame, not only later. |
| `celebration_test`: a board first seen finished does not celebrate | the age at first sight was 0 (celebrated a board it had never seen complete). |
| `celebration_test`: pops in placement order, 120 ms apart | `placeOf` did not exist; then all pieces popped together. |
| `celebration_test`: over after 2.5 s | a 2.5 s age still reported running. |
| `celebration_test`: effects off is still | pops ran and stars drifted with the effects off. |
| `celebration_test`: never crosses the picture | star centres were computed from the board's edges without the corner case, and confetti had no overlap filter. |
| `celebration_test`: the glow breathes once | no glow function; then the peak was not mid-way. |
| `celebration_paint_test`: the burst is painted from the finish and gone after | 0 `focus` pixels at 500 ms (nothing was drawn round the board). |
| `puzzle_session_test`: the sound plays by name once | it played `success` (and a per-side finish played it twice). |
| Host: the card waits, then shows the photo | the card was on screen on the finish frame, and no `puzzlePhoto-left` existed. |

## Decisions

1. **The celebration's age comes from a phase change `PieceMoments` sees, not from the snapshot.** The snapshot has no
   finish time; this is the same rule boing and wobble already use, so a view built after the finish (a joined phone
   joining late, the library's preview) does not replay it. Listed in `piece_moments.dart`.
2. **Placement order is each locked piece's last change time (`changedAtMs`), ties by index.** The snapshot keeps no
   placed sequence, and the last change time is exactly the frame the piece locked. A piece already locked when the
   view first saw it sorts before ones that locked later.
3. **The stars, the confetti and the glow are pure functions of the age** (no `Random`, a golden-ratio scatter), so
   every screen shows the same burst and tests can check positions and areas. This is what makes "a joined phone
   plays the same celebration" true without sending anything.
4. **The glow is a blurred stroke round the pieces' own outlines, drawn under the picture**, so the design's "its
   outline gets a soft warm rim" is literal and the pieces keep their edges.
5. **A race's dimming lives in `MatchPainter`, in both `_screen` and `_phones`.** The losing board has no finish age
   of its own, so the dim is driven by the *other* side's age (`finishAgeMs(1 - side)`); it darkens to 28 % over
   600 ms and is gone at 2500, when the card covers the board.
6. **The card is gated by a `Timer` in `puzzle_screen.dart`, not by a callback from the view.** The view's ticker is a
   repaint clock; the round's end is the screen's own event, and `dispose` cancels the timer. When no side finished
   (time-up) the card shows at once, exactly as before.
7. **The photos sit in a `Row` above the side rows, not beside them.** Beside them the card overflowed 1.4 px on the
   phone host and 47 px on a narrow one; above them it fits 852×393 and 1280×720 (host tests, both modes).
8. **Each photo maps the field's `board` rect, not `boardSize`.** Snapshot positions are field units
   (`targetAt = field.origin + target`), and on the split screen that rect is the picture's crop, so each side's photo
   is its own picture rather than the other side's or a shifted one.
9. **The photo redraws the pieces through `toyShape` with `look.shade`, rather than reusing the board painter.** The
   painters are library-private parts of `view.dart` and the photo is a `party_host` widget; drawing the pieces'
   shapes, colours and angles keeps it a photo of what was made without exporting a painter.
10. **The photo shrinks into place (1.25× → 1 over 260 ms, ease-out cubic) rather than morphing from the board.**
    The board and the card are different widgets with no shared geometry; a true morph would need a second animation
    owner in the screen for the moment's whole length. The shrink is the design's "shrinks into the card" as far as
    this job can honestly go; with motion off (effects off or the platform's disable-animations) it is simply there.
11. **The celebration is clipped to the side's world.** It is drawn inside the board canvas, which is already clipped
    to the field, so a race's burst never spills into the other side or over the clock strip; the cost is that stars
    and bits below the board (only 5 units of room) are cut at the field's bottom edge. Judged the safer of the two.
12. **`celebration` replaces `success` for the `finished` event and nothing else.** The event is the picture's
    completion (not a leg, not a record), so no other game's sound changes.
13. **The results' wait is folded into the tests' `endRound` helper.** Every existing results test keeps its shape and
    reads "the round is over, pump to the card" instead of each carrying its own 2.5 s.

## Questions

1. The joined phone's own result card is `controller_app/lib/src/ui/result_card.dart`, outside `allow:` — design 3a's
   "its own results card holds the same photo" is not done there. The celebration on the phone's play view is automatic.
2. The "New record!" chip and `new_record` sound (design 3a, T15) are not in this job: best times do not exist yet, so
   there is nothing to compare against.
3. The mirror (the TV's small copy of a side's board) shows no celebration; design 3a says "everywhere the round is
   seen". Should the mirror show the burst too?
4. The bottom of the star ring and the lower confetti are cut by the field's bottom edge (5 units of room under the
   board). A ring pulled up to fit would be a shape change; is the clip acceptable?
5. The team finish plays `celebration` once for the round (the session's event fires once), and a race that has both
   sides finishing would too — should each side's finish play it, or one per round as now?

## Self-check (docs/review-rules.md part A, 1–5)

1. **Every host setup**: host tests run the card on a 1280×720 PC host and a 852×393 phone host in both host modes;
   a joined phone draws the same `PuzzlePlayView` from the same snapshot, so it celebrates alike (puzzle and phone
   suites pass); no protocol message changed, so an older peer plays unchanged (nothing on the wire).
2. **When kept state starts and ends**: `_cardTimer` starts only when a side finished, every way it ends is `dispose`
   (a cancel) or the timer firing once; a time-up starts no timer; `PieceMoments` keeps the age until the next
   `puzzleId` or the view's end. Shown by the host card test (2300/2500 ms) and the 2.5 s test.
3. **How a new state combines with the others**: the finish cannot meet pause, away or "Get ready" (the round is over);
   it meets results (the card waits — host test), Play again (a new `puzzleId` resets the moments — `endRound` then
   Play again in `puzzle_screen_test`), leaving (dispose cancels — host tests), and time-up (no side finished, card at
   once).
4. **Stay in the job's folder**: every changed file is inside the job's folder and the `allow:` list; nothing else
   changed.
5. **Stop rather than overstep**: nothing needed outside `allow:`; the joined phone's card (question 1) is reported
   instead of touched, and the mock-up's "New record!" chip (question 2) waits for best times.

## Checks run

- `dart format` on the two party_host UI files (the only ones it reformatted).
- `tools/check.sh format analyze puzzle host phone tv` → PASS format, PASS analyze, PASS puzzle (358), PASS host
  (321), PASS phone (445), PASS tv. Logs in `%TEMP%/thumbparty-check-20261110-134450`.
- `tools/review.sh` → 0 fail, 13 note (size and numeric-literal notes on this job's lines).
- Note: `git status` shows `tv_test_app/windows/flutter/generated_*` as modified with an **empty** content diff (line
  endings only, from the Flutter tooling the checks run). This job edited no such file.

## Commit message

Add the finish celebration: pop, stars, confetti, glow, card photo

When a board's picture is complete its pieces pop in placement order 120 ms
apart to 110 %, 14 stars burst from the board's edge and 22 confetti bits fall
round it (never over the picture), and a warm rim breathes once, all over 2.5 s
from the finish age PieceMoments now keeps. The finished event plays
celebration. In a race the losing board dims. The host's card waits the moment
out, then shows each side's picture as a framed, tilted photo (shrinking in
unless motion is off). With effects off the pops, motion and shrink are gone and
the glow is a still rim.

## Status row

a3 done: the finish celebration is built and tested (pops, star ring, confetti, glow, cheer, `celebration` sound, race dim, the card's photo after 2.5 s); open: the joined phone's own card photo, the New record chip, a mirror burst.

## Delete

- none
