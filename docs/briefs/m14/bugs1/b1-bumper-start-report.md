# M14 bug b1: starting the Bumper Round on a phone or tablet host, and rows like the other modes

`stop: after it`: the bug is fixed, test-first, and every check named in the brief was run. Nothing is committed.

## Summary

- **A phone or tablet host can always start.** While the waiting card shows and this device is itself a player
  ("Play on this phone"), the card now has a **Ready** button beside its line, at the top of the card: a tap does
  exactly what that player's A does (ready; a second tap takes it back), and the existing rule starts the round once
  every joined player is ready. The line reads "Tap Ready when you're ready." on that host.
- **A TV, and a phone on "Show on this device", are unchanged.** No button, the line still says "Press A when
  you're ready.", and the card opens on its chosen mode with the same focus order as before (no new focus stop).
- **A night's Bumper Round gets the same button**, because it is the same card; no second code path.
- **The rows match the other modes' rows.** The orange ✗ and green ✓ discs are gone: each row is the badge, the
  name and a small word, "Ready" (good green) or "Not ready yet" (soft ink). Robo wears the same word. The host
  phone's own player's row says "(you)", as the join screen's rows do.
- **The other phone-host screens were audited** (item 2): the Shape Race join screen, the night's start card and
  scoreboard, the Arena's results card and the pause menu all offer a tappable control and, where they name a
  button, name the right one for their host. The Arena's waiting card was the only stuck screen; nothing else was
  touched.
- **Files:** `arena_waiting_card.dart` (the own player and the line), `arena_waiting_widgets.dart` (the Ready row,
  the word marking, the "(you)" name), `arena_text.dart` (the new words), and the new test file
  `packages/party_host/test/arena_touch_ready_test.dart` (7 tests). No protocol, app or service change.
- **Not done:** nothing the brief asked for. Nothing outside the brief was changed.
- **On a device, try:** (1) phone/tablet in "Play on this phone" → Play → Arena: tap **Ready** and watch the round
  start when the others are ready; tap it twice to see the ready go and come back; (2) the same in Party night →
  Bumper Round; (3) on a TV: the same card without the button, "Press A", focus where it always was; (4) the rows:
  badge, name, "Ready" / "Not ready yet", and "(you)" on this phone's own row.

## Decisions

1. **The ready control sits in a row of its own under the mode row, beside the line**, not above the map choice:
   Shape Race's Start is also beside its line of words, and there it is above the players and the maps, so a phone
   in landscape shows it without scrolling (the maps alone run past a phone's height).
2. **The own player is found by `ownPlayerIdProvider` plus membership in the joined list**, not by
   `GamePlayer.ownPlayer`: the app already says which player is this device's, the join screen asks the same
   provider, and the field is only read by the connection layer's copy of the player.
3. **The wording follows the button, not the touch flag.** A phone on "Show on this device" is touch-first but has
   no own player; its joined phones press A, so "Press A when you're ready." is the truthful line there.
4. **The marking is one widget (badge, name, word) used by every row of the card.** No shared readiness widget
   exists in the host's screens (the join screen's rows carry no readiness; Robo's was the only other marking), so
   the brief's second choice was used — the same look, in the row's own styles (`type.button` for the name,
   `type.body` for the small word) — and the keys `ready-<id>` / `notReady-<id>` are kept, so nothing else moved.
5. **A tap only toggles; the round still starts by the existing rule** on the card's next 16 ms tick
   (`ControllerMenus.step`), exactly where a phone's A press starts it. One path, one owner.
6. **The own player's row name now goes through `HostText.playerLabel`** instead of a literal built in the widget:
   the text file's words already say "(you)" and "(simulated)", and a finger on the card must see which row is
   theirs.

## The other phone-host screens (brief item 2)

| Screen | What it asks for | Verdict |
| --- | --- | --- |
| Arena's waiting card | "Press A when you're ready." and no pad on screen | **Stuck; fixed here** |
| Shape Race's join screen | Start button; the line picks `beginTouch` / `beginTouchOrPad` on a touch host, and the hint is `hintOwnPlayer` while this phone plays | Fine |
| Party night's start card, scoreboard | Buttons only (`nightShapeRace`, `nightBumper`, `next`, rounds), no pad instruction | Fine |
| Arena's results card | "Play again" / "Change mode" / "Next" buttons | Fine |
| Puzzle's results, pause menu, away card | Buttons; the phone has its own pause and back controls | Fine |
| The Arena field's note while nobody is in | `HostText.noController`: "pair a phone on the main screen" (no pad named) | Fine |

## Tests and computed values

New: `packages/party_host/test/arena_touch_ready_test.dart` (7 tests, each failing on the old card because the
`arenaReady` key and the words did not exist):

1. "a phone host's card gives its own player a Ready button, which readies it and takes it back" — 852×393,
   `ownPlayerIdProvider` = `p1`, `hostTouchFirstProvider` = true; expects `arenaReady`, "Tap Ready when you're
   ready.", the row `P1 iPhone 3F1C (you)` (sample roster's P1), "Not ready yet", then "Ready", then "Not ready
   yet" again; Robo's label is "Ready".
2. "the Ready button and a joined phone's A start the round when every player is ready" — phones p1 and p2
   (`phoneInfo('p2', 2)` → "P2 Phone 2"); tap Ready → p1 ready, p2 "Not ready yet"; P2's A → the card is gone and
   the `arena` field is drawn.
3. "a night's Bumper Round gives the phone host the same Ready button" — the night's card is up, tap Ready, 5 s of
   frames (`roundStarted`): the `arena` field runs.
4. "a TV's card has no Ready button, keeps the Press A line, and opens on its chosen mode" — 960×540, no overrides:
   no `arenaReady`, "Press A when you're ready.", no "(you)" row, primary focus `arena waiting mode`, one
   arrowRight lands on `arenaMode-race` (the old order).
5. "a phone that only shows the game has no Ready button: the joined phones press A" — 852×393, touch first, no own
   player: no button, "Press A when you're ready.".
6. "the rows mark readiness in words beside the badge and the name, as the other rows do" — a `PlayerBadge` in
   `arenaPlayer-p1`, "Not ready yet" → "Ready" after P1's A, and no `Icons.cancel` anywhere on the card.
7. "a phone in landscape shows the Ready button without scrolling" — 852×393 with the look's real fonts: no
   exception, the button's top ≥ 0 and its bottom ≤ 393 (the ready row is the card's second row).

Suites: host 387 tests (380 before + 7), phone 463, tv 53 (1 skipped), all passing; `dart analyze --fatal-infos`
clean; `dart format` clean.

## Self-check — docs/review-rules.md part A

1. **Every host setup.** TV: no button, same line, same focus (test 4). Phone on "Play on this phone": button, tap
   line, round starts (tests 1, 2, 7). Phone on "Show on this device": no button, "Press A" (test 5). Joined phone:
   its A still readies it and starts when all are (test 2); a night's card behaves the same (test 3). One build
   older: the card is host-side only and no protocol changed, so an older joined phone is a plain controller; an
   older host build keeps today's card until it updates.
2. **When kept state starts and ends.** `_ready` and `_before` are the card's own, as before: they start empty when
   the card opens, are pruned each tick to the joined players, and die with the state when the card is disposed.
   The new button only calls `_toggle`, which writes `_ready`, so it ends exactly where a row tap and an A press do;
   `_ownPlayerId` is derived and holds nothing.
3. **How a new state combines.** The ready control adds no phase, timer or blocker: the round still starts only
   through `onStart`, and `Pausable` still owns everything after it. It cannot combine with the pause menu, the host
   away, "Get ready", a dropped link or the results — those all begin after the card is gone; the existing away/
   leaving pruning of `_ready` is untouched. Tests: 2 and 3, plus the existing `arena_waiting_test` and
   `arena_night_test`, which pass unchanged.
4. **Stay in the job's folder.** Changed only `packages/party_host/lib/src/ui/{arena_waiting_card,
   arena_waiting_widgets}.dart`, `packages/party_host/lib/src/text/arena_text.dart`, the new test file and this
   report — all inside `allow:`.
5. **Stop rather than overstep.** Nothing needed a file outside `allow:`, and no rule contradicted the code. The one
   reading taken is Decision 4 (no shared readiness widget exists); it is listed there with its reason.

## Questions and suggestions

1. **Suggestion (not done):** the host phone's own player could also show its badge and name on the night start and
   scoreboard; today the scoreboard lists it like any phone, without "(you)". One line in `NightText` would do it.
2. **Question:** the ready button wears the focus yellow while ready (as the mode buttons show "chosen"). If the owner
   would rather it keep the paper look and only change the word, that is a one-line change.

## Commit message

Fix: the Bumper Round starts from a phone or tablet host

The Arena's waiting card had no way to start on a host device that plays
here: the host phone builds no pad over its menus, so its own player could
never press A. The card now shows that player a Ready button beside its
line, which readies and un-readies exactly as its A does, and the line says
"Tap Ready when you're ready."; a TV and a phone that only shows the game
keep "Press A" and their focus order. A night's Bumper Round uses the same
card, so it is fixed with it.

The rows also lost the orange X and green check discs: each is the badge,
the name and a small "Ready" / "Not ready yet", and the host phone's own
row says "(you)", as the join screen's rows do.

## Status row

M14 bug b1: a phone or tablet host can start the Bumper Round from the waiting card (Ready button, "Tap Ready" line, same card in a night) and the rows mark readiness in words — done, checks pass; open: the owner's device test, and nothing else.

## Delete

- none
