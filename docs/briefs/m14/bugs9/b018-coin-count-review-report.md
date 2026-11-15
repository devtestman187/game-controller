# Review of b018-coin-count

## Summary

Verdict: **small fixes** — 0 must, 1 should, 3 could. The fix matches the brief
and the code is clean; the wrong figures are in the report, not the code.

Checks I ran: `flutter test test/coin_badge_legibility_test.dart` 5 of 5 pass;
`flutter test` in `packages/test_game` 230 pass (the report's count, confirmed);
`dart format --output=none --set-exit-if-changed` on the three files: 0 changed;
`dart analyze --fatal-infos packages/test_game`: no issues.

The report's base numbers hold against the code: old pill 28.7 x 16.35 px with
the count 0.75 px past its ink on every count, new pill 39.6 x 25.3 px (`7`)
and 76.1 x 28.1 px (`100`), peak boxes 51.4 x 32.9 / 78.2 x 36.5 / 99.0 x 36.5.
Wrong: the clamp *distances*, which are the old pill's peak offsets.

Most important: the report's three "moved" distances; the widget test's width
check that cannot fail; no TV field in the test although the TV's pill grew.

## Findings

- **should** docs/briefs/m14/bugs9/b018-coin-count-report.md:19 the three clamp distances in the "after" column (33.2 px down at the top edge; 34.1 and 18.7 px in at x = 0) are the *old* pill's peak offsets, so "Measured: every number above" is false there — with the new pill the `7` peak top starts at -43.4 px (moved down 43.4) and `100`/`7` move in 49.4/25.7 px → recompute those three figures in the summary and in the table rows on lines 60-61, or drop the movement and keep "top at 0 / left at 0".
- **could** packages/test_game/test/coin_badge_legibility_test.dart:169 the width check cannot fail: the marble is at x = 0.5 and the pill is far narrower than the field, so the paper box is always the pill's full width → draw that marble at x = 0, where the clamp moves the pill, so the width assertion can catch a clipped pill.
- **could** packages/test_game/test/coin_badge_legibility_test.dart:17 the test covers only phone fields, yet the new `inset` (the look's outline width, 4 on the TV against 3 on a phone) changes the TV's pill too and no test pins it (guideline §9 "more than one size", review-rules A1) → run the same font, edge and digits assertions on a TV field with a `tv: true` look and `tvPlayerScale` in the radius.
- **could** packages/test_game/lib/src/arena_coin_badge_painter.dart:153 the doc comment says "the look's own weight and line height" but `_countStyle` hard-codes `FontWeight.w700` and `height: 1` → say what the style is (bold ink at the count's own line height) or take the weight from the look.

## Decisions to confirm

- Two font floors (14 px for one digit, 16 px for two or more, three digits keep 16) — the owner's "too small" is what these answer, and nobody has seen them on the phone yet.
- The pill's inside inset is now the ink width plus the padding on all four sides, so the pill grows on every host including the TV (bigger only) — a look change on the TV that the report calls untouched in feel but not in size.
- The clamp uses the scale of the pop that frame draws, so a pill near an edge slides down or in *while* it pops rather than being clamped for the peak — a visible shift at the field's edge.
- The badge's constants and `CoinBadgeLayout` are public in `src` so the test can read them through a direct `package:test_game/src` import (the same way `party_host`'s tests do) — `lib/test_game.dart` was outside `allow:`, so the export question is Claude's.

## Could not check

- The "5 failed of 5 on the old geometry" claim by a run: no git command that changes the tree is allowed. By arithmetic on the old `_coinCount` (`git show 6b03e0da:...arena_marble_painter.dart`) all five do fail: 11.856 px against 14, 11.856 against 16, the count 0.75 px past the pill's right on every count, and no clamped pill at the top or left edge.
- The owner's look: the cause of "appears cutoff" was not measured on a device.
- `git diff 6b03e0da..1a64d76` and `git status`: refused by this environment, so the changed files were read whole instead.
- Running the arena suite rewrote `docs/design/maps/toy-factory.png` and `docs/design/maps/spinning-tops.png` (`map_render_test` does that by design); `git status`/`git hash-object` were refused, so I could not confirm they are byte-identical to the commit.
- `docs/briefs/m14/bugs9/run-findings.md` does not exist, so there were no entries to check.

## Commit message — a draft

```
B-018 coin count review: fix sound, three report distances wrong

The 14/16 px font floors, the pill's ink inset and the pop-peak clamp match
the brief; 5 new tests pass, the 230-test suite passes, format and analyze
are clean.
The report's clamp distances (33.2 down, 34.1 and 18.7 in) are the old
pill's offsets: the new pill moves 43.4, 49.4 and 25.7 px.
The new test has no TV field and a width check that cannot fail; the count
style's comment names a look weight it hard-codes.
```

## Status row

M14 bugs9 B-018: fixed, tested and reviewed (5 new tests, 230 suite, clean format/analyze); open — the report's three clamp distances to correct, a TV field and a real width check in the new test, and the owner's device look.

## Delete

- none
