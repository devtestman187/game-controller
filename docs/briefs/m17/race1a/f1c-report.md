# race1a f1c report

STATUS: stopped, no file changed.

## Why

`_SidePanel` is built by `_Sides`, and `_Sides` is built by `_JoinBody`. `_JoinBody` lives in
`packages/party_host/lib/src/ui/join_screen_widgets.dart`, which is not in the allow list. `_JoinBody` has no `seats`
parameter, and `JoinScreen.build` (join_screen.dart:352) builds it. For `seats: cap` to reach the panel, `_JoinBody`
needs a new `seats` field passed to `_Sides` (`join_screen_widgets.dart:162-195`).

Workarounds I did not take, because each is a design decision:
- an InheritedWidget or provider that carries the cap from `JoinScreen` to `_Sides`;
- `_Sides` reading `puzzleSettingsProvider` and the level itself, which would duplicate `maxPerSideFor`.

## Questions

1. Add `packages/party_host/lib/src/ui/join_screen_widgets.dart` to the allow list (a `seats` field on `_JoinBody`,
   passed to `_Sides`)? Or pick one of the workarounds above?
2. The brief says `JoinSidePanel.seats`, but the class is private (`_SidePanel`, `_Sides`). I assume the `seats` parameter
   goes on both.

## Commit message

none (stopped before any change)

## Status row

race1a f1c: not started; blocked on join_screen_widgets.dart missing from the allow list.

## Delete

- none
