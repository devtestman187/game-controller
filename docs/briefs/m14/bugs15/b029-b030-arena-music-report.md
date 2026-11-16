# M14 bugs15 B-029/B-030 — Arena music: back after Play again and on the waiting card

## Summary

`HostMusic.roundScreenOpened` took `arena` alone, so the music knew a round screen was open but not
where it was in it. Now it takes an optional `waiting` too (M14 bugs B-030): while the screen sits on
its waiting card, `_wanted` returns the lobby's loop even though a round is held. `GameScreen` also
reports its stage at every stage change — the card in `initState`, `_start`, `_again` and
`_changeMode` — and that clears the last round's end, so Play again's round gets the Arena's piece
back at its own "go" (M14 bugs B-029). Once the results' `_roundEnded` was forgot, the round's music
comes back on its own when `Pausable` says it plays; nothing else in the music changed.

Tests: `packages/party_host/test/arena_music_test.dart`, 4 tests, written first. All 4 failed on the
old code, each at its own first expectation and each with the music null where a loop was wanted: the
card's `lobby`, Play again's `arena`, Change mode's `lobby`, and the `lobby` of Music turned up on the
card (the silent half of that test passed as it should). All 4 pass now. The 13 music and Arena suites I ran together with it: 96 tests, all pass.
`tools/check.sh format analyze host`: PASS, PASS, PASS (513 host tests). `game_screen.dart` is 378
lines, `lobby_music.dart` 364 (limit 380).

Decisions:
1. The flag goes on `roundScreenOpened` rather than a method of its own, so one call both says where
   the stage is and clears `_roundEnded` — B-030 and B-029 share the call and no caller can forget
   half of it.
2. `GameScreen` reports inline at its four sites, no helper: the file was 375 lines and a documented
   helper would have taken it past 380.
3. With no lobby open, the waiting card stays silent (as before) rather than inventing music: the TV
   app's debug start (`START_GAME=arena`) mounts `GameScreen` without the picker.
4. `_waiting` is reset in `roundScreenClosed`, so leaving the card (Back) leaves nothing held.
5. `PuzzleScreen` is untouched: `waiting` defaults false, so Shape Race's music and rules are as they
   were.

Fixed, unverified: needs device check (an iOS phone host and a TV).

## Files changed

- `packages/party_host/lib/src/ui/lobby_music.dart` — `_waiting` field; `roundScreenOpened(writer,
  {arena, waiting})`; `_wanted` returns the lobby's loop while waiting and a lobby is open;
  `roundScreenClosed` clears the flag; the class and method docs say so.
- `packages/party_host/lib/src/ui/game_screen.dart` — reports its stage to the music in `initState`
  (with the stage it starts on), `_start`, `_again` (no waiting) and `_changeMode` (waiting); the
  `_music` field's doc says so.
- `packages/party_host/test/arena_music_test.dart` — new, 4 tests (below).
- This report.

`lobby_music_widgets.dart` needed no change: `RoundHold` and `LobbyHold` are unchanged and the
waiting card is inside `RoundHold` already.

## Test values

- Card: the picker's `lobby` loop carries on to the card — `sounds.loop == 'lobby'`,
  `loopStarts == ['lobby']` (no restart). Start: `loop == 'arena'`, `loopStarts == ['lobby',
  'arena']`, `loopStops == [Duration.zero]` (the lobby stops at once; the Arena's piece starts at
  "go", after the 3 s beat).
- Play again: the Bumper Round's clock run to 0 puts the results up with `loop == null`; after
  `arenaAgain` and 5 s of frames, `loop == 'arena'`, two `'arena'` starts (the first round's and the
  new one's; the clock's `arena_hurry`/`arena_final` switches are starts too), one `'lobby'` start.
- Change mode: back on the card, `loop == 'lobby'`, a second `'lobby'` start; then Start (all phones
  ready again) gives `loop == 'arena'`, a second `'arena'` start.
- Music at 0%: set before the picker opens, the card is silent (`loop == null`, no starts); at 60%
  the card plays `'lobby'`.

## Self-check (review-rules part A)

1. **Every host setup.** TV/PC host and the phone host build the same `GameScreen` and `HostMusic`
   with no platform branch added; joined phones mount neither hold and never play it. The four new
   tests run the TV-size harness (960×540); the phone host is the same screens, but I ran no device
   — that is the device check above. An older build keeps the old bug either way: no protocol or
   saved-format change.
2. **When kept state starts and ends.** `_waiting` starts when the screen opens on its card
   (`arena_music_test` "the waiting card plays the lobby's loop" and "Change mode brings the lobby's
   loop back"), ends on Start and Play again (the same two tests: the round's `arena` plays), and on
   `roundScreenClosed` when the screen goes (`arena_back_test` leaves the card; its music is not
   asserted there). With no round held the flag is never read.
3. **How a new state combines with the others.** The card has no `Pausable` under it, so the pause
   menu, the host away and a player away cannot be up with it, and the results are another stage
   (`_stage`), so `waiting` and `roundEnded` never hold together. Card × leaving is `arena_back_test`
   (the round closes and the lobby's loop is the one wanted again); card × results is the
   "Change mode" test's first half (`loop == null` on the results).
4. **Stay in the job's folder.** Only the four allowed paths were written: the two `lib` files, the
   new test file and this report.
5. **Stop rather than overstep.** Nothing was needed outside `allow`, and the brief's contract could
   be met as written. The one oddity I saw (the tempo blip under Questions) is reported, not fixed.

## Questions

1. Play again for the Arena starts one frame of `arena_final` before `arena`: the old round's last
   clock report (0 ms) reaches the music after `roundScreenOpened` reset it, so `loopStarts` ends
   `… 'arena_final', 'arena'` (test b). Shape Race has the same leak, hidden because its last tempo
   is normally `round`. Out of this brief; a follow-up could ignore a round's clock reports until
   its phase is playing.
2. During a night the same card is the night's stage, so it now plays the lobby's loop there too.
   That is what "the card plays the lobby music like the picker and join screen" asks for, but it is
   a visible change to a night's first screen.

## Hand-over

The card's music and Play again's are fixed behind one call (`roundScreenOpened`) that every stage
of the Arena's screen now makes. Left: the device check (an iOS phone host and a TV) — listen to the
card, Start, Play again and Change mode then Start. If the Play again tempo blip (Questions 1) is
worth a job, the music's clock report needs a guard until the phase is `playing`; the new test (b)
already prints the switch order.

## Commit message

Arena card plays the lobby's loop, and every round its own again

HostMusic.roundScreenOpened takes a `waiting` flag (B-030): while the Arena's
screen sits on its waiting card, the lobby's loop plays there, as on the picker
and the join screen.
GameScreen reports its stage at the card, Start, Play again and Change mode, so
the last round's end is forgot and Play again's round gets the Arena's piece
back at its own "go" (B-029).
New arena_music_test.dart covers the card, Play again, Change mode then Start,
and Music at 0%.
Shape Race's music, the loops' volumes and the lobby's rules are unchanged.

## Status row

M14 bugs15 B-029/B-030: the Arena's waiting card plays the lobby's loop and every round (Play again, Change mode then Start) starts the Arena's piece again — done, tests pass; open: a device check on an iOS phone host and a TV, and a follow-up for the one-frame tempo blip after Play again.

## Delete

- none
