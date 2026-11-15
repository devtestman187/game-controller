# B-018 coin count above a marble: legibility report

## Summary

The owner's phone, 390 x 844 and 844 x 390 (a 390 px shortest side either way),
gives a marble a radius of 0.032 x 390 = **12.48 px**.

Before: the count drew at 0.95 x 12.48 = **11.856 px** whatever its length, in a
pill 28.8 x 16.4 px whose 3 px ink edge left 10.4 px of inside for its 12 px
digits: the count's box ran **0.8 px above the pill's inside top and 3.7 px past
its inside right**, so the digits sat under the pill's own ink edge. A marble at
the field's top edge had its pill 14.4 px above the field, its pop peak reaching
**33.2 px above the canvas** — no pill on the screen.

After: **14 px** for a one-digit count and **16 px** for two or more, a
documented minimum that lifts the pill's coin and padding with it (pill 39.6 x
25.3 px for `7`, 76.0 x 28.1 px for `100`). Its inside keeps clear of its ink
edge, and its centre is clamped by its **pop-peak** half size: a marble at the
top edge now wears a whole pill with its peak top at y = 0 (moved down 33.2 px),
and one at x = 0 has its peak left edge at x = 0 (moved in 34.1 px for `100`,
18.7 px for `7`). The TV's look is untouched (its radius is 1.5x, so its count
already draws at 17.78 px); its pill only grows.

Measured: every number above. Guessed: **the cause of "appears cutoff"** —
nothing was measured on a device; both candidates (a pill off the field, digits
under the pill's ink) were real and both are fixed.

Tests: the new file failed 5 of 5 on the old geometry and passes 5 of 5 now; the
`test_game` suite passes, **230 tests** (5 new; its count before is not
measured). Format and analyze are clean.

Not done: no device look, no golden, no tablet or TV field in the new test.

## What changed

- `packages/test_game/lib/src/arena_coin_badge_painter.dart` (new, 170 lines):
  the badge moved out of the marble painter — its shares, the two minimum font
  sizes, `CoinBadgeLayout` (the pill, its pop scale, the coin, the count and its
  box) and `ArenaCoinBadgePainter.layout`/`paint`. The layout is the one place
  the badge's geometry is worked out, so the test reads the same numbers the
  paint draws.
- `packages/test_game/lib/src/arena_marble_painter.dart` (237 -> 183 lines): its
  badge constants and `_coinCount` are gone; it asks the badge painter for one
  paint per Bumper Round marble, pop from `moments.coinPopOf` as before.
- `packages/test_game/test/coin_badge_legibility_test.dart` (new): five tests,
  the real painter, phone-sized portrait and landscape fields.

## The numbers, before and after

All on the owner's field (radius 12.48 px), Sunny look, the arena's style
(`outlineWidth` 3 px).

| | before | after |
| --- | --- | --- |
| font, one digit | 11.856 px | 14 px |
| font, two or three digits | 11.856 px | 16 px |
| pill for `7` | 28.8 x 16.4 | 39.6 x 25.3 |
| pill for `100` | 52.4 x 16.4 | 76.0 x 28.1 |
| count inside the pill | 0.8 px over the top, 3.7 px over the right | inside, 3 px + padding clear on every side |
| pill at the top edge, pop peak | top at -33.2 px (off the canvas) | top at 0, moved down 33.2 px |
| pill at x = 0, pop peak, `100` | left at -34.1 px | left at 0, moved in 34.1 px |

The `100` pill's widths after include the count's own width (48 px at 16 px);
the peak boxes for `7`/`42`/`100` at the top edge are 51.4 x 32.9, 78.2 x 36.5
and 99.0 x 36.5 px. Caveat on the widths: a widget test draws in the test font,
whose digits are a full em wide (14 px for one digit at 14 px, 48 px for `100`
at 16 px), so a real device's pills are narrower by the difference while the
font sizes — the fix — are the same.

## Tests and checks (run in this job)

- `flutter test test/coin_badge_legibility_test.dart` while the badge file held
  the old geometry unchanged: **5 failed of 5** (`+0 -5`) — the font 11.856, the
  digits over the pill's inside, the pill off the field at all eight edges and
  corners, and no paper of the pill on the canvas for a marble at the top edge.
- The same file after the fix: **5 passed** (`+5`).
- `flutter test` in `packages/test_game` (the `arena` check): **230 passed**.
- `dart format --output=none --set-exit-if-changed controller_app tv_test_app
  packages assets`: 798 files, 0 changed.
- `dart analyze --fatal-infos` over the workspace: no issues.
- `tools/check.sh format analyze arena` itself was refused by this environment
  (it needs an approval I don't have), so I ran the three commands from its own
  table, one at a time, above. None of them may be quoted as a passing
  `tools/check.sh` run.

## Decisions

- Minimum font is two consts, 14 px for one digit and 16 px for two or more,
  because the brief asks for both and a wider count must not shrink below its
  one-digit size.
- The coin and the padding grow by the same factor the font was lifted by
  (`grow`), because the brief says they scale along with it and the badge keeps
  its shape; the gap above the head stays the marble's share, so the pill does
  not drift away from the head.
- The pill's inside is inset by the ink width plus the padding, not the padding
  alone: the old box put the digits 3.7 px under the pill's own edge, the one
  arithmetic cause of "cutoff" inside the pill that I could measure.
- The clamp uses the pill's pop-peak half size, not its resting one, so the pop
  never takes the pill off the field; a pill wider than the field is centred.
- The badge lives in its own file and exposes its layout to the package's tests
  (tests import `lib/src`, as `party_host`'s do): `lib/test_game.dart` is outside
  `allow:`, so a direct `src` import was the only way to test the real numbers.
- The count's ink stroke stays the look's own `outlineWidth`, not the count's
  scale, so the badge keeps the scene's line weight.

## Self-check (review-rules part A)

1. Every host setup: the badge is drawn from the snapshot's radius and the look;
   a phone host, a joined phone and "Play on this phone" use the same code with
   scale 1 (tested at both phone orientations, `coin_badge_legibility_test`);
   the TV's look only makes the radius 1.5x, so the minimum never lifts and the
   pill grows by the ink inset — the arena suite still passes, no new TV test.
2. Kept state: none. The layout is worked out per paint from the snapshot and
   the round's clock (pop), nothing is remembered (`CoinBadgeLayout` dies with
   the paint).
3. New state combining: none; no pause, hide, wait or input state is involved.
4. Stay in the job's folder: the three changed paths, all inside `allow:`.
5. Stop rather than overstep: nothing outside `allow:` was needed; the brief and
   the code agreed, so nothing to report.

## Questions and suggestions

1. The 14/16 px floors follow the brief; nobody has looked at them on a phone.
   If the owner still finds it small, the consts are the two knobs.
2. A count of three digits keeps the two-digit floor (16 px), not a third one;
   the brief asked for one- and two-digit sizes only.
3. Suggestion for a later job: a golden or an owner photo of a marble at a
   corner, since the clamped pill sits over the head and only a look can say
   whether that reads well.

## Hand-over

Claude: the diff is three files (one new painter, one new test, the marble
painter trimmed). The risky part is the pill's inside inset, which changes the
pill's size on every host including the TV (bigger only); the second is the
pop-peak clamp, whose numbers are tabled above. Please check the two minimum
font constants against what the owner wants before the next build.

## Commit message — a draft

```
B-018: the Bumper coin count reads at 14 px and stays on the field

The count above a marble drew at 0.95 of the marble's radius, 11.9 px on a
phone, its digits under the pill's ink edge; at the field's top edge the
whole pill was drawn 33 px off the canvas. The owner: "too small, number
appears cutoff".

The badge now has a 14 px minimum font, 16 px for two or more digits, with
its coin and padding growing with it; its inside keeps clear of its ink
edge, and its centre is clamped by its pop-peak size. It moved to its own
painter file (170 lines) and a new test covers both phone orientations.
```

## Status row

M14 bugs9 B-018: fixed and tested (count 14/16 px, pill clamped inside the field, digits clear of the ink edge); open: the owner's look on a device.

## Delete

- none
