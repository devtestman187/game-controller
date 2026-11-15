# M14 bugs11 b020: a night's one player gets the Arena's card back (B-020)

Job: `docs/briefs/m14/bugs11/b020-solo-card.md`. Gate: after it, in the job's low-usage mode (no stops for questions). **Status: done.**

## Summary

- **The bug**: B-002 (d4b8731) made a night's one player start the Bumper Round at once (`SoloRoundStart`), so the Arena's waiting card — its map choice and its mode button — never showed. Outside a night it always showed.
- **The fix**: the Arena no longer skips its card. `GameScreen`'s `_alone` field, its `when _alone` branch and the `SoloRoundStart` class are gone; `_Stage.waiting` always returns `ArenaWaitingCard(bumperOnly: night != null, surpriseFirst: night != null)`. `skipsLobby` stays for Shape Race's join screen only, with its doc comment rewritten.
- **The test**: new `packages/party_host/test/solo_arena_card_test.dart`, 3 widget tests. Its first test failed on the old code — `find.byKey(const Key('arenaWaitingCard'))` was `findsNothing` for a night's one player — and passes now.
- **Counts seen here**: the new file 3 tests (1 red on the old code, 3 green after); `night_round_test` + `solo_skip_test` + the new file 23 tests green; `night_reveal_test` + `arena_night_test` + `arena_touch_ready_test` + `arena_waiting_test` + `night_robo_test` 31 tests green; then `tools/check.sh host` 465 tests and `tools/check.sh phone` 475 tests, both green. `tools/review.sh`: 0 fail, 1 note (the size note on `game_screen.dart`, which my change made 7 lines shorter).
- **Decisions**: the night's card keeps its Bumper-only mode button (its points need the Bumper Round), so the game-type half of the owner's row is not answered — see the open question; `SoloRoundStart` is deleted rather than left unused (guidelines §2, "Leftovers"); `solo_skip.dart` stays because Shape Race still uses `skipsLobby`.
- **Open question for the owner**: *should a solo night show both modes on the Arena's card?* The card shows Bumper alone in a night because night points and the scoreboard assume the Bumper Round (design section 8, N7). Showing Race there would need the night to score a race (today it has no end) — a bigger change than B-020.
- Out of scope, as the brief says: no Next-map button (that is `b020-next-map`).

## Changes

| File | What changed |
| --- | --- |
| `packages/party_host/lib/src/ui/game_screen.dart` | The `_alone` field and the `case _Stage.waiting when _alone: return SoloRoundStart(onStart: _start);` branch are gone, with the `solo_skip.dart` import; the class comment and the waiting branch now say the card always shows (B-020). 373 lines after the change (was 380). |
| `packages/party_host/lib/src/ui/solo_skip.dart` | `SoloRoundStart` and its state (and the Flutter, riverpod and `arena_settings_provider` imports) deleted. The `skipsLobby` doc comment now says it is Shape Race's rule alone and that the Arena's card is never skipped. |
| `packages/party_host/lib/src/ui/night_start_screen.dart` | `_startBumperRound`'s comment: the Arena's card follows, with one player or more (B-020). No code change. |
| `packages/party_host/test/solo_arena_card_test.dart` (new) | 3 tests, below. |
| `packages/party_host/test/night_round_test.dart` | The old pin "a one-player night Bumper round skips the waiting card and starts at once" now says "starts on its card's Start, as the night's first round": it expects the card, readies the only player, and still checks `arenaSnapshot(tester).mode == ArenaMode.bumper` and `roundTags == ['night_1of3']`. |
| `packages/party_host/test/solo_skip_test.dart` | Test names and the file's doc comment now name Shape Race (the rule itself is unchanged: 1 player in a night → true, else false). |
| `packages/party_host/test/arena_night_test.dart` | The two-player setup comment no longer says "one alone skips the card (B-002)". |
| `packages/party_host/test/arena_touch_ready_test.dart` | The same stale comment on the phone host's two-player night setup. |
| `docs/design/party-night.md` | N6: a night's one player skips Shape Race's join screen only; the Bumper Round always goes to the Arena's card, one player or more (B-020). Section 8, second bullet: the card is always shown, opens on Surprise me in a night, and Shape Race's join screen is the only screen a one-player night skips. |

## The new tests and the values they expect

`packages/party_host/test/solo_arena_card_test.dart`:

1. **"a night's one player gets the Arena's card, on Surprise me, and the round waits for Start"** — a pinball map is saved on `arenaSettingsProvider` before the night opens; one phone `p1`; Party night → `nightBumper`. Expects: `arenaWaitingCard` once; `arenaMode-bumper` once; `arenaMode-race` none (a night plays the Bumper Round alone); `arenaMap-pinball` once; `chosenMap-pinball` **none** (Surprise me is lit even though a map is saved, design section 7b); `notReady-p1` once. Then a second of frames: the card is still up and `arena` (the field) is absent, so nothing started on its own. Then `readyUp` + `roundStarted`: the card is gone and `arenaSnapshot(tester).mode == ArenaMode.bumper`.
2. **"a night's card is the same for two players as before"** — `p1` + `p2`: the card is up, `P2 Phone 2` has its row, no field; after `readyUp` the field is up.
3. **"outside a night one player keeps the card with both modes"** — Play → Arena with `p1`: the card is up, `arenaMode-race` is there, no field.

**The red run on the old code** (before any lib change): test 1 failed at its first expectation, `find.byKey(const Key('arenaWaitingCard'))` was `findsNothing` — the bug's exact reason. Tests 2 and 3 passed on the old code too, as they must: they pin what B-020 leaves unchanged.

## Decisions

- **The night's card keeps Bumper alone.** Night points, the scoreboard and the awards assume the Bumper Round (design section 8 and N7); adding Race to a solo night would need a night-scored race, which is not this job. Listed as an open owner question above.
- **`SoloRoundStart` deleted, not parked.** Nothing else used it, and the guidelines refuse dead code; `game_screen.dart` also lost the import, the field and the branch.
- **`solo_skip.dart` kept.** `games_screen.dart` still calls `skipsLobby` for Shape Race's puzzle pick, which keeps its solo board. Only the doc comment changed.
- **The old pin rewritten, not deleted.** `night_round_test`'s test was the only place checking a one-player night Bumper round's `roundTags`; it now readies the lone player and keeps that assertion.
- **Surprise me checked by absence.** The card's Surprise me has no `chosenMap-` key (only maps get one), so "opens on Surprise me" is shown as "no map is chosen while a map is saved".

## Self-check (review-rules part A, 1–5)

1. **Every host setup.** TV/PC host: `solo_arena_card_test.dart` test 1 (a TV-sized host with one joined phone). A phone host that plays here: `arena_touch_ready_test.dart` "a night's Bumper Round gives the phone host the same Ready button" (its own player readies with the Ready button, unchanged and green). A phone that only shows the game, and a joined phone: the same file's other tests, green. One build older: no protocol or snapshot change at all (the card is host UI only), so nothing changes for it.
2. **When kept state starts and ends.** The only kept state removed is `SoloRoundStart`'s one-shot `_asked` flag with its post-frame start: it existed only to start a round the moment the maps were in, and no timer or callback outlives it now. The card's own state (its tick timer, `_ready`, `_picked`, `_started`) starts when the card mounts and ends in `dispose` — unchanged, and covered by `arena_waiting_test.dart` and `arena_touch_ready_test.dart`.
3. **How a new state combines with the others.** No new blocking state: a one-player night now uses the same waiting stage as everyone else, so its pairs with the pause menu, the host away, a player away, "Get ready" and the results are the pairs the card already had (`pause_menu_test.dart`, `away_card_test.dart`, `arena_waiting_test.dart` "the TV gets the 3-2-1 beat too"). Test 1 also proves the stage no longer skips itself: nothing starts without a press.
4. **Stay in the job's folder.** Every path I wrote is under the job's `allow:` list (the nine files in the table above), checked with `git status --short`.
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`; the Next-map button belongs to `b020-next-map` and is not built.

## Checks

- `flutter test test/solo_arena_card_test.dart` (old code): 1 failed, 2 passed — the red proof.
- `flutter test test/solo_arena_card_test.dart test/night_round_test.dart test/solo_skip_test.dart`: 23 passed.
- `flutter test test/night_reveal_test.dart test/arena_night_test.dart test/arena_touch_ready_test.dart test/arena_waiting_test.dart test/night_robo_test.dart`: 31 passed.
- `tools/check.sh format analyze host phone`: PASS format (4 s), PASS analyze (22 s), PASS host (465 tests, 53 s), PASS phone (475 tests, 64 s); run again after the two comment fixes: format, analyze and host PASS (465), phone PASS (475).
- `tools/review.sh`: 0 fail, 1 note — `game_screen.dart` 373 lines (lib aim 300, hard limit 400); it was 380 before this change, so the note is not new.

## Hand-over

- The Arena's waiting card now shows for every round, a night's one player included, so B-020's "map and game type" is answered for the map, and for the mode only as far as a night allows (Bumper alone).
- `b020-next-map` can build on this: the card is now always up before a night's Bumper Round, so a "Next map" control has a card to live on.
- Nothing else in the night flow changed: the night still starts on its button, records on Next, and the solo Shape Race skip is untouched.

## Commit message

M14 bugs11 b020: a night's one player keeps the Arena's card

The Arena's waiting card always shows, with one player or more: a
night's only player picks the map (opening on Surprise me) and
presses Start, instead of the round starting at once (B-002).
SoloRoundStart and GameScreen's `_alone` branch are deleted;
skipsLobby stays for Shape Race's join screen alone. party-night N6
and section 8 say so, and the pins that assumed the card-less start
now expect the card.

## Status row

M14 b020 (solo Arena card): done — a night's one player gets the Arena's waiting card back with its map choice and Start, `SoloRoundStart` and the `_alone` branch deleted, `skipsLobby` now Shape Race's only, design N6 and section 8 updated, 3 new tests; open: the owner's answer on showing both modes in a solo night, and the Next-map button (b020-next-map).

## Delete

- none
