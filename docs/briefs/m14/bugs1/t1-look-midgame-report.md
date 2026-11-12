# M14 bug t1: the look changes at once, mid-game too — report

## Summary

- **Cause 1 (the freeze):** `LookPaletteNotifier` kept the palette it had while any round was on — `build()` returned
  the stored palette when `roundHoldsProvider.count > 0`, and `refresh()` did nothing then (design D1: "never
  mid-round"). `RoundPaletteHold` took a hold from each round's screen (`RoundHold`: `PuzzleScreen`, `GameScreen`,
  results and pause) and from a joined phone's view over a game. So a Look change saved the setting and was not drawn
  until the next page after the round.
- **Cause 2 (no repaint):** `PuzzlePainter.shouldRepaint` compared only the snapshot and the clock, and
  `MatchPainter.shouldRepaint` everything but the look: a board whose snapshot and clock stood still (paused, or one
  slow frame) never repainted for a new look. Every other painter in the tree already compared `look`.
- **What a player now sees:** picking Sunny or Night in Settings changes the round under it at once — Shape Race's
  board, tray, pieces, workers, cat and celebration; the Arena's field in every mode, the Bumper Round included; the
  results card over them; the party night's screens; and on a phone host the pad and overlays drawn over the round.
  The round itself is untouched: same match, same pieces, clock, coins and points.
- **Joined phone:** it follows **its own** Look setting, as before (design D8), and now live too; it does not follow
  the host's.
- **Files:** `look_providers.dart` (the hold removed), `round_palette_hold.dart` (emptied; delete it),
  `lobby_music.dart`/`lobby_music_widgets.dart`, `party_host.dart`, `joined_view.dart`, `puzzle_painter.dart`,
  `match_painter.dart`, and the tests `look_midgame_test.dart` (new), `look_palette_test.dart`, `round_palette_test.dart`.
- **Not done:** `docs/design/look-and-sound.md` D1 still says the palette never changes mid-round; it is outside this
  job's `allow:` and needs a one-line update (question 1).
- **Owner, on a device:** start a Shape Race, open Settings from the pause or the phone, pick Night → the game under it
  turns Night at once and plays on. Same in the Arena (both modes) and on a joined phone. Nothing restarts.

## Cause and fix, screen by screen

The palette is a provider that every `ToyLookScope` and painter reads, so removing the hold fixes every screen that
draws from it at once; the two painters were the only places that also needed a repaint. What each named area showed
before → now:

| Area | Before | Now |
| --- | --- | --- |
| Shape Race board, tray, pieces, workers, cat, celebration | old look until the round ended | new look on the next frame |
| The race's split screen (both boards, HUD, mirror) | old look | new look (`MatchPainter` repaints for the look alone) |
| One board / a viewer's board (`PuzzlePainter`) | old look, and no repaint even when paused | new look (`shouldRepaint` includes it) |
| Arena, Race and Bumper Round, coins, results over the field | old look | new look (`ArenaPainter` already compared `look`) |
| Party night's screens (reveal, scoreboard, awards) | old look | new look (their painters already compared `look`) |
| Phone host's overlays over a round (pad, sticks, menus) | old look | new look (their painters already compared `look`) |
| Joined phone's view and mirror | old look | new look, from its own setting |

No round state is touched: the change is only a provider's palette (and, for a joined phone, its own setting). No
restart, no lost pieces, time, coins or points.

**Auto** still reads the clock only at the set moments — at start, when the setting changes, and when a page route is
pushed or popped — so a round does not turn Night by itself at 19:00 while nobody touches anything; but a page opened
over it after 19:00 now shows Night there and then (before, it kept the round's palette).

## Files changed

- `packages/party_host/lib/src/look_providers.dart` — removed `roundHoldsProvider`/`RoundHolds` and the two guards;
  the palette is worked out from the choice in `build()` and by `refresh()` always.
- `packages/party_host/lib/src/ui/round_palette_hold.dart` — emptied (a single newline) so the workspace analyzes;
  delete it (see below).
- `packages/party_host/lib/src/ui/lobby_music.dart` — dropped the now-unused import.
- `packages/party_host/lib/src/ui/lobby_music_widgets.dart` — `RoundHold` now hands its child straight through; its
  doc no longer mentions the palette.
- `packages/party_host/lib/party_host.dart` — removed the export of the deleted widget.
- `controller_app/lib/src/ui/joined_view.dart` — removed the `RoundPaletteHold` wrapper; the view is unchanged.
- `packages/puzzle_game/lib/src/puzzle_painter.dart` — `shouldRepaint` also compares `look`.
- `packages/puzzle_game/lib/src/match_painter.dart` — `shouldRepaint` also compares `look`.
- `packages/party_host/test/look_midgame_test.dart` (new) — the brief's tests: a Shape Race and a Bumper Round round,
  a Look change mid-round, the new palette on the board's painter, the round untouched, and both puzzle painters
  answering true when only the look changed.
- `packages/party_host/test/look_palette_test.dart` — the two tests that asserted the round froze the palette now
  assert the opposite (the owner's report); the clock-is-not-watched test's comment is corrected.
- `controller_app/test/round_palette_test.dart` — a joined phone's own Look setting shows at once mid-game; Auto's
  clock is still read at the next page.

## Computed test values

- Auto at `DateTime(2026, 11, 8, 12)` (hour 12): `7 <= 12 < 19` → Sunny; `LookChoice.night` → Night;
  at 18:59 (hour 18) → Sunny; at 19:01 (hour 19): `19 < 19` is false → Night (`sunnyFromHour = 7`, `sunnyUntilHour = 19`).
- Shape Race: the two-team race draws through `MatchPainter` (a `MatchSnapshot` with `boards.length == 2`), asserted
  with `isA<MatchPainter>()`; the painter's `look.palette` is Night after the change; `identical(play.match, match)` is
  true and `timeLeftMs` is unchanged between the two reads (the pump carries no duration, so no step runs).
- Bumper Round: `board.s.round`, `board.s.mode` and `board.s.players.length` are the same before and after; snapshot
  identity is not asserted because the host makes a new snapshot object on the frame the pump runs.
- `shouldRepaint`: the new painter carries the round's own snapshot, clock, moments, camera, pad, px-per-mm and only
  the other palette's look → true for `MatchPainter`, `PuzzlePainter` and `ArenaPainter`.

## Decisions

- **Remove the round hold rather than special-case a setting change.** The freeze was the cause and the design's
  intent; with the owner's call ("it is a bug") the simplest, safest fix is for the palette to follow the setting
  wherever it is changed, which is also what every other provider in the app does.
- **No "Changes when this round ends." line.** No screen is left stale, so the line the brief allows is not needed and
  `look_and_sound_section.dart` is untouched.
- **The palette's selected-test row on the joined phone stays untouched.** Its look is its own (`lookPrefsProvider`),
  as today.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** A TV/PC host, a phone on "Play on this device" and a phone on "Show on this device" all draw
   the round from the same palette provider, so all change live (tested on the host harness, which is the phone-look
   root: `look_midgame_test.dart`). A joined phone follows its own setting, tested in `round_palette_test.dart`. A
   phone or host one build older sends no look over the wire — the look is local everywhere, so an older peer is
   unaffected (unchanged by this job).
2. **When kept state starts and ends.** Nothing is held any more: the hold's start (a round screen mounted), its ends
   (the screen gone, `held` going false) and the idle case are all gone with `RoundHolds`; the palette is a plain
   derivation of the setting and the clock read at page changes. Tested by the whole `look_palette_test.dart` suite,
   including "Auto … stays Sunny … with no page route" (no timer, no tick).
3. **How a new state combines with the others.** The change adds no state that pauses, hides or blocks input: the pause
   menu, "Get ready", the away card, a dropped link and the results are untouched; Settings over a paused round and
   over a running one both change the look at once (the setting is read, not the round). Tested mid-round in
   `look_midgame_test.dart` and over a round in `look_palette_test.dart`.
4. **Stay in the job's folder.** Only files under this job's `allow:` were written: `packages/party_host`,
   `packages/puzzle_game`, `controller_app/lib`, `controller_app/test` and this report.
5. **Stop rather than overstep.** `docs/design/look-and-sound.md` D1 states the opposite rule and is outside `allow:`;
   it is reported (question 1) rather than edited.

## Questions and suggestions

1. **`docs/design/look-and-sound.md` needs one line changed.** D1 currently reads that the palette "never in the middle
   of a round" changes, and the mock-ups' section 8 note repeats it. The file is not in this job's `allow:`; please
   update D1 to "a Look change shows at once, a round in progress included (owner, Nov 12, 2026)" in a later job, or
   send this job back with the file allowed. `docs/decisions.md` may want the same line.
2. **The design keeps Auto's clock out of the round.** It is read at page changes, so a round left alone across 19:00
   keeps its palette until the next page or setting change. That matches the old rule's spirit and the owner's report
   (about the setting), but if "the look changes at once" should include Auto's hour, it needs a timer — a separate
   decision.
3. **`lobby_music_widgets.dart`'s `RoundHold`** no longer wraps anything: it is now a plain pass-through that only
   starts and stops the round's music. If a later job prefers it, it could keep the music and lose the widget
   (`PuzzleScreen`/`GameScreen` could call `openRound`/`closeRound` from their own life). Not done here to keep the
   diff small.

## Commit message

```
Look: a Sunny or Night change shows at once, mid-round too

The palette was frozen for the length of a round: the look's notifier kept
the stored palette while a round held it, and every round screen took such a
hold, so a Look change waited for the round to end. The hold is gone: the
palette follows the setting wherever it is changed, and a page route still
works it out from the clock for Auto. The puzzle and match painters now
repaint for the look alone, and the round is untouched: same match, pieces,
clock, coins and points. A joined phone keeps its own setting, now live;
tests cover both games mid-round and shouldRepaint.
```

## Status row

`t1 look mid-game: done — a Sunny/Night change shows at once during a Shape Race, every Arena mode and on a joined phone, with the round's state untouched, and the puzzle painters repaint for the look alone; open: docs/design/look-and-sound.md D1 still says the palette never changes mid-round and is outside this job's allow list.`

## Delete

- packages/party_host/lib/src/ui/round_palette_hold.dart
