# b020-next-map — proposal for B-020 (report only)

Job: M14 bugs11 b020-next-map. Proposal only: no Dart, no test, no design file was changed; the only
file written is this one. Read for it: docs/design/party-night.md (N6, §7, §7b, §8),
`packages/party_host/lib/src/ui/game_screen.dart` (`_start`, `_mapFor`, `_again`, `_changeMode`,
`_next`, `_leave`, `_stageBody`), `arena_results.dart`, `arena_map_choice.dart`,
`arena_waiting_card.dart`, `arena_settings_provider.dart`, `solo_skip.dart`, the night's state
(`packages/party_host/lib/src/night/night_state.dart`: the `maps` ledger),
`packages/party_host/lib/src/ui/puzzle_continue.dart` (Shape Race's Next/Shuffle, B-011),
`packages/test_game/maps/index.json`, and docs/briefs/m14/bugs5/pr-map-pick-report.md.

## Summary

- **The ask:** after a Bumper Round a single player can only replay the same map (Play again), go
  back to the waiting card (Change mode) or leave for the game picker (Back). B-020 wants "continue
  to the next map without needing to go to the stage selection".
- **Pick (candidate A): a fourth button, "Next map", on the Bumper Round's results, outside a night
  only.** It starts another round at once on a map this one did not use — the pick the waiting card's
  **Surprise me** makes — so one press replaces today's three (Back → Arena → ready, or Change mode →
  Surprise me → ready). It goes through the existing `_start(null)`, which already picks that map
  (`_mapFor`, `game_screen.dart:215-222`) and records it as `lastMapId` (`:203`): a callback, not a
  new way of starting a round.
- **Every player count outside a night**, not only one: the card must not branch on who is in
  (coding-guidelines §2).
- **In a one-player night nothing is added (b).** The results keep their one Next (§4); the night's
  map step is the waiting card, which b020-solo-card brings back for one player, and §7b already
  opens each Bumper Round on a map the night hasn't used.
- **"Next" means Surprise me** (`mapForRound`'s "not the map just played"), the picker's own word
  (§7b), rather than the library's index order; no new saved state.
- **Risk:** the results card is owner-approved, so a button on it goes back to the owner
  (party-night.md:5); four buttons want a second row on a phone host (the `Wrap` already does that).
- **Size:** `game_screen.dart` is 379 of 380 lines, so the job must free lines first: move the
  `_debugKeys` set (11 lines) to `game_debug_overlay.dart`. Then 376 lines with `_nextMap` and the
  new callback; without the move the file ends at 387.
- **Computed values:** 5 maps in the library (5 play the Bumper Round, 3 the race); after any round
  the Next map button offers 4 of the 5 (never the one just played), each 1 in 4; the results card
  goes from 3 buttons to 4 outside a night and stays 1 in a night; presses from a finished solo round
  to the next map go from 3 to 1.
- **Open for the owner:** is a fourth button on the results card OK, and are the words "Next map"
  right (Shape Race's "Next puzzle" follows the library's order; this one surprises)?

## Today (what the code does; all read in this job)

- **Outside a night, after a Bumper Round**, `ArenaResults` draws three buttons in a `Wrap`
  (`arena_results.dart:174-200`): Play again (`arenaAgain`, the focused first button, replays the same
  map and mode, `game_screen.dart:227-238`), Change mode (back to the waiting card, `:242-248`) and
  Back (the game picker, through `_leave`, `:294-299`). Three buttons is what
  `arena_results_test.dart:67-70` pins.
- **The waiting card is where a map is chosen** (party-night §8): mode buttons, the map cards and
  Surprise me (`arena_waiting_card.dart`, `_chosenId` at `:195-199`, `_pickMap` at `:222-225`). The
  card opens on the map saved in `ArenaSettings.mapId` (`arena_settings_provider.dart:35-36`), or on
  Surprise me when a night passes `surpriseFirst` (`:63-66`).
- **A round's start records its map:** `_start` calls `playedMap(map.id)` (`:203`) so Surprise me
  never repeats it, and `usedMap(map.id)` when a night is running (`:204`). `_start` is what every
  map choice ends in: the card's Start (`onStart`, `:340`) and, for one player today, `SoloRoundStart`.
- **Race rounds never end**, so the results card only ever follows a Bumper Round (party-night §7:
  "At 0 the round is over"; N7: "today's race has no end"). A "Next map" button therefore only ever
  picks a Bumper map.
- **In a night the results have one button**, Next, which records the round and goes to the
  scoreboard (`game_screen.dart:279-289`); `arena_results_test.dart:162-174` pins that the other
  three are gone.
- **The map ledger:** `night_state.dart:167-175` keeps the maps the night has played, and
  `GameScreen._mapFor` adds `lastMapId` to it before calling `mapForRound`
  (`game_screen.dart:218-222`).

## The proposal: candidate A — "Next map" on the results

- **Where:** `ArenaResults`' `Wrap`, **second** (after Play again/the night's Next, before Change
  mode), key `arenaNextMap`, icon `Icons.map`, label `ArenaText.nextMap = 'Next map'`
  (`ArenaText` already holds the Arena's results words, `changeMode` at `arena_text.dart:46`). The
  first button keeps its place, its focus and its meaning, so a child's A press does today exactly
  what it did.
- **When it shows:** `!night` — the same condition the other two menu buttons use, so no new branch
  on player count and no change to the night's card.
- **What it does:** `_start(null)` — the card's own Start with Surprise me chosen. That builds the
  round on `settings.mode` (outside a night: the mode the round just played, since the card is the
  only place that sets it and the card is not reachable from the results), picks the map through
  `_mapFor`, records `lastMapId`, and lands on the field with `_takeFocus()`.
- **Code shape:** `onNextMap` joins `ArenaResults`' constructor (one line in `game_screen.dart`'s
  `ArenaResults(...)` at `:362-369`) and a three-line `_nextMap` that logs and calls `_start(null)`,
  so the log keeps the results' "Results: …" line that `_again` and `_changeMode` write.

## Decisions (low-usage mode)

- **Outside a night only.** A night's results have exactly one way on by design (§4) and the night's
  map step lives on its waiting card; adding a second button there would fight both.
- **Shown for every player count, not only one player.** A rule that changes the card by who is in
  the room is a special case for one caller (coding-guidelines §2), and two players want the same
  "another map" as one.
- **A new button, not a re-purposed one (candidate A, below).** Play again keeps its "same map"
  meaning; removing it to make room would take away a way to replay a map a child likes.
- **"Next" = Surprise me, not the library's order.** It reuses the pick the picker already offers
  and names (§7b), needs no new saved state, and keeps "a map you didn't just play" true; index order
  would add a second, invisible ordering nothing else in the Arena uses.
- **The button starts the round at once, with no card.** The owner's complaint is the extra step;
  a button that opens the card first would be Change mode with a new name. Anyone who wants to
  compare maps still has Change mode.
- **No new bus button/wording in `HostText`:** the Arena's words live in `ArenaText` (`changeMode`
  already does), and `HostText.nextPuzzle` is Shape Race's.
- **A single bumper map degrades gently:** `mapForRound` falls back to any playable map when nothing
  is fresh (`arena_map_choice.dart:26-28`), so the button replays the map rather than disappearing —
  no disabled state to draw or to test.
- **The round goes through `_start`, so `lastMapId` and the night ledger keep one owner** (`:203-204`).

## Candidate B — the same need without a new button

- **What:** outside a night, Change mode opens the waiting card on Surprise me for everyone
  (`surpriseFirst: true`, `arena_waiting_card.dart:63-66`, plus the saved `mapId` left alone). No
  button, no card change.
- **Why it appeals:** zero changes to an owner-approved card, and the map choice stays on the screen
  that draws the maps with their pictures.
- **Risk:** it is still two presses (Change mode, then A to ready) and the word "Change mode" doesn't
  say "new map"; it also silently changes what the card opens on outside a night, which the owner's
  family has seen since M14.2 (a card that remembers the last map is a feature, not an accident).
- **Pick A**, and B stays the fallback if the owner refuses a fourth button: it is one line plus a
  test, and lands later without redoing anything.

## What "next" means, and the ledger

- **The pick:** `mapForRound(maps, mode: last mode, random: _random, chosen: null, used: {lastMapId} +
  the night's maps)`. In a Bumper Round that is "any bumper map except the one just played", chosen
  evenly (`from[random.nextInt(from.length)]`, `arena_map_choice.dart:16-28`).
- **`lastMapId`:** `_start` writes it on every round it starts (`:203`), so Next map advances it and
  the *waiting card's* Surprise me sees it too — a Next map and a card's Surprise me can never land on
  the map just played. Nothing else changes about `ArenaSettings`: `mapId` (the card's saved pick) is
  untouched, so the card still opens on the map the host chose there.
- **The night's used set:** untouched by this button (it never shows in a night). If a later job ever
  puts a map button on a night's card, `_start` already records the map (`usedMap`, `:204`) — no new
  plumbing.
- **Randomness:** the screen's own `Random` made once at the edge (`:99`, design S8), the same one
  Surprise me already uses, so a test can hand in a game but not a seed — the test asserts "not the
  map just played", not which map came up.

## The effect on game_screen.dart (379 lines, cap 380)

- **As it stands** the file has one line of room. The job adds `onNextMap: _nextMap` (1 line, in the
  `ArenaResults` call) and `_nextMap` (7 lines with its doc), i.e. 387 lines: over the cap.
- **Split (pick): move `_debugKeys` (`:31-41`, 11 lines with its doc) to `game_debug_overlay.dart` as
  `debugOverlayKeys`.** It is "the keys that show the overlay", so it belongs with the overlay that
  draws it; `game_debug_overlay.dart` gains one `import 'package:flutter/services.dart';` (it imports
  `material` only today) and goes 127 → 139. `game_screen.dart` stays owner of the `_debug` flag.
  After: 379 − 12 (the block and its blank line) + 1 (import of `game_debug_overlay.dart`) + 8 = 376.
- **Not picked:** pulling the results `Stack` (`:344-371`) into a new widget file. It is the bigger
  seam and the right one eventually, but it needs a value object to carry nine constructor arguments
  (coding-guidelines §3 allows five), so it is its own job, not a rider on a button.
- **b020-solo-card's lines:** that job removes `_alone` (`:106-109`), the `SoloRoundStart` case and
  the `solo_skip` import — about ten lines, which would leave room without the split. I did not run
  that job and make no claim about its result; the split is right either way, and the two jobs don't
  collide beyond this file (that job owns `game_screen.dart` first, so this one lands after it).

## (b) A one-player night's results: no map step there

- The night's card keeps its single Next (`_next`, `:279-289`; `arena_results_test.dart:162-174`).
  Reasons, in order: §4 fixes the night's one way on; the card is owner-approved (party-night.md:5);
  the night's map must be one it hasn't used, and the results card holds only `night: bool`, not the
  ledger; and after b020-solo-card the solo night already walks through the waiting card with its
  map choice — one press of A there is the same "go on" the results would offer.
- **If the owner still wants one press in a night**, the honest place is the scoreboard's Bumper
  Round button (§4, `night_scoreboard_screen.dart:128`), which is already the night's game-type
  choice — not a second button on the results.

## Computed values

| What | Value |
| --- | --- |
| Maps in the library (`packages/test_game/maps/index.json`) | 5: playroom, pinball, block-castle, toy-factory, spinning-tops |
| Maps that play the Bumper Round (`"bumper"` section) | 5 of 5 |
| Maps that play the race (`"race"` section) | 3 of 5 (playroom, block-castle, toy-factory); the button only ever follows a Bumper Round, so only the 5 matter |
| Results buttons outside a night, before → after | 3 → 4 |
| Results buttons in a night, before → after | 1 → 1 |
| Next map's candidates after a Playroom round | 4 (pinball, block-castle, toy-factory, spinning-tops), each 1 in 4 |
| Next map's candidates after a Pinball round | 4 (playroom, block-castle, toy-factory, spinning-tops), each 1 in 4 |
| Presses from a finished solo round to the next map on a new map, before → after | 3 (Back → Arena → A) or 3 (Change mode → Surprise me → Ready) → 1 |
| `game_screen.dart` lines: now / button only / with the split | 379 / 387 / 376 |
| `arena_results.dart` lines: now / after | 309 / ~318 (one parameter, one button) |

## Tests the job would add or update (tests-first, not written here)

- New, `packages/party_host/test/arena_next_map_test.dart`: from the results outside a night, Next
  map starts a round on a map other than the one just played, and `arenaSettingsProvider.lastMapId`
  becomes that map (4 of 5 maps, never the same twice in a row with the real library); with a
  one-map test library the round replays that map (the fallback).
- `arena_results_test.dart`: the three-way test at `:47-70` becomes four ways (add
  `find.byKey(const Key('arenaNextMap'))`, and rename its name); the night test at `:155-174` adds
  `expect(find.byKey(const Key('arenaNextMap')), findsNothing)`; the tap-report test at `:130-145`
  adds `'map'`.
- `menu_press_test.dart:36-46` and `arena_results_test.dart:24-34`: both harnesses build
  `ArenaResults`, so both gain `onNextMap:`.
- A phone-host size test (the brief's arena card tests already run a narrow size): four buttons wrap
  to two rows without overflow.

## Questions and suggestions

1. Is a fourth button on the results card OK (B-020's whole point), and are "Next map" the right
   words beside Shape Race's "Next puzzle" (which is the library's order, with a Shuffle switch)?
   "New map" or "Surprise map" would remove the ambiguity if the owner prefers.
2. Should Next map also appear in a night, at the cost of a second button on a card §4 fixes at one?
   (My pick: no.)
3. The Arena's picker still opens on the saved `mapId` outside a night, so a host who picked a map on
   the card sees that map again after a Next map on the card's next visit — is that wanted, or should
   the card follow `lastMapId`?
4. Suggestion, not acted on: with B-011's Shape Race card at five buttons and this one at four, a
   small "one more round" rule (the same button in every game's results) may deserve a design line
   before M15's games each invent their own.

## Self-check (review-rules part A)

1. **Every host setup:** proposal only; the change is host-drawn (TV, phone host alike) with nothing
   on the wire — a joined phone sees the new round's `view_start` exactly as after Play again. Test:
   the planned `arena_next_map_test.dart` runs on the host harness.
2. **Kept state:** `lastMapId` already starts null and is written once at each round's start
   (`:203`); the button adds no state. Test: the planned assertion on `lastMapId`.
3. **New state combined:** none — the button is the existing `_start` path, so the pause, away, ready
   and results owners are unchanged; the results stage ends the same way Play again ends it. Test:
   the existing `game_screen_test.dart` paths still run.
4. **This folder only:** the only write is this report.
5. **Stop rather than overstep:** nothing outside `allow:` was needed; no contradiction found between
   the brief, party-night §4/§7b and the code. The one file that would exceed its cap is handled by
   the split above.

## Hand-over

B-020's second half is proposed, not built. Next: the owner's OK on the fourth button and the words
(question 1), then one job in `packages/party_host` after b020-solo-card: `ArenaText.nextMap`, the
button in `arena_results.dart`, `_nextMap` in `game_screen.dart` with the `_debugKeys` move, and the
five test updates listed above. If the owner says no to a fourth button, candidate B is a one-line
change to the card's `surpriseFirst`.

## Commit message — a draft

M14 bugs11: proposal for Next map on the Arena's results (B-020)

Report only, no code. A solo player who finishes a Bumper Round can only replay the
map, go back to the waiting card or leave for the game picker. Proposes a fourth
button, "Next map", on the results outside a night: it starts another Bumper Round at
once on a Surprise me map, the one pick the waiting card already offers, so one press
replaces three. No new state: the round goes through the existing start, which records
the map as the last played. A night keeps its one Next, and the waiting card brings the
solo night's map choice back (b020-solo-card). Values, the game_screen line split and
the risks are in docs/briefs/m14/bugs11/b020-next-map-report.md.

## Status row

B-020 is proposed in full: outside a night the Bumper Round's results gain a fourth button, "Next map" (another round at once on a Surprise me map, never the one just played, no new state), while a night keeps its one Next and the waiting card carries the solo night's map step. Open: the owner's OK on the fourth button and its words, then one job after b020-solo-card.

## Delete

- none
