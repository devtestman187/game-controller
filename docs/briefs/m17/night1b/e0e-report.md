# e0e report: "Game full" for a joiner past the cap

## Summary

A phone that is watching a full game now sees `Game full, watching: <names>` instead of `Not joined: <names>`. With room left it still sees `Not joined: <names>`. The cap (`maxPerSide`), sides and join rules are unchanged.

Files changed:

- `packages/party_host/lib/src/text/host_text.dart`: `HostText.notJoined(names, {bool full = false})` returns `Game full, watching: $names` when `full`, else `Not joined: $names`. The doc comment is one line (the file is 380 lines, at the limit).
- `packages/party_host/lib/src/ui/join_screen_widgets.dart`: `_NotJoined` and `_JoinBody` take `required bool full` and pass it on. The `Key('notJoined')` is kept.
- `packages/party_host/lib/src/ui/join_screen.dart`: `build()` computes `final full = sideForNewPlayer(_teams) == null;` and passes `full: full` to `_JoinBody`. Nothing else changed (368 lines).
- `packages/party_host/test/join_screen_full_test.dart` (NEW): four tests, two looks (TV at 1920x1080, phone at 960x540) times two rosters.

Tests run, all in `tools/mine.sh`:

- Before the change (base code), the two "Game full" tests failed with `Actual: 'Not joined: P5 Phone 5'`. The two "Not joined" tests passed. This is the tests-first proof.
- After the change: `OK 5 tests packages/party_host`; format and analyze clean.

Computed values in the expectations:

- Four players joined (p1 left, p3 right, p4 left, p5 right), a fifth phone p6 watching. Its label is `P5 Phone 5` (the label number is the `phoneInfo` index). Expected `Game full, watching: P5 Phone 5`.
- Two players joined (p1 left, p3 right), p4 watching, label `P3 Phone 3`. Expected `Not joined: P3 Phone 3`.

Existing tests: none changed. No test pins the old "Not joined" text for a full game. `join_screen_test.dart:143` checks the key is absent with one player, and `join_screen_frame_test.dart:155` finds the key only, so both still pass.

Self-check (docs/review-rules.md part A):

1. Host setups: TV host is covered by the TV-look test (`join_screen_full_test.dart`, "(the TV look)"). Phone host is covered by the "(the phone look)" test. Joined phone and watching phone are covered by the same tests. A peer one build older is not covered by this change.
2. Kept state: none added. The line is recomputed from `_teams` on each build.
3. Combinations: not tested. The pause menu, host away, "Get ready", a dropped link, results and leaving are not exercised by these tests.
4. Scope: edits are only inside `allow:`.
5. Stops: none. The TV overflow below is reported, not fixed.
6. Looks: both looks are tested. The TV look is at 1920x1080 and the phone look at 960x540. No fixed pixel height was added.

## Questions and suggestions

1. **TV look overflows at 960x540.** With four players joined, `toy_card.dart:129` (in `packages/toy_look`, outside this job's allow list) overflows by 40 px at the bottom. The TV-look test therefore uses 1920x1080, the TV device size from `join_screen_frame_test.dart`. Someone should check whether the TV look is meant to fit 960x540 at all. I did not change `toy_look`.
2. **`_JoinBody` now has 9 parameters.** It had 8 before this change. Our rule allows 5 and says to use a value object beyond that. I followed the brief and did not refactor it here. A later job could group the roster fields into one value object.
3. `join_screen.dart` is 368 lines, not the 366 in the brief. Still under the 380 limit.
4. `run.log` and `DRIVER-NOTES.md` were already modified or untracked before this job. I did not touch them.

## Commit message — a draft

```
party_host: "Game full" for a joiner past the cap

A phone that is watching a full game saw "Not joined", which tells it to
join a side that has no room. The watching line now reads "Game full,
watching: <names>" when both sides are full, and keeps "Not joined" while
a side has room. The cap, the sides and how players join are unchanged.
New test file join_screen_full_test.dart covers both rosters under the TV
and phone looks.
```

## Status row

e0e: a joiner past the cap sees "Game full, watching: …" (TV and phone looks, tested). Open: the TV look overflows a player card at 960x540 (toy_look, not in this job's scope), and `_JoinBody` has 9 parameters.

## Delete

- none
