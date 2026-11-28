# glow1 c1 report: confetti stops moving while the game is paused

## Summary

Done. The confetti burst now freezes when the puzzle is paused and carries on from the same point on resume. A pop that lands during a pause is not shown, and it is not replayed on resume. The burst's look, pop time (`PresentRules.popMs`, 1500 ms), `PresentTracker` and the held line are unchanged, and `puzzle_game` is untouched.

Changes:
- `packages/party_host/lib/src/ui/present_pop_widgets.dart`
  - `PresentConfetti` takes `this.paused = false` (new, dartdoc'd).
  - `didUpdateWidget`: on pause (`paused` turns true while animating) it calls `_burst.stop(canceled: false)`; on resume (`paused` turns false while `0 < value < 1`) it calls `_burst.forward()`. The tracker swap is kept, after the pause logic.
  - `_pop` returns early while `widget.paused`.
  - `build` draws while animating, or while paused partway (`0 < value < 1`), so a frozen burst stays on screen.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` (line 353): `PresentConfetti(tracker: _present, paused: paused)`, still one line. The file is 379 lines before and after (net growth 0, under the 380 gate).
- `packages/party_host/test/present_pop_widgets_test.dart`: added `pausableStage` and `burstPainter` helpers, and two tests per look (menu and TV):
  - `paused confetti freezes where it is and resumes from there`
  - `a pop while paused throws no burst, and resuming does not replay it`
  - The existing tests are kept.

Computed values in the freeze test:
- Pop, then pump 200 ms: progress 200 / 1500 = 0.133.
- Paused, then pump 1 s: `shouldRepaint` against the frozen painter is `false`, so progress is still 0.133 (200 ms).
- Resumed, then pump 500 ms: progress 700 / 1500 = 0.467, so `shouldRepaint` is `true`.
- Pump another 1500 ms: the key is gone. The remaining 1300 ms of the burst finished within that pump.

Decisions:
- Used `shouldRepaint` instead of reading the private `_ConfettiPainter.progress`. `avoid_dynamic_calls` is on, so `dynamic` was not an option. This compares the painter's progress without touching private members.
- A pop while paused is ignored, not queued. The tracker still counts it, and the held line still updates from the tracker. Only the burst is skipped.
- The tests need the new `paused` parameter, so they do not compile on the base. The brief exempts this (a new parameter with no behaviour on the base to pin), so I did not record a base failure.

## Self-check (review-rules part A)

1. Host setups: the widget tests cover the stage with `PresentConfetti` on both looks. The puzzle mount in `puzzle_screen.dart` passes `paused` from the same `Pausable` builder for every host. Not run on a device, so the TV and phone setups are unverified in the app.
2. Kept state: the burst controller is still disposed with the widget (existing test `confetti unmounted mid-burst ...`). A frozen burst is not kept after unmount. No new state outlives the widget.
3. Combinations: the pause flag is the one from `Pausable`, which the puzzle mount already drives. I did not read `Pausable` and did not test the pause menu, host away, player away, "Get ready", a dropped link, the results or leaving with a real `Pausable`. Those are unverified.
4. Files: only the three allowed files and this report were changed.
5. Nothing was skipped. The `puzzle_screen.dart` line is the only change in that file.
6. Looks: the new tests run under `HostLook.menu` and `HostLook.tv` (the loop in the test file). No fixed pixel height was added.

## Checks

- `tools/mine.sh`: OK. It formatted 3 files, analyzed `party_host` (no findings reported), and ran the touched tests (reported `OK 14 tests`). My count of the test cases in the file is 13 (6 per look × 2 looks + 1 plain). I did not reconcile the 14 with mine. Both new tests are in the file and the run is reported as OK.

## Hand-over

- Ready for review. The device check of the TV look during a pause is still open.

## Questions

1. Should a pop that lands during a pause be shown on resume (a replay), or dropped as it is now? The brief did not say, and I chose to drop it.
2. Does `Pausable`'s `paused` also go true for the host-away and "Get ready" states? I did not read `Pausable`, so this is unconfirmed.

## Suggestions

- A device check on the TV: pause mid-burst, then resume, and confirm the burst looks right at 3 metres.

## Commit message

Subject: `fix(glow1): confetti freezes while the game is paused`

```
The present's confetti kept flying while the puzzle was paused. PresentConfetti
now takes paused: a burst in flight stops where it is and carries on from the
same point on resume, and a pop during a pause is not shown or replayed. The
puzzle mount passes its paused flag. Tests cover the freeze, the resume and a
pop while paused, under the menu and TV looks.
```

## Status row

glow1 c1: confetti freezes during a pause and resumes from the same point (pops during a pause are dropped); open: device check of the TV look and the other pause paths (host away, Get ready).

## Delete

- none
