# M13 11: the Arena's buttons and its goal flag (owner's iPhone test of m13.1)

Job: `docs/briefs/m13/s11-device-arena.md`. Stop after it (done, nothing more).

## What changed

### `packages/test_game/lib/src/arena_session.dart`
- `const arenaDashLabel = 'Dash'` — the dash's one name, for the phone's A button and the TV's HUD.
- `arenaLayout` now labels A `'Dash'` and Start `'Pause'` (as Shape Race's layout does) and hides the buttons the
  rules read nowhere: `_unusedButtons` = B, X, Y, LB, RB, Select. The set is a named constant above the layout rather
  than a multi-line map entry, because `tools/review.sh` reads a `hidden: {` at indent 2 as a member's opening brace and
  fails the file (the same false positive project-notes.md line 49 records for `labels: {`).

### `packages/test_game/lib/src/arena_painter.dart` (282 lines)
- The corner flag's constants (`flagCheckerShare`, `flagPoleShare`, `flagMarginShare`, 3 × 2 checks) are replaced by the
  middle flag's, all shares of the goal pad's shorter side: `flagHeightShare` 0.6, `flagPoleWidthShare` 0.05,
  `flagKnobShare` 0.075 (radius; `flagFootWidthShare` is `2 ×` it, so knob and foot share the flag's left edge),
  `flagFootHeightShare` 0.06, `flagClothShare` 0.5 (the cloth is half the flag's height), `flagClothTopShare`
  (`2 × flagKnobShare`, i.e. the cloth hangs from the knob's bottom), and 4 × 3 checks.
- `_flag` lays the flag out from the pad's middle in px and draws the pole's shaft, foot and knob (`_pole`) and the
  cloth (`_cloth`). Nothing else about the goal changed: the glow, the pad, its shape and colour are as they were, and
  the flag stays flat (design 6).

### `packages/test_game/lib/src/arena_hud_widgets.dart`
- `_dashReady` is `'$arenaDashLabel ready (A)'`, so the HUD's words and the phone's label can never drift apart. The
  string the HUD shows is unchanged (the HUD test that finds `'Dash ready (A)'` passes untouched).

### `packages/test_game/test/arena_session_test.dart`
- New group "the phones' buttons", two tests: the layout's labels, and "every hidden button is one the rules never
  read" — `buttonsTheRulesRead()` holds each `ControllerButton` on its own and keeps the ones that change
  `GameInput.fromGamepad`'s move, dash or aim, then requires `arenaLayout.hidden` to be exactly every button except
  those and Start. A rule that starts reading Y (say) fails the test instead of silently hiding a used button.

### `packages/test_game/test/arena_paint_test.dart` (374 lines)
- `fieldBytes`/`drawField` take a `box` (default `screen`, the 960 × 540 TV), so a test can draw a phone's box.
- `padOf(box)` gives the goal pad in px; `flagExtent(...)` scans the pad's pixels, inside its ink edge, for everything
  that is not the pad's `good`, and returns the flag's bounding box.
- New: "the goal pad's middle holds the flag's ink, not its green", "the flag is about 60 % of the pad tall and centred
  on it" (both palettes × a 667 × 375 phone and the 960 × 540 TV).
- Rewritten: "the goal's middle is good" became "the goal pad is good inside its edge, below the flag" (the pad's middle
  now holds the flag, by design).

## Tests first

Written and run against the old code before the change; each failed for its own reason:

| test | failure on the old code |
| --- | --- |
| the Arena labels A Dash and Start Pause | compile error: `arenaDashLabel` undefined, and the labels were `{start: 'Pause'}` |
| the Arena hides every button its rules never read | `arenaLayout.hidden` was empty, expected `{b, x, y, lb, rb, select}` |
| the goal pad's middle holds the flag's ink | pixel (610, 187) on the phone was 45 from both ink and paper (the old corner flag left the middle green) |
| the flag is about 60 % of the pad tall and centred on it | height 0.259 of the pad's shorter side (the old 3 × 2 corner flag), expected 0.55–0.65 |

## Test counts

From `tools/check.sh format analyze arena host phone tv`, before the job and after:

| target | before | after |
| --- | --- | --- |
| arena | 62 | 66 (+2 layout, +2 flag; 1 test rewritten) |
| host | 240 | 240 |
| phone | 433 | 433 |
| tv | PASS | PASS (the summary prints no count for this one) |

## The buttons hidden

`b`, `x`, `y`, `lb`, `rb`, `select`. Kept: `a` ("Dash") and `start` ("Pause").

`arena.dart` reads only A (`GameInput.fromGamepad`: `dash: g.pressed(GamepadButton.a)`) and the sticks/D-pad for the
move and the right stick for the aim; Start is the host's pause (M11), not a rule, so it stays visible and labelled.
The test above derives the read set from the gamepad mapping itself, so it fails the day a rule reads a hidden button.

## The flag's shares and the numbers they give

All shares are of the goal pad's **shorter side**, `p` (the pad is `ArenaGame.goalArea`'s 0.11 × 0.24 of the field):

| share | value | gives |
| --- | --- | --- |
| `flagHeightShare` | 0.6 | the whole flag, foot's bottom to knob's top: 0.6 p |
| `flagPoleWidthShare` | 0.05 | the pole's shaft |
| `flagKnobShare` | 0.075 | the knob's radius (0.15 p across); `flagFootWidthShare = 2 ×` it = 0.15 |
| `flagFootHeightShare` | 0.06 | the foot, a pill 0.15 p × 0.06 p |
| `flagClothShare` | 0.5 | the cloth's height against the flag's: 0.3 p, so a check is 0.1 p |
| `flagClothTopShare` | 0.15 | the cloth's top below the flag's top (the knob's bottom) |
| `flagChecksWide` / `flagChecksHigh` | 4 / 3 | the cloth is 0.4 p × 0.3 p |

The flag's drawn box is `2 × flagKnobShare + flagPoleWidthShare/2 + …` — in numbers: `0.075 + 0.025 + 0.4 = 0.5 p`
wide and `0.6 p` tall, and it is placed with that box centred on the pad's middle. The pad's middle thus falls in the
middle of a check (1.5 checks from the cloth's left and 1.5 from its bottom), not on a check's edge.

Computed for the two test boxes (and what the tests measured):

| box | pad (px) | p (px) | flag drawn | measured box | measured height / p | offset from the pad's middle |
| --- | --- | --- | --- | --- | --- | --- |
| 960 × 540 TV | 105.6 × 129.6 | 105.6 | 52.8 × 63.4 | x 852…905, y 238…302 (53 × 64) | 64 / 105.6 = **0.606** | +0.10 px across, 0.0 px down |
| 667 × 375 phone | 73.37 × 90 | 73.37 | 36.7 × 44.0 | x 591…629, y 165…210 (38 × 45) | 45 / 73.37 = **0.613** | −0.31 px across, 0.0 px down |

The pad's middle pixel is the cloth's paper check in both boxes and both palettes (`0xFFFFE3`, gap 0 to `paper`, 208 to
`good`); the allowed slack is 5 % of p (5.3 px on the TV, 3.7 px on the phone).

## Tests I changed, and why

- `arena_paint_test.dart`: "the goal's middle is good" → "the goal pad is good inside its edge, below the flag". The
  brief moves the flag onto the pad's middle, so the old sample point is by design no longer the pad's green; the new
  test samples the pad 40 % of p below its middle (10 px under the foot, 21 px above the pad's edge) and keeps the same
  `good`-within-2 assertion and both palettes.
- `arena_paint_test.dart`: `fieldBytes`/`drawField` gained `box` (default unchanged), so the flag can be checked at a
  phone size as well as the TV's. Every existing caller is unchanged.

No other test was touched. All the existing tests pass unchanged, including the HUD's `'Dash ready (A)'`, the mat,
wall, bumper and glow pixel tests, and the view's phone-bar tests.

## Self-check, review rules part A

1. **Every host setup.** The layout and the flag are host-independent: the session sends `arenaLayout` to every phone
   from either host type (it is the same message a TV host and a phone host send), and the flag is drawn from the
   snapshot and the box only, which joined phones do through the same `ArenaBoard` — checked at a phone's and a TV's box
   by "the flag is about 60 % of the pad tall and centred on it". A phone one build older is unaffected: no message or
   field was added (labels and hidden have been in `GameLayoutMessage` since M10, `Capability.layout`).
2. **When kept state starts and ends.** Nothing is kept, timed or remembered by this change: the flag is computed per
   frame from the pad's rect (`_flag`/`_pole`/`_cloth` take no state) and `arenaLayout` is one `final` value created
   once. The session's existing `_withLayout` still re-sends it after a pause (`resumed`), unchanged; "the session ends
   as quit, and a won round does not end it" still passes.
3. **How a new state combines with the others.** No new state: nothing pauses, hides, waits or blocks input. Only the
   P5 labels/hidden set and the drawing changed, so the pause menu, away, "Get ready" and results combine exactly as
   before; the phone's pad already dims a hidden button and ignores its touches (`face_buttons.dart`), the same way it
   does for Shape Race's B, LB, RB and Select.
4. **Stay in the job's folder.** Five files under `packages/test_game` and this report; `git status` shows nothing else
   of mine (the three `tv_test_app/windows/flutter/generated_*` files were rewritten by Flutter's own tooling during the
   checks, not by me).
5. **Stop rather than overstep.** Nothing was needed outside `allow:` and no rule was bent; the two review-script
   findings (a 41-line `_flag`, the `hidden: {` false positive) were fixed inside this job, not waived.

## Questions and suggestions

1. The brief said to share the HUD's dash string "if that string has a home". It had none, so `arenaDashLabel` is a
   named constant in `arena_session.dart` — and the HUD now builds `'$arenaDashLabel ready (A)'` from it. That adds an
   `import 'arena_session.dart'` to `arena_hud_widgets.dart`; if you'd rather the HUD kept its own literal, it is a
   one-line revert and the layout keeps the constant anyway.
2. The flag is the pad's middle *as a whole*: its pole stands 18 px (TV) left of the pad's middle, the cloth to the
   right, so "the pole stands in the pad's middle" and "the whole flag is centred on the pad's middle" can't both be
   literal. I read the second as the rule (it is the one the test measures).
3. `flagClothTopShare` is `2 × flagKnobShare` both for the look (the cloth hangs from the knob's bottom) and for a
   measurable reason: it puts the pad's middle in the middle of a check. A later change to the knob or the cloth's
   height moves the middle onto a check's edge, and the middle test will say so.
4. Worth an owner's look on the iPhone: the flag is 0.5 × 0.6 of the pad's shorter side — visibly bigger than the old
   corner flag on a TV, and on a landscape phone's ~73 px pad it is 37 × 44 px, which the pixel tests say reads.
5. Generated files: `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and `generated_plugins.cmake` show
   as modified. `flutter test` (through `pub get`) rewrites them; they are not part of this diff's content.

## Commit message

```
Arena: label A Dash on the phone and move the flag to the goal's middle

The layout labelled only Start, so the dash had no word on the pad: A now
reads "Dash" and hides B, X, Y, LB, RB and Select, which the rules never read.
The goal's corner flag was small and read badly, so the flag is now centred on
the pad, 0.6 of its shorter side tall, with an ink pole on a foot, a paper knob
and a 4 × 3 checkered cloth flying right from the top, all sized as documented
shares of the pad. Tests: the labels, the hidden buttons (from the gamepad
mapping), and the flag's height, centring and middle at a phone's and the TV's
size in both palettes.

## Status row

M13 11 (device fixes 2, Arena): A reads "Dash" and the unread buttons are hidden; the goal has a big centred flag (0.5 × 0.6 of the pad). Open: the owner's look at the flag on the iPhone in m13.2.

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted. Claude rendered the Arena on a phone-sized box in both palettes.

- **The flag** is centred, but at 0.6 of the pad's shorter side it still read small inside the pad. It's now 0.8 (`flagHeightShare`), and the test's range is 0.75–0.85. Seen in Sunny and Night: the flag fills the pad.
- **Q1:** the HUD reading `arenaDashLabel`: kept, since one word for the dash is the point.
- **Q2:** the whole flag centred, as the test measures: right.
- **Hidden buttons:** B, X, Y, LB, RB and Select, derived from the gamepad mapping; the test fails if a rule starts reading one. Accepted.
