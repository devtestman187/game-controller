# Review: M14 bugs3 i1-ok-presses

## Summary

**needs Claude** — 1 must, 1 should, 1 could.
Most important: the Arena waiting card still cannot be worked from a phone (`arena_waiting_card.dart:110`, `game_screen.dart:310`), so the owner's B-013 ("cannot control TV menu at all") is probably still open, though the report calls only the Arena results card covered.
Next: the lift runs before the press only (`controller_menus.dart:263`), so every phone press leaves the button latched and the next press of the TV remote's OK on it is swallowed until the remote lets go.
Then: `ControllerMenus.okKey` is public though nothing outside the file uses it, and its doc link does not resolve there.

## Findings

- **must** packages/party_host/lib/src/ui/arena_waiting_card.dart:110 the card reads only A and B from the pads and `game_screen.dart:310` keeps the menus on the game there, so a phone still cannot move the focus or press the mode, map or Start rows — the "cannot control TV menu at all" of B-013 → give the card the pad's directions as well (or hand its buttons back to `ControllerMenus`) and test a phone picking a mode and pressing Start.
- **should** packages/party_host/lib/src/ui/controller_menus.dart:263 the lift runs before the press and never after it, so every phone press leaves the focused button's `_isKeyHeld` set (`toy_button.dart:152`) and the next OK from the TV remote on that button does nothing until its own release → lift again after `Actions.maybeInvoke` (or in a `finally`) so no press path leaves a button held.
- **could** packages/party_host/lib/src/ui/controller_menus.dart:92 `okKey` is public but used only inside `_liftOk`, and the file does not import `host_shortcuts.dart`, so the doc link `[hostActivateShortcuts]` resolves to nothing → make it private (or use it for the physical key too) and import the file or drop the brackets.

## Decisions to confirm

- The workaround itself: a `KeyUpEvent` handed straight to `FocusNode.onKeyEvent`, in `party_host` because `toy_look` is outside `allow:`. The report's own suggestion asks for a release API in `toy_look`; the owner decides whether this ships or is replaced before the next caller needs it.
- Up before the press only. Its price is the `should` above (one remote press swallowed after each phone press); confirm that trade.
- The report's "Not done" scopes the Arena waiting card out of the job. B-013 is a Blocker and that card is the one Arena menu a phone cannot work at all, so the scope call needs Claude's word.
- `ControllerMenus.okKey` joins the widget's public surface with no outside caller; confirm it is meant to stay public.

## Could not check

- The suites, `format` and `analyze`: every Bash command here needs approval, so the report's 391/464/117 passes and "both tests fail on the code as it was" are unverified.
- `git diff 758a2b8..c4e4e00` is not permitted either; the change was read from `docs/briefs/m14/bugs3/run-i1-ok-presses.patch` (report, `controller_menus.dart`, `menu_press_test.dart`), so a change outside that patch would be missed.
- Decision 2's probe ("0 key events at a focused widget" from `HardwareKeyboard.handleKeyEvent`) cannot be re-run: the two probe files are gone.
- Whether B-013 meant the waiting card or the results card cannot be settled from the report or the code; the `must` above reads it as the waiting card.

## Commit message
Review: the Arena waiting card still needs the TV remote

The phone's second press is fixed, but the Arena waiting card reads
only A and B from the pads, so its mode, map and Start rows are the
remote's alone (probably B-013's "cannot control TV menu at all").
The lift also leaves a button held after each phone press, so the
next TV-remote OK on it is swallowed; `okKey` is public with no
caller and an unresolved doc link.

## Status row
M14 bugs3 i1 ok presses: reviewed — needs Claude; open: the Arena waiting card cannot be worked from a phone (B-013 likely open), one remote press swallowed after each phone press, and `okKey`'s public surface and doc link.

## Delete
- none
