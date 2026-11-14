# b011b-continue: a series after a hand-picked puzzle

## Summary

Built B-011 outside a night. Picking one puzzle on the picker now starts a
**series**: a value (`PuzzleSeries`, `ui/puzzle_continue.dart`) holding the
level, the ids played and whether Shuffle is on. `PuzzleScreen.series` carries it
into the next round; it is not saved, and Back to the picker ends it.

The results card after a series round offers, in a `Wrap`: **Next puzzle** (first,
focused), a **Shuffle** toggle, **Play again**, **Change teams** and **Back**. Next
plays the level's next unplayed puzzle in the library's list order, wrapping past
the end, or a random unplayed one with Shuffle on; same teams. Once every puzzle of
the level has played, "You have played every `<level>` puzzle" and **Continue to
`<level>`** take Next's place; on the last level (Medium; Hard ships none) Play
again is first. A night's round and an `any <level> puzzle` round keep one Next.

Numbers: **11 new tests** (`puzzle_continue_test.dart`, 5 pure + 6 widget); the
package runs **438 tests**, all green; `puzzle_screen.dart` is **380 lines**; the
phone card's pad walk is right, right, down, left (two rows) at 852×393.

Not done: nothing from the design. `PuzzleBag` is not reused: its order is saved
and shared by `any` rounds, while a series is in memory and follows list order.

Questions: none blocking. The level-done prompt is drawn inside the results card
(the brief allowed a card or a dialog), so Back still leaves in one press.

On a device: on a phone host pick one Easy puzzle, walk Next puzzle to the end of
Easy, flip Shuffle, Continue to Medium, finish it — the last level should offer
the prompt, Play again, Change teams and Back, and nothing that leads on.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** The card is host-side and the same on a TV/PC host and a
   phone host ("Play on this phone" or "Show on this device"); a phone on a
   phone-sized host is the one that differs in height, tested by `the series'
   results card draws on a phone-sized host without overflow`. A joined phone
   draws the play view only and gets no results card (not affected: no protocol
   change, nothing sent). An older build plays exactly as before (no message,
   no saved state) — needs device check only for look, not behaviour.
2. **When kept state starts and ends.** Starts in `initState` when the choice
   names a puzzle and no night is running; every round adds its id; it ends with
   the screen (Next/Play again build a new screen that carries it; Back and
   Change teams leave it behind); a level change resets the played set with the
   same Shuffle; a night's round has none. Tested by `a night's chosen round
   still has its one Next`, `the Shuffle switch stays on for the series` and
   `the next level starts a fresh series with the same Shuffle`. App hidden:
   nothing runs or times out (a value, no timer) — not tested.
3. **How a new state combines.** Pairs that can meet: card + phone-sized host
   (tested, above), card + a night (tested, `a night's chosen round still has its
   one Next`), card + Change teams / Back (tested by the walks in
   `puzzle_results_test` and `host_focus_ring_test`), Shuffle on + the level's
   last puzzle (tested by `Shuffle plays every puzzle of the level once, then the
   prompt offers the next level`). Card + pause menu cannot meet: the card is up
   only after the round ended and takes the focus; the pause menu is a round-time
   screen and this diff does not touch it (not tested here; unchanged).
4. **Stay in the job's folder.** Every file I wrote is in `allow:` (list below).
   Nothing outside it.
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`, and no
   rule blocked the design, so no stop.

## Decisions

- The series is a value in the screen's state, not a provider: it must die with
  the series, and a provider would outlive Back to the picker and leak into the
  next hand-picked round.
- Next follows `PuzzleLibrary.ofLevel` order, wrapping, not the bag: the brief
  asks for the library's list order, and the bag's order is saved and shared.
- The replay button keeps today's words and keys (`Rematch` in a race, `Play
  again` on one board, via `_replayWords()`), so the three pinned tests keep
  every other assertion; only the first button and its focus moved.
- Shuffle is a `HostButton` with `toggle_on`/`toggle_off` and the focus fill
  when on, not a Material `Switch`: the card is walked by the pad, and a bare
  switch is neither a host button nor a focus stop.
- Shuffle is hidden once the level is done: nothing is left to pick from, and
  the owner's "it will end once all puzzles have been played" reads that way.
- Play again repeats the puzzle just played and does not mark it played again
  (today's behaviour, unchanged).
- Continue keeps the Shuffle setting into the next level but starts a fresh
  played set, and its button takes the focus.
- On the last level the prompt is drawn above Play again, which takes the focus,
  so the pad's OK works at once.
- The card scrolls (`SingleChildScrollView`) when the prompt makes it taller
  than a phone host, rather than dropping a button.
- `PuzzleBag` is not reused (see Summary): the two orders differ by design.

## Files

- `packages/party_host/lib/src/ui/puzzle_continue.dart` (new, 184 lines):
  `PuzzleSeries` and the series' card buttons (`_SeriesButtons`, `_ShuffleSwitch`).
- `packages/party_host/lib/src/ui/puzzle_screen.dart` (383 → 380): the `part`,
  the `series` field and `_series` state, `_showPuzzle` records the round,
  `_shuffle`, and the card inside a `SingleChildScrollView`.
- `packages/party_host/lib/src/ui/puzzle_pick.dart` (228): `_startedSeries`,
  `_menu`, `_seriesMenu` with its button helpers, `_nextInSeries`, `_continueTo`,
  `_levelIds`, `_nextLevel`, `_replay`, and the moved `_next`.
- `packages/party_host/lib/src/ui/puzzle_results_widgets.dart` (224): `_Results`
  takes a `_ResultMenu`, and `_buttons()` picks the night/any/series buttons.
- `packages/party_host/lib/src/text/host_text.dart`: `shuffle`, `playedEvery`,
  `continueTo`.
- `packages/party_host/test/puzzle_continue_test.dart` (new): the 11 tests above.
- `packages/party_host/test/puzzle_screen_test.dart`: the first test now expects
  Next puzzle as the first button and Play again beside it.
- `packages/party_host/test/puzzle_results_test.dart`: the phone and stick walks
  and the race's focus follow the new card.
- `packages/party_host/test/host_focus_ring_test.dart`: the results ring walks
  the five buttons.
- `packages/party_host/test/host_text_test.dart`: three rows for the new words.

## Commit message

```
Series: Next puzzle and Shuffle after a hand-picked puzzle (B-011)

Picking one puzzle on the picker starts a series that remembers the level's
played ids in memory. Its results card offers Next puzzle (first, focused), a
Shuffle toggle, Play again, Change teams and Back in a Wrap, so a phone host
never overflows; Next plays the level's next unplayed puzzle in list order, or
a random one with Shuffle on. Once every puzzle has played, a prompt says so
and offers Continue to the next level. A night and "any puzzle" rounds keep
their own Next. Tests: puzzle_continue_test and the three card tests updated.
```

## Status row

B-011 done: after a hand-picked puzzle, a series with Next puzzle, Shuffle and the level-done prompt (puzzle_continue_test); open: owner's device check of the phone host card and the pad walk.

## Delete

- none
