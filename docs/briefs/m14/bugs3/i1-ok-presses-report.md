# M14 bugs3 i1: the phone's OK works on every press

## Summary

- Root cause, one for both reports: every button on the TV is a host button, and a host button presses once and then waits for its key to come back up before it presses again (its `_isKeyHeld` guard, cleared only by a `KeyUpEvent` for Enter, Space, select or the gamepad's A, so a held key's auto-repeat doesn't press it twice). A phone's A never arrives as a key: the TV menus read the pad and press the focused widget with an `ActivateIntent`, the same intent the remote's OK maps to. The first press therefore latched the button, and every later press on it did nothing while the remote kept working. That is B-008 ("first press works, second one doesn't, across the entire UX") and, on the Arena results card's buttons, B-013.
- Fix, `packages/party_host/lib/src/ui/controller_menus.dart`: before an A press the menus now let the OK go up around the focus (`_liftOk`), by walking a `KeyUpEvent` for `gameButtonA` from the primary focus through its ancestors and stopping where it is handled, which is what the remote's release does and exactly where the button's guard listens. Each press then starts from nothing held. `ControllerMenus.okKey` names the key the phone's A stands for.
- Tests, new `packages/party_host/test/menu_press_test.dart`: two successive presses on the focused button, a direction then two presses on the next button, and the Arena results card (two presses on "Play again", then a direction and two on the mode button). Both tests fail on the code as it was.
- Nothing else changed: no protocol, connection, phone-app or text change; no rules, maps or balance.
- Not done: the Arena waiting card still takes the pads itself (A/B ready a phone), so its rows and Start stay the TV remote's there — see Questions.

## Decisions

1. **Lift the OK in the menus, not in the button.** `packages/toy_look` is outside `allow:`, and the button's guard is right for a real key; the caller that presses without a key is the one that must let it go.
2. **Deliver the release through the focus chain, not `HardwareKeyboard.handleKeyEvent`.** The latter exists but does not reach the focus tree (a probe counted 0 key events at a focused widget), and the only members that do (`keyEventManager.keyMessageHandler`, `handleKeyData`) are deprecated, which `--fatal-infos` rejects; the ancestor walk uses `FocusNode.onKeyEvent`/`ancestors` only.
3. **Up before down.** `_liftOk` runs before `Actions.maybeInvoke`, like a remote's release preceding the next press, and so nothing is released after a press may have changed the screen.
4. **Lifts whatever is focused, not a remembered button.** The walk starts at the current focus, so a button latched before a direction move is lifted when the focus comes back to it; no state is kept in the menus.

## Device suggestions

- On the TV with an iPad: on the game picker press OK twice on the same tile, and again on a tile reached with the stick — both presses should act.
- In Arena: two presses on "Play again" on the results card, then right and two on the mode button; open the pause menu mid-round and press OK twice on Resume.
- Check the remote still behaves: one press per OK, and a held OK does not repeat.

## Self-check (review-rules part A)

1. **Every host setup:** unchanged for a phone host's own player (`_tick` still skips local players) and for the TV app's remote; the joined-phone case is the one tested (`menu_press_test`); no protocol change, so an older peer is unaffected.
2. **When kept state starts and ends:** the lift keeps no state — it is one event sent just before each A press; the menus' own state (`_before`, `_repeat`, `_labelled`) starts and ends as before (cleared when the menus get the controllers back).
3. **Combines with:** the pause menu and the results card are menus on the newest claim, so both use the same `HostButton` path (the results are tested, the pause menu is not separately); the Arena waiting card claims the game's controls, so the menus never see its presses (unchanged); away players, dropped links and leaving do not press A at all.
4. **Stay in the job's folder:** only files in `allow:` were written; the two scratch probes are listed under Delete.
5. **Stop rather than overstep:** nothing needed stopping; decision 2 is the choice the rule against deprecated members forced.

## Computed test values

- `menu_press_test`, first test: A twice on "One" → `['one', 'one']` (old code: `['one']`); right, A twice on "Two" → `['one', 'one', 'two', 'two']` (old: `['one', 'one', 'two']`).
- `menu_press_test`, Arena test: A twice → `['again', 'again']` (old: `['again']`); right, A twice → `['again', 'again', 'mode', 'mode']` (old: `['again', 'again', 'mode']`).
- The lifted key is `LogicalKeyboardKey.gameButtonA` / `PhysicalKeyboardKey.gameButtonA`, which is in the button's `_activateKeys`, so its `_handleKeyEvent` clears `_isKeyHeld` and releases the press look.
- Suites: host 391 tests (the 389 from before plus these 2), phone 464, protocol 117, all passing; `format` and `analyze` clean.

## Questions

- The Arena waiting card reads the pads itself (`game_screen.dart` gives the game the controllers while it shows), so a phone readies with A but cannot reach its mode, level, map or Start rows — only the TV remote can. If B-013 meant those rows too, that is a menu-design change for another job.
- Is the focus look in the menus still right when a phone presses A on a button that has none (the look now ends in the same frame as it starts, so a press shows no squish)?

## Suggestions

- `packages/toy_look`'s guard is invisible from outside: a future caller that presses a host button from code (not from a key) will hit the same latch. A small public way to say "this press is over" in `toy_look` would make this job's workaround unnecessary; it is outside this job's `allow:`.

## Commit message
The phone's OK works on every press, not only the first

A host button presses once and then waits for its key to come up, so a
phone's A, which reaches it as the remote's OK without any key event,
latched the button after one press (M14 bugs B-008 and B-013).
The menus now let the OK go up around the focus before pressing it,
and two widget tests cover the second press and the Arena results card.

## Status row
M14 bugs3 i1 ok presses: done — the menus lift the OK before each phone press (`controller_menus.dart`), so every press works in every TV menu including the Arena results; `menu_press_test` covers two presses and the Arena case; open: the Arena waiting card's rows stay the remote's.

## Delete
- packages/party_host/test/_probe.dart
- packages/party_host/test/_probe2.dart
