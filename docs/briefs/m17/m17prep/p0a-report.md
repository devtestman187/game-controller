# p0a report: night cards at 360x640 and 667x375

## Files changed
- `packages/party_host/test/night_cards_fit_test.dart`: new; measures start, scoreboard (mid-night) and reveal at both sizes with 4 and 6 players, plus a deliberate-overflow case for the measurer. Writes section `nightCards` of p0a-fit.json only when NIGHT_FIT=1.
- `controller_app/test/night_result_fit_test.dart`: new; the phone's night result card (round 2 of 5, and round 5 of 5 with the night's end) at both sizes, 4 and 6 standings, plus the overflow stub. Section `nightResult`.
- `docs/briefs/m17/m17prep/p0a-fit.json`: the measured data (both sections).

## Setup and how the numbers are taken
- Host cards: option C's setup. The host is laid out in frame px (device / min(w/960, h/540)) and measured in dp (x scale). 360x640: scale 0.375, layout 960x1707. 667x375: scale 0.6948, layout 960x540. Same content at 4 and 6 players, so the bands are the same.
- Content = every paragraph plus every decorated box that is not a backdrop (a box covering at least half the view each way is the card or page). Free band = view height less the lowest content bottom. Corner free width = view width less the right edge of the content touching the top 56 dp. Strip need = 2 x one line of the look's body type (dp). Head needs 56 dp.
- Phone card: no frame, dp are real. At 360 dp wide the phone app draws only "Make the window bigger" (`minWindowWidth` 540, controller_screen.dart:221), so the card is not drawn.
- No overflow and no exception in any case (13 + 9 tests pass). The overflow stub is reported by the measurer.

## Host cards (dp)
| card | size | free band | strip needs | strip | corner free width | head | in the way (head) | lowest content |
|---|---|---|---|---|---|---|---|---|
| start | 360x640 | 3.0 | 15.0 | no | 9.0 | no | box [241,40 110x32] (rounds segment) | footer buttons [3,609 354x29] |
| start | 667x375 | 5.56 | 27.78 | no | 27.78 | no | text "5 rounds" | footer buttons [6,317 656x53] |
| scoreboard | 360x640 | 3.0 | 15.0 | no | 7.88 (6p; 4p same) | no | box [10,26 342x90] (4p) / [10,26 342x129] (6p) | footer buttons |
| scoreboard | 667x375 | 5.56 | 27.78 | no | 14.58 (4p), 22.22 (6p) | no | box [19,47 634x167] (4p), text "Round 2 of 5" (6p) | footer buttons |
| reveal | 360x640 | 3.0 | 15.0 | no | 9.0 | no | text "Party night" | footer bar |
| reveal | 667x375 | 5.56 | 27.78 | no | 16.67 | no | text "Party night" | footer bar |

Body line: 7.5 dp at 360x640, 13.89 dp at 667x375. Smallest text in frame px: start 18.0, scoreboard 15.0, reveal 23.4 (floor 20). Start and scoreboard have texts under the floor: "Round 2 of 5" 15.0, the two game names 18.72 and 18.0 (and two empty-text paragraphs at the same sizes). Not asserted (see questions).

The band is below the footer bar, which sits at the bottom edge of the view at both sizes. At 360x640 the layout is 1707 frame px tall, so the middle of the screen is empty space; the footer is pinned to the bottom, so the free band at the bottom is 3 dp. Space for a strip would have to come from the middle or from reserving it, not from the bottom.

## Phone result card (dp, 667x375 only; 360x640 shows "Make the window bigger")
| moment | players | smallest text | free band | strip needs | strip | corner free width | head |
|---|---|---|---|---|---|---|---|
| round 2 of 5 | 4 | 15.0 | 40.0 | 40.0 | yes (equal) | 123.5 | yes |
| round 2 of 5 | 6 | 14.06 | 21.37 | 40.0 | no | 110.34 | yes |
| round 5 of 5, night end | 4 | 11.58 | 14.43 | 40.0 | no | 75.63 | yes |
| round 5 of 5, night end | 6 | 10.34 | 10.94 | 40.0 | no | 58.2 | yes |

The card shrinks as a whole to fit (FittedBox), so its text is under 15 dp from 6 standings on. The strip fits (exactly) only with 4 standings mid-night. Body line 20.0 dp.

## Conclusion (owner's Q3)
1. At 360x640 a host's card (portrait, 960x1707 frame px) has no corner room for a 56 dp head: the free width is 7.9 to 9 dp, and no strip room: 3 dp below the footer.
2. At 667x375 the head does not fit on any host card (14.6 to 27.8 dp free of 56) and the 2-line strip does not fit (5.56 dp of 27.78).
3. Without a reserved strip or a corner given up by the card, neither fits on the host cards at either size; option C's strip (reserving room under the layout) is the setup that gives it.
4. On the phone card the head fits at 667x375 in all four cases; the strip fits only mid-night with 4 players. At 360 dp wide the phone shows no card.
5. So: setup screen and Thumby do not fit at 360x640 without something like option C; the measure is of the cards as they are today, with nothing moved.

## Questions
1. The brief asked to assert the 20 px floor; start and scoreboard are under it (15.0 to 18.72), so an assertion would fail the suite. I recorded `belowFloor` in the json and left it out of the asserts. Should a failing floor check stay as a recorded finding?
2. The phone card at 360x640 is the "Make the window bigger" screen, not a card; I assert that instead of measuring a card. Is 360x640 meant as the portrait window of the phone-as-host, or the phone held in landscape (640x360)?

## Suggestions
- Measure the host cards at 640x360 as well: that is where the phone host actually lies.

## Commit message
m17prep p0a: measure night cards for Thumby head and strip fit

Measuring tests (NIGHT_FIT=1 writes p0a-fit.json) for the host's night
start, scoreboard and reveal cards and the phone's night result card at
360x640 and 667x375 with 4 and 6 players. Records free band, corner free
width and the verdict for a 56 dp head and a 2-line strip. No lib change.
Finding: no host card has the room at either size; the phone card has
head room at 667x375 only.

## Status row
p0a done: night cards measured (p0a-fit.json): neither the 56 dp head nor the 2-line strip fits on any host card at 360x640 or 667x375; phone card fits the head at 667x375 only. Open: 20 px text floor is broken by start/scoreboard (15 to 18.72 px); owner's Q3 decision.

## Delete
- none
