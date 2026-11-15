# M14 bugs11 b020-solo-both: a solo night's Arena card offers Race and Bumper

## Summary

Owner decision (Nov 15): "Solo party should offer race and bumper." A night's Arena card now shows Race and
Bumper when exactly one player has joined, opening on Bumper as before; a night of two or more keeps Bumper alone,
and its Bumper Round is unchanged.

Changed:
- `arena_waiting_card.dart`: one `night` flag replaces `bumperOnly` and `surpriseFirst`; `bumperOnly` is now
  `night && joined.length >= 2`, so a join or leave on the card adds or takes the race button away. A night opens
  on Bumper until the host presses a mode button (`_pickedMode`). `onStart` passes the shown mode with the map.
- `game_screen.dart`: `_start(mode, chosenMapId)` plays the card's mode, not a forced Bumper. A night's race
  scores nothing: no `usedMap`, no night tag, no recorded round (a race has no end, so no results and no Next);
  the night keeps running and its Bumper Rounds go on (leave the race with Back, Escape or the pause's leave).
- Tests: new `solo_arena_both_test.dart` (3); the solo race-absent pin in `solo_arena_card_test.dart` now expects
  both modes (its intent kept); `arena_night_test.dart`'s reason says "a night of two".
- `docs/design/party-night.md`: N7 and section 8 (line 191).

Test counts: new file 3 (failed on the old code: no race key, no race button); six named suites 55; host 468.

Decisions (no questions asked):
1. `bumperOnly` derived from the card's watched roster: it already watches joined players for the rows and Robo,
   and a mid-card join needs no extra plumbing.
2. A night opens on Bumper without writing the saved mode: `arenaSettingsProvider.mode` changes only on a press.
3. The mode rides with `onStart` as the map does, so a race pick cannot be overridden and the card's `_mode`
   (which filters the maps and Robo) is the round's mode.
4. A solo night's race plays as a plain race, outside the night's scoring (the brief's suggestion): recorded, it
   would burn a night round with no winner, and N7 gives it no end and no points to record.

Open owner question: should a solo night's Race count as a night round (and how it ends and scores), or is playing
it outside the night, as now, right? Also, with one player it races alone (Robo is Bumper-only): intended?

## Files changed

- `packages/party_host/lib/src/ui/arena_waiting_card.dart` — `night` flag; `_bumperOnly` from the joined count
  (2 or more); night opens on Bumper until `_pickedMode`; `onStart(mode, mapId)`; docs. 354 lines.
- `packages/party_host/lib/src/ui/game_screen.dart` — `_start(mode, mapId)`; night scoring only for a Bumper
  Round; `ArenaWaitingCard(night: night != null, ...)`. 378 lines (under the 380 cap).
- `packages/party_host/test/solo_arena_both_test.dart` — new: 3 tests (card content, race pick starts a race,
  two players keep Bumper alone).
- `packages/party_host/test/solo_arena_card_test.dart` — the solo card's race pin now expects the button.
- `packages/party_host/test/arena_night_test.dart` — reason text for the two-player night.
- `docs/design/party-night.md` — N7, section 8.

## Computed test values

- `solo_arena_both_test` case 1: saved mode `race` and saved map `pinball` before the night → card shows
  `arenaMode-bumper` and `arenaMode-race`; `focused(arenaMode-bumper)` true (the card's `_modeFocus`); no
  `chosenMap-pinball` (Surprise me); after `readyUp` + `roundStarted`, `arenaSnapshot.mode == ArenaMode.bumper`
  and `timeLeftMs` non-null (the 60 s clock). Log: `Round started: arena, bumper, Playroom` (Surprise me never
  picks `pinball`, the map saved before).
- case 2: tap race → `arenaSettingsProvider.mode == ArenaMode.race`; after Start, snapshot mode `race`,
  `timeLeftMs == null` (a race has no clock), `partyNightProvider.round == 0`, `night.maps` empty. Log:
  `Round started: arena, race, Block Castle`.
- case 3: two players → `arenaMode-race` findsNothing; snapshot mode `bumper`.
- Old code: case 1 failed on the race key, case 2 on `ensureVisible` of the race button ("Bad state: No element").

## Self-check (review-rules part A)

1. **Every host setup.** One card, so a TV, a phone playing here, a phone that only shows the game and joined
   phones all get both buttons on a solo night — `solo_arena_both_test` case 1 (TV harness) and
   `arena_touch_ready_test` "a night's Bumper Round gives the phone host the same Ready button" (phone host, two
   players, still Bumper alone). No protocol change, so a one-build-older phone is unaffected (not tested
   against an older build: nothing goes over the wire).
2. **When kept state starts and ends.** `_pickedMode` starts false each time the waiting card's State is made,
   ends with it, and means nothing while no card is up; the saved mode changes only on a mode press — case 1
   (race saved, still opens on Bumper) and case 2 (shows race after the press).
3. **How a new state combines with the others.** The pick is card state before the round; `Pausable` still owns
   the playing stage, the pause, the host away and a player away, and the results. Race + night: the night counts
   nothing and stays running — case 2 asserts `round == 0` while the race plays; leaving a race is the existing
   Back/Escape path, unchanged.
4. **Stay in the job's folder.** Only `docs/design/party-night.md` and files under `packages/party_host/lib/src/ui`
   and `packages/party_host/test` — all inside `allow:` (`git status` shows no other file of mine).
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`, and no rule contradicted the code, so
   no stop.

## Checks run

- `flutter test packages/party_host/test/solo_arena_both_test.dart` on the old code: 2 of 3 failed (race key
  absent; race button not found) — the new file fails for the bug's reason.
- `flutter test` on the six named suites (from `packages/party_host`): 55 tests, all pass.
- `tools/check.sh format analyze host`: PASS format, PASS analyze, PASS host (468 tests, 47 s).

## Suggestions (not acted on)

- A solo night's race could say on its field or on the scoreboard that no round was counted, so the host is not
  surprised that the night is still on round 1 afterwards.
- If the owner wants the night to avoid playing the race's map in a later Bumper Round, `_start` would need to
  note it (`usedMap`) without counting a round; today it books nothing.

## Hand-over

The card and the screen now agree on one mode: the card shows it, the screen plays it, and a night only scores
its Bumper Rounds. The remaining question is the owner's (does a solo race belong in a night's rounds), which
does not block the change. Nothing else in the night, the results or the metrics read a race round.

## Commit message

Solo night's Arena card offers Race and Bumper

A night's card now shows both mode buttons when one player is joined, as the
owner asked (B-020 follow-up); a night of two or more keeps Bumper alone. The
card opens a night on Bumper whatever mode was saved, and passes the mode it
shows with Start, so the screen plays it instead of forcing Bumper. A night's
race has no end and no points (N7), so it plays as a plain race: it books no
round and no map on the night, and the night's Bumper Rounds go on after it.
Tests: new solo_arena_both_test, the solo card's race pin updated, and
party-night N7 and section 8 say a solo night offers both modes.

## Status row

M14 bugs11 b020-solo-both: a solo night's Arena card offers Race and Bumper (both modes, opening on Bumper); a night's race plays unscored and the night goes on. Open: owner's call on whether a solo race counts as a night round, and the b020-next-map proposal (not this job).

## Delete

- none
