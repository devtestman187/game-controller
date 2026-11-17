# B-031: a stick disposed with a thumb on it

## Summary

`_AnalogStickViewState._up` ran after the stick's State was disposed: a thumb still
on a stick when its screen goes (round end, layout change, reconnect) lifted its
pointer over the dead `Listener`, so `setState` and `ref.read(padProvider)` ran on a
defunct State (Sentry, iPad iOS 26.6.2, m14.8 build 835). The stick also never sent
its release, so the TV kept it pushed.

What changed in `controller_app/lib/src/ui/stick_widgets.dart`:

- `_up` returns when `!mounted` (before `setState` and `ref.read`).
- `_move` has the same guard: a drag can land after the stick is gone, the same way
  a lift does.
- `dispose()` sends `stick(side, stickCenter, touched: false)` if a pointer is still
  down, on a pad notifier captured in `initState` (`ref` is unusable in `dispose`).
- The release is deferred with `Future.microtask`, because riverpod refuses a
  provider change while the widget tree is finalizing (the error I got first), and
  it is skipped when the app's `ProviderScope` went with the screen (no pad left to
  tell, and the call would throw `UnmountedRefException`).

Tests: new file `controller_app/test/stick_dispose_test.dart`, 4 tests. On the old
code two failed: the lift after dispose with `setState() called after dispose()`, and
the release test with left still at `(0.0, -0.444)`. All 4 pass now. The normal
down/move/up test also passed on the old code — it is the regression guard the brief
asks for, not a failing-first test. Checks: `format` PASS, `analyze` PASS, `phone`
PASS (532 tests), `tools/review.sh` 0 fail, 0 note.

Stick behaviour while mounted, layout, look and settings are unchanged.

**Fixed, unverified: needs device check (thumb on stick while the round ends).**

## Files changed

- `controller_app/lib/src/ui/stick_widgets.dart` (273 lines, was 237): the two
  mounted guards, the captured pad and scope, and the release in `dispose`.
- `controller_app/test/stick_dispose_test.dart` (new, 129 lines): the four tests.

## The tests and the values in them

`_StickHost` puts one `AnalogStickView` (left, fixed) in a 200 x 200 box, so the
radius is 100 px and the dead zone is the default 0.1. It pumps on the app's fakes
with `pumpFaked`, and starts stick mode with `switchMode(tilt: false, sticks: true)`
so both sticks exist and send, as the app's own start does. `removeStick()` takes the
stick off the screen (what a round end or a layout change does) while the thumb is
down.

1. **lifting the thumb after the stick is gone throws nothing** — down, `moveBy(40, 0)`,
   remove, `up()`; `takeException()` is null. Why 40 px is 0.333: `x = 40/100 = 0.4`,
   past the dead zone, `(0.4 - 0.1) / (1 - 0.1) = 0.3333`, rounded to 0.333 by the pad.
   Old code: `setState() called after dispose(): _AnalogStickViewState` (the bug).
2. **the stick taken away with the thumb on it sends its release** — down,
   `moveBy(0, -50)` (y: `(0.5 - 0.1) / 0.9 = 0.444`, negative upwards), remove;
   `padProvider` left is `stickCenter` and the last input the fake client got ends
   `'L 0.0,0.0 R 0.0,0.0'`. Old code: left stayed `(0.0, -0.444)` — no release.
3. **a thumb still down when the whole screen goes throws nothing** — the same, then
   `pumpWidget(const SizedBox.shrink())`, which disposes the `ProviderScope` itself;
   the deferred release must not run then. Without the scope check this test throws
   `UnmountedRefException` from `PadNotifier.stick`.
4. **a thumb moved and lifted while the stick stays still moves and releases it** —
   normal path: center at down (dead zone), `(0.0, -0.444)` after the move,
   `stickCenter` after the lift, no exception.

## Decisions

- **`Future.microtask` for the release.** The brief's option, taken because the
  synchronous call threw "Tried to modify a provider while the widget tree was
  building ... while finalizing the widget tree". Doing it in `deactivate()` instead
  hits the same guard (tried it).
- **The release is skipped if the app's scope is gone.** `ProviderContainer.exists`
  is not a liveness check here: it still returns true after the container is
  disposed, and the call then threw `UnmountedRefException`. `Notifier.ref` (whose
  `mounted` would say it) is protected (analyzer: `invalid_use_of_protected_member`).
  So the stick keeps the ancestor `ProviderScope`'s `State` from `initState` and
  checks `mounted`. A plain `ProviderScope` at the app's root always exists, so this
  is never null in the app; if it were, no release is sent, which is the safe side.
- **`late final` fields set in `initState`** for the pad and the scope:
  `docs/project-notes.md` line 120 says exactly this for a `late final` that uses
  `ref` (set it in `initState`, or `dispose` throws).
- **`_move` guarded too.** It is the same pattern as `_up` (a `ref.read` from a
  pointer callback after dispose), which the brief's item 3 asks me to guard.
- **No other State class in the file.** `StickModeView` is a `ConsumerWidget`
  (stateless) and `StickPainter` is a `CustomPainter`; `_AnalogStickViewState` is the
  only State in `stick_widgets.dart`.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** Not affected: the change is on the phone's pad only, and the
   same code runs on a joined phone, on a phone hosting ("Play on this phone") and on
   "Show on this device" — the pad and its provider are the app's own in all of them.
   The TV only ever receives the release it now gets instead of a stuck stick.
2. **When kept state starts and ends.** The captured pad and scope start in
   `initState`; the only kept thing is the optional one-shot microtask, which ends by
   running or by finding the scope gone; nothing stays after the widget is disposed.
   Tested by tests 1-3 (the check that nothing throws after dispose).
3. **How a new state combines with the others.** It only adds a release at dispose:
   it can combine with a round end (`padOnScreenProvider` dropping the pad, and the
   round end also calls `releaseAll`), a layout change (the too-small view), and
   leaving; a double release is harmless (the pad sends nothing when the stick is
   already centered — `_apply(..., force: true)` only records the held controls).
   Tested by tests 2 and 4.
4. **Stay in the job's folder.** Only `stick_widgets.dart`, the new test file and this
   report changed.
5. **Stop rather than overstep.** Nothing needed outside `allow:`; no stop.

## Hand-over

- The fix is small and covered by tests; the one thing tests cannot show is a real
  thumb on a real stick while a round ends on an iPad — that is the device check
  named above.
- `touched: false` is not visible in `PadInput` (it only feeds the M9 held metrics),
  so test 2 proves it by the release being sent and the stick being back at
  `stickCenter`; a check on the metric needs an active metrics session.
- Pointed at but not changed (outside `allow:`): `DpadView`, `SmallButton` and
  `FaceButtonsView` take `pad` from `ref.read` in `build` and call `pad.up(pointer)`
  from their `_PointerArea` `Listener`; if the whole `ProviderScope` goes while a
  button is down, that stale lift would hit the same `UnmountedRefException`. Only
  when the app's root itself is replaced, not on a normal round end.

## Commit message

Fix B-031: a stick disposed under a thumb no longer crashes

A thumb still on a stick when its screen goes (round end, layout change,
reconnect) lifted over the dead Listener: `_up` ran setState and ref.read on
a disposed State, and the stick was never released.

`_up` and `_move` return when unmounted; dispose sends the stick back to its
center with touched false, through a pad captured in initState, in a microtask
after the tree finalizes and only while the app's scope is still there.
New `stick_dispose_test.dart` covers the lift, the release, a whole-screen
teardown and the normal down/move/up path.

## Status row

B-031 fixed and unit-tested (stick dispose: `_up`/`_move` mounted guards, release in `dispose`); open: device check with a thumb on a stick while a round ends, and the same stale-pointer pattern in the button widgets (not in this job's allow list).

## Delete

- none
