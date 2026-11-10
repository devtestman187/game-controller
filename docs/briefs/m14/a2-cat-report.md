# M14 a2 — the cat and the Chaos setting (G3)

Stop: the brief's `stop:` is "after it", so the job runs the whole G3 slice — rules, tests, snapshot, drawing, the
setting, a1's three follow-ups — and stops there. The night itself (job c1) is not started: the cat has no night
rule, exactly as the brief says, because the night will set Chaos off for its last round.

The cat is a `CatChaos` in `puzzle_game`, owned by `PuzzleMatch` and stepped after the sides' ticks from the
match's seed; it visits a side, warns, walks, bats a piece and runs off, and a worker's A on it sends it away for
the round. `PuzzleSettings.chaos` is the `off`/`little`/`party` setting (library default `off`, host default A
little), it rides in snapshot version 2 as a top-level `cat`, and a phone's HUD has a points line in a night.

## The cat as built: states and timings

`CatRules` (`lib/src/cat_view.dart`) holds every number, so the view, the rules and the tests agree:

| State | Length | What it is | Drawn as |
| --- | --- | --- | --- |
| away | — | no cat in the frame | nothing |
| `warning` | 2.0 s (`warningS`) | at the edge of the side it will visit, on the exact piece's line (`edgeInset` 3.5 units in from that side, clamped into the field) | the paw at the edge, the cat's shadow on the target piece |
| `walk` | 1.2 s (`walkS`) | from the edge to the piece's middle | the face moving in, the shadow still on the piece (effects off: the face at the piece) |
| `bat` | 0.4 s (`batS`) | where the strike happened: the piece is batted (or knocked) at the *start* of this state | the face |
| `leave` | 1.2 s (`leaveS`) | from the strike back to the edge | the face running off (effects off: nothing) |

A visit is `visitS = 4.8 s` (2 + 1.2 + 0.4 + 1.2). The warning's `meow` and the bat's `bump` are events
(`catWarning`, `catBat`) emitted at the state's first frame; a shoo emits `catShooed`. Each event carries the
piece's id, and the bat says `knocked: true` when the piece went back to the tray.

The clock: the match steps the cat inside its own `update`, after the sides' ticks, and only while the round
is undecided (`if (_result == null) events.addAll(_cat.update(dt))`). A pause, the host away or a player away
publishes no steps, so the cat stands still; `_decide()` calls `_cat.endRound()`, which sends it away and cancels
every visit still planned. Chaos `off` does the same on every step. There is no wall clock, timer or `Random()`
without a seed anywhere in it: `Random(seed ^ _salt)` (`_salt` 0x0CA7) keeps the cat's draws apart from the tray's,
which use `Random(seed)`.

When the visits come (`_plan`): one for `little`, two for `party`, each inside its share of the window between
`graceS` 20 s and `tailS` 10 s before time-up, and early enough in its share to be gone before the next share's
visit is due (`room = max(0, share - visitS)`). A 120 s round therefore spreads them; a 40 s round (the tests')
plans them at 20.0 s and 22.6 s and the second one actually arrives at 24.8 s, when the first cat has gone.

## Targeting and limits: each rule with its test

| G3's rule | As built | Test (`cat_test.dart` unless named) |
| --- | --- | --- |
| warned at least 2 s ahead | the warning is exactly 2.0 s, and the bat comes 3.2 s after it | "the warning comes 2 s before the bat, on the piece the cat bats" |
| the side ahead in pieces placed, either on a draw | `_leader()` takes the highest `placed`, and on a draw the seeded pick | "the cat goes to the side ahead in pieces placed" |
| either side on a draw, never the same side twice in a row | the pool drops `_lastSide`; on a draw the two visits take one side each | "on a draw the cat may go either way, and never the same side twice in a row" |
| none in the first 20 s or the last 10 s | the plan's window, and `_due` refuses a visit that would run into the tail | "the cat never comes in the first 20 s or the last 10 s" |
| A little: at most once, only a loose or tray piece, batted to another free spot | one planned visit; `_mayKnock` is false below Party; the target is the topmost tray/loose piece; `_freeSpot` finds a grid place where the full-size box fits, clear of the picture's outlines and every other piece | "A little comes once a round, bats a loose or tray piece, and never a placed one" |
| Party: at most twice, one knock a round, only on the side ahead by at least one piece | two planned visits; `_mayKnock` requires `!oneBoard`, Party, `!_knocked`, `placed <= total - 2` and every other side behind | "Party knocks one placed piece of the side ahead back to its tray, and the side keeps its points" |
| never the picture's last piece | the `placed <= total - 2` test: knocking one of a side's placed pieces with only one left would take the round from it | "Party leaves the picture's last piece alone" (3 of 4 placed: the cat bats the single tray piece instead) |
| never one placed in the last 3 s | the target is the newest placed piece with `elapsedS - placedAtS >= settledS` (3 s) | "Party takes an older placed piece and leaves one placed in the last 3 s" (a piece placed 6 s and one 1 s before the warning: the 6 s one goes) |
| the knocked piece goes back to that side's tray with its outline glowing | `catKnocks` returns it to `trayPos`/`trayAngle` and sets the game's `_catGlow` to its outline, which rides in the frame's `hn` | same knock test: state `tray`, `pos == trayPos`, `hintTargets` contains the outline |
| and the side keeps its points | nothing is subtracted anywhere | same knock test: `points` before == after |
| one board (solo, team) never loses a placed piece | `_mayKnock` is false when `oneBoard` | "a one-board round keeps every placed piece" |
| never in the night's last round | no rule here: the night (c1) sets Chaos off for that round — said in `CatChaos`'s doc comment | — |
| Chaos off never brings the cat | `update` returns at once and `_away()` | "Chaos off never brings the cat" |
| the cat's clock stands still while the round does | no step, no movement | "the cat's clock stands still while the round does" (ten `update(0)` calls leave 2000 ms of warning, then one 50 ms step takes it to 1950) |
| the same seed gives the same cat | one seeded `Random`, drawn from only inside the cat | "the same seed gives the same cat, frame for frame" (two matches, same starts and bats) |

## Shooing

A worker within `PuzzleGame.pickupReach * settings.pickupRange * 2` (3.38 × 2 = 6.76 field units, a worker's
reach plus a little, so a dot on the paw always shoos) who presses A during the warning or the walk sends the cat
off: `CatChaos.shoo` runs from where it stood (state `leave`), cancels every remaining visit, and returns the
place for `PuzzleGame.awardCatShooed(id, at)` (a1's hook: +1 × `pointsScale`, a star pop-up at the cat) and the
player's `catsShooed`. A on the cat *always* wins: `_tapAll` asks the cat first and skips `_pickUp` when it took
the shoo, so a piece under the dot stays where it is. Tests: "a shoo during the warning always works, and the cat
stays away for the round", "a shoo during the walk works too", "a shoo earns the shooer's side +1, more at a
night's last round, with a pop-up" (scale 1 and 2), "the shooer's catsShooed counts in the round's stats" (read
from `MatchResult.round`), "A on the cat shoos rather than picking a piece up".

## The Chaos setting

- `PuzzleSettings.chaos` (`off`, `little`, `party`), JSON `chaos` as the enum's name, unknown names fall back to
  the default. The library's default is `off` (N12), so every existing rules test runs with no cat and no new
  frame bytes — tests: "the Chaos setting travels as its name, and a name this build doesn't know is Off",
  "Chaos off never brings the cat".
- `pointsScale` is now validated in `ranges` (1..4, step 1) like `timeLimitS`; `night` stays a bool check (it is
  not a number): "an out-of-range pointsScale is refused like the clock is" (9 → 4, 0 → 1, 2 → 2).
- The host: `puzzleSettingsProvider` and `PuzzleSettingsNotifier` moved by a pure move into
  `lib/src/puzzle_settings_provider.dart` (exported from `providers.dart`, so its readers are unchanged), and the
  notifier's default and `reset()` became `hostPuzzleDefaults` = the library's defaults with `chaos: little`.
- Puzzle settings: a card at the top of the screen with the three buttons ("Off", "A little", "Party"), the chosen
  one ticked, and one line under them ("It bats a loose piece; on Party it also knocks one placed piece back to the
  tray"). Tests: `packages/party_host/test/puzzle_settings_screen_test.dart`'s "the cat's three buttons set the
  Chaos setting, saved, and a new host plays on A little".

## The snapshot: `sd` and `cat`

Still version 2 (unreleased until M14 ships), two additions, both listed in `docs/protocol.md`:

- Each board carries `sd`, the side that plays it (`0` left, `1` right), left out when null.
  `MatchSnapshot.points` now reads it instead of the board's place, so a one-board round that plays for the right
  reports its points to the right. A board built by hand without `sd` falls back to its place, which is what
  `points_test.dart` builds. Tests: "each board says its side, and the match's points read them" (boards whose
  sides are swapped in the list), "a one-board round that plays for the right says so in its board".
- A top-level `cat` while the cat is out, `[state, side, x, y, warning ms, target]`, and no key at all while it is
  away. `MatchSnapshot.lerpTo` moves it between frames and draws it as the nearer frame has it when it comes or
  goes. Tests: "the cat rides in the frame while it is out, and a frame without it means no cat" (the cat comes
  back as it went out, field by field), "a frame of four players, the most pop-ups and the cat stays under 2048
  bytes".

A sample frame from the tests (a 1v1 of `flatWorld`, both trays full, the cat warning on the right about piece 3
with its whole 2 s left):

```json
{"v":2,"b":[{"v":2,"pz":"flat","sd":0,"t":19784,"ph":0,"pc":[[410,215,0,0],[410,265,0,0],[410,315,0,0],[410,365,0,0]],"pl":[[1,80,80]]},{"v":2,"pz":"flat","sd":1,"t":19784,"ph":0,"pc":[[410,215,0,0],[410,265,0,0],[410,315,0,0],[410,365,0,0]],"pl":[[2,740,80]]}],"sd":709911204,"cat":[0,1,785,365,2000,3]}
```

## Drawing

`paintCat` (part of `view.dart`, `lib/src/cat_paint.dart`) draws the paw, the face and the shadow from the frame
only: the shadow on the exact target piece while it warns and walks, the paw at the edge in the warning, the face
on its way, at the strike, and running off. It is passed into `PuzzlePainter` (the one board and the one at the
top of a phone's whole match), into `MirrorPainter` (the other side's picture) and into `MatchPainter`'s screens
and phones, always as `s.cat` and only to the board whose side the cat is on. With the effects off the walk is not
drawn: the face appears at the piece and the leave draws nothing, and the cat still comes (G5). Nothing flashes —
the paw, the face and the shadow are static in their states. Tests (`cat_paint_test.dart`): "the cat draws its paw
and its shadow in the warning, and comes with the effects off too" (pixels differ from the same frame without the
cat, and again with `effects: false`), "with the effects off it goes without the walk: nothing is drawn as it
leaves" (identical pixels).

The cat's colour is the look's `wall` — the violet the look owns in both palettes — because `review.sh` fails any
`Color(0x…)` outside `toy_look` and `toy_look` is outside this job's allow list. The mockup's plum
(`0xFF9A8BB0`) is close, and the ink edge and shadow are the look's, so it reads the same in Sunny and Night
(Question 1).

## a1's follow-ups

- **Q1, the phone host's HUD panel gets points.** `phoneHud` (with `_boardOf`, `_otherSide`, `_sideName`, `_clock`)
  moved out of `match_painter.dart` (400 → 355 lines) into `lib/src/phone_hud.dart`; `camera.dart`'s `_fitting` and
  `_hudUnder` moved out (399 → 356) into the part `lib/src/camera_fit.dart`. In a night `phoneHud` appends one
  line to the score ("· 7 pts", or "· 7 · 5 pts" for the whole match) **and** to the short lines, so the camera's
  own size for the area reserves it without any change to `hudPlace`. Test: "the phone panel shows the points line
  only in a night, and the camera reserves it" (the short form, one score line + its gap taller: 22.5 px at
  667 x 375; outside a night the text is exactly what it was).
- **Q2, `sd` per board** — above.
- **Q3, `pointsScale` in `ranges`** — above.

## Files changed

All line counts are after the job (`wc -l`).

| File | Lines | What changed, and why |
| --- | --- | --- |
| `packages/puzzle_game/lib/src/cat_chaos.dart` | 344 (new) | `CatChaos`: the plan, the states, the targeting, the free spot, the shoo, `endRound`. |
| `packages/puzzle_game/lib/src/cat_view.dart` | 99 (new) | `CatRules`' timings, `CatState`, `CatView` (what a frame carries), the `CatVisit` interface the game asks for a shoo. |
| `packages/puzzle_game/lib/src/cat_paint.dart` | 144 (new) | The paw, the face and the shadow, drawn from the frame only. |
| `packages/puzzle_game/lib/src/puzzle_cat.dart` | 51 (new) | The game side of the cat: `_shoo` (A on the cat), `catBats`, `catKnocks` and the glowing tray outline. |
| `packages/puzzle_game/lib/src/phone_hud.dart` | 67 (new) | `phoneHud` moved out of `match_painter.dart`, plus the night's points line. |
| `packages/puzzle_game/lib/src/camera_fit.dart` | 46 (new) | `_fitting` and `_hudUnder` moved out of `camera.dart` to make room. |
| `packages/puzzle_game/lib/src/game.dart` | 320 | The `cat` hook, the glowing tray outline, `trayPos`/`trayAngle` on new pieces, the snapshot's `side`. |
| `packages/puzzle_game/lib/src/match.dart` | 309 | Owns the `CatChaos`, steps it after the sides' ticks and only while the round is, ends it in `_decide`, passes it in the frame and in `settings`. |
| `packages/puzzle_game/lib/src/snapshot.dart` | 323 | `PuzzleSnapshot.side` (`sd`), `MatchSnapshot.cat`, `points` by side, both in `lerpTo`. |
| `packages/puzzle_game/lib/src/settings.dart` | 136 | `Chaos`, `chaos` in JSON and `withValue`, `pointsScale` in `ranges`. |
| `packages/puzzle_game/lib/src/puzzle_values.dart` | 99 | Three cat event kinds, `placedAtS`, `trayPos`, `trayAngle`. |
| `packages/puzzle_game/lib/src/puzzle_tick.dart` | 113 | A on the cat shoos before picking up. |
| `packages/puzzle_game/lib/src/puzzle_drop.dart` | 191 | A knocked piece's glow goes when it is picked up; `placedAtS` on a snap. |
| `packages/puzzle_game/lib/src/puzzle_events.dart` | 79 | The meow, the bump and the shoo's haptic, sound and record. |
| `packages/puzzle_game/lib/src/puzzle_painter.dart` | 355 | Takes the cat and passes it to `paintCat`. |
| `packages/puzzle_game/lib/src/match_painter.dart` | 355 | Off the 400 wall: `phoneHud` moved out; the cat goes to the board it is on, the mirror and the phones. |
| `packages/puzzle_game/lib/src/mirror_painter.dart` | 221 | Draws the cat when it visits the other side. |
| `packages/puzzle_game/lib/src/view.dart` | 319 | The two new parts, and the cat from the frame to the one-board painter. |
| `packages/puzzle_game/lib/src/camera.dart` | 356 | Two functions moved out to `camera_fit.dart`. |
| `packages/puzzle_game/lib/puzzle_game.dart` | 29 | Exports `cat_view.dart`. |
| `packages/puzzle_game/test/cat_test.dart` | 258 (new) | 17 tests: every G3 rule and every shoo. |
| `packages/puzzle_game/test/cat_snapshot_test.dart` | 195 (new) | 7 tests: `cat`, `sd`, the budget, the ranges, the phone's points line. |
| `packages/puzzle_game/test/cat_paint_test.dart` | 89 (new) | 2 tests: the cat is drawn, and goes without the walk with the effects off. |
| `packages/puzzle_game/test/support/cat_run.dart` | 105 (new) | `catRace`/`catSolo` and `Watch`, which steps a match and notes the cat's visits. |
| `packages/party_host/lib/src/puzzle_settings_provider.dart` | 39 (new) | The provider and its notifier, moved, with the host's default A little. |
| `packages/party_host/lib/src/providers.dart` | 371 | The move out (and its `dart:convert` import), plus the export. |
| `packages/party_host/lib/src/ui/puzzle_settings_screen.dart` | 211 | The Chaos card: three buttons, the chosen one ticked, one line. |
| `packages/party_host/lib/src/text/host_text.dart` | 359 | The card's texts. |
| `packages/party_host/test/puzzle_settings_screen_test.dart` | 67 | One test more: the three buttons, saved, A little by default. |
| `docs/protocol.md` | — | Board `sd` and the top-level `cat`. |

No lib file is over 400 lines (the longest is `camera.dart` 356) and no function over 60: `tools/review.sh` notes
nine functions over its 40-line aim, the longest `_trayLayout` at 54 lines, and none of the nine is longer than it
was before this job (the cat's own functions are all well under 40).

## Computed values the tests assert

- Warning **2000 ms** at its first frame; the bat **3.2 s** after the warning starts (2.0 + 1.2); a visit
  **4.8 s**.
- A 40 s round: the plan's window is 40 − 20 − 10 − 4.8 = **5.2 s**; A little's start is 20 + r·0.4 s, Party's are
  20.0 s and 22.6 s, and the second cat arrives at **24.8 s** and is gone by 29.6 s — inside the last 10 s by
  0.4 s.
- The shoo reach is `pickupReach (3.38) × pickupRange (1) × 2` = **6.76 field units**; a dot placed on the cat is
  always within it.
- +1 to the shooer's side at scale 1 and **+2** at scale 2, with a pop-up of that amount at the cat's place.
- The four-player, five-pop-ups-a-side, night frame with the cat is **705 bytes** (limit 2048).
- The phone's points line: **22.5 px** taller at 667 x 375 (0.06 × 375, the score's line and its gap).
- Pieces the tests place for the 3 s rule: one 6 s and one 1 s before the warning; the 6 s one is taken.

## Test counts, before and after

| Suite | Before | After |
| --- | --- | --- |
| puzzle | 323 | 349 (+26: 17 `cat_test`, 7 `cat_snapshot_test`, 2 `cat_paint_test`) |
| host | 276 | 277 (+1: the Chaos card) |
| phone | 439 | 439 (unchanged) |
| tv | 53 passed, 1 skipped | 53 passed, 1 skipped (unchanged) |

Existing tests are unchanged: nothing in `cat_test.dart`'s or the snapshot's expectations was edited, and every
old test passes as it was — the cat is additive (library default Chaos off, `cat` and `sd` left out, points only
in a night, HUD text outside a night exactly as before).

Tests first: with the cat unwired for one run (`_cat.update` commented out of `PuzzleMatch.update`) 17 of the 24
cat and snapshot tests failed (the other 7 — `sd`, the ranges, the budget with a hand-built cat — do not need the
step); with it back, all 26 pass. The paint tests were written against a painter that had no `cat` at all and the
settings test against a screen with no card.

## Checks run

```
tools/check.sh format analyze puzzle host phone tv
PASS format (4s) · PASS analyze (11s) · PASS puzzle (349 tests, 56s) · PASS host (277 tests, 28s)
PASS phone (439 tests, 34s) · PASS tv (11s) · All checks passed (148s)
```

`tools/review.sh`: **0 fail, 53 note** (numeric literals in the painters, files over the 300-line aim, functions
over 40 lines). The one FAIL it found on the way — a `Color(0x…)` literal for the cat's plum — is gone: the colour
comes from the look now (Question 1).

## Mirror pictures unchanged

`mirror_place_test.dart` and `mirror_png_test.dart` pass unchanged, byte for byte: the mirror takes the cat only
when `s.cat` says the cat is on the other side, and the frames those tests build carry none (Chaos off by
default).

## Self-check — docs/review-rules.md part A, items 1–5

1. **Every host setup.** A TV/PC host and a phone on "Show on this device" draw the cat on the board it visits
   (`cat_paint_test` draws a one-board `MatchView`); "Play on this phone" and a phone that shows one side draw it
   on that side's world, and the other side's mirror draws it when it is over there (`match_painter` passes it to
   `_phones` and `_mirror` by the frame's side); a joined phone draws it from the `cat` key alone
   (`cat_snapshot_test` round-trip). A phone or host one build older reads version 2 as it did: the `cat` and
   `sd` keys are extra, so it draws the round without the cat and still plays (no update text, because the
   version did not change — `snapshot_v2_test`'s version-1 reader is unaffected).
2. **When kept state starts and ends.** The cat starts at its planned time — never before 20 s of the round and
   never with less than 10 s + a visit left — only while the phase is playing, and ends by running off after
   4.8 s, by being shooed (leave, then away for the round), when the round is decided (`_decide` → `endRound`)
   or when Chaos goes off. A pause, the host away and a player away all stop the steps (the host publishes no
   frame), so the cat's clock freezes and nothing catches up — tested by "the cat's clock stands still while the
   round does".
3. **How a new state combines with the others.** *The cat and a held big piece:* the cat only ever targets tray,
   loose or locked pieces, never a held one (`_targetOf`), and a shoo never picks anything up, so a player
   carrying a big piece keeps it (`_tapAll` returns before `_pickUp`; "A on the cat shoos rather than picking a
   piece up"). *The cat and the time-up:* `_decide` stops both games and sends the cat away in the same frame, so
   the last frame and the results carry no `cat`; a round that ends while the cat is out leaves no visit planned.
   *The cat and the pause / Get ready / a dropped link:* no steps, no movement (above). *The cat and two sleep
   states at once* (paused and a player away): both just stop the steps, and the cat has no state of its own to
   get out of step.
4. **Stay in the job's folder.** Only files from `allow:` were written: `docs/briefs/m14/a2-cat-report.md`,
   `docs/protocol.md`, `packages/puzzle_game/lib/**`, `packages/puzzle_game/test/**`, and in `party_host`
   `lib/src/providers.dart`, `lib/src/puzzle_settings_provider.dart`, `lib/src/ui/puzzle_settings_screen.dart`,
   `lib/src/text/host_text.dart` and `test/puzzle_settings_screen_test.dart`. Nothing under `assets/`,
   `packages/toy_look`, the rule book, `packages/game_kit`, `packages/test_game` or the night's screens was
   touched.
5. **Stop rather than overstep.** Stopped at the gate. Two things could not be done inside `allow:` and are
   Questions rather than guesses: the mockup's plum colour (it needs `toy_look`; the cat takes the look's `wall`)
   and the `meow` sound (it needs `assets/`; the event plays the name, and nothing sounds yet).

## Questions

1. **The cat's colour is the look's `wall`, not the mockup's plum.** `review.sh` fails a `Color(0x…)` literal in
   lib outside `toy_look`, and `toy_look` is outside this job's allow list, so `_catColour(look)` returns
   `look.colors.wall` (0xFF7F8FD1 Sunny, 0xFF8C9BD8 Night — both near the mockup's 0xFF9A8BB0). Should a later job
   give `toy_look` a `cat` colour at the mockup's plum, in both palettes, so the cat is exactly frame 3's?
2. **"Never the same side twice in a row" can leave the cat out of a Party round.** The target is the side ahead,
   and that side is then excluded, so once the first visit knocks a piece loose and its side stays ahead, the
   second visit has no side to go to (`_leader()` returns null and the plan is used up). The tests assert the
   knock and "at most twice", and a draw's two visits still happen. Is "no second visit when the leader was the
   last visitor" the intended reading, or should the cat fall back to the other side in that case?
3. **`meow` has no audio file.** The brief says "the `meow` sound by name" and the event plays `'meow'`, but
   `assets/audio` has no such sound and `assets/` is not in `allow:`. Nothing sounds at the warning until the
   audio job that adds it (the comment in `puzzle_events.dart` says so). Does c1 or an audio job own it?
4. **Short rounds.** The rules leave 10 s between the 20 s grace and the 10 s tail, and a visit is 4.8 s, so two
   Party visits only fit back to back; `_plan` therefore places each visit early in its share of the window so
   they never overlap. A 120 s round spreads them as expected. Fine, or should a short round get one visit?
5. **The 3 s "settled" rule is checked when the cat picks its piece** (at the warning), because the shadow must
   be on the exact piece during the whole warning: a piece placed *after* the warning can still be knocked.
   Confirm that is what G3 means.
6. **`sd` is also the match-level seed's key**, one object up (`{"sd": seed}` beside `{"b": [{"sd": side}]}`).
   The brief names the board's key `sd`, so it is; a cheaper read for a newcomer would be a different name
   (`bsd`) before this ships — say if you want it.
7. **A night's points line can change the HUD's form.** `hudPlace` picks the clock area's form from the text it
   is given, so a long points line can switch a night round from one line to two (or to the short form) when the
   score first grows — the area moves under the same phone's thumb-free corner. Should a night round be sized for
   its possible points from the start?

## Suggestions

- A follow-up for `toy_look`: a `cat` colour (Question 1) and, with the audio, the meow's asset — both are small
  and independent of the cat's rules.
- The phone's points line would read faster with a small star glyph before the number, matching the pop-up's
  icon, now that the line exists (`phoneHud` owns the font already).
- `CatChaos` could expose its planned visit times behind `assert`, so a playtest build can draw them; the tests
  already work around their absence with a first run that finds the time (`cat_test.dart`'s 3 s test).
- When c1 builds the night, its start card could say who the cat is after ("The cat goes for the side that's
  ahead") — the text would live in `host_text.dart`'s neighbourhood, but the card is another job's screen.

## Commit message

M14 a2: the cat, its shoo and the Chaos setting

- `CatChaos` in `puzzle_game`, stepped by the match after the sides' ticks from its seed: warning 2 s
  (meow, paw, shadow on the exact piece) → walk → bat → leave, frozen whenever the round is.
- G3's limits: the side ahead (either on a draw, never twice in a row), none in the first 20 s or last
  10 s, once a round on A little, twice on Party with one knock of a settled placed piece of the side
  ahead (back to the tray, outline glowing, points kept); one board never loses one; no night rule.
- A on the cat shoos it: +1 × `pointsScale` with a pop-up, `catsShooed` in `MatchResult.round`, and it
  stays away for the round.
- Snapshot still version 2: a top-level `cat` while it is out and `sd` per board, so `points` reads the
  side; docs/protocol.md updated; 705 bytes worst case with four players, five pop-ups and the cat.
- Drawing: paw, shadow, walk, a glowing tray outline; effects off still shows the cat and draws no walk.
- `PuzzleSettings.chaos` (library default off), `pointsScale` in `ranges`; the host saves A little and
  shows three buttons; the provider moved to its own file. A phone host's HUD reserves and draws points.

## Status row

M14 a2 done: the cat (`CatChaos`, every G3 rule, the shoo and its +1), Chaos off/little/party with the host's A
little default, `cat` and `sd` in snapshot version 2, the cat drawn from the frame, a phone HUD points line, and
`pointsScale` in `ranges`; open: a `meow` audio asset and a `toy_look` cat colour (questions 1 and 3), and the
leader/never-twice reading (question 2).

## Delete

- none
