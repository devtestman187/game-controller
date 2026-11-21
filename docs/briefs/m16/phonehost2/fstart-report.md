# fstart — the night start loses its scroll net, and the phone frame zeroes the bar inside it

## Summary

- **Step 0 (bar room).** New `controller_app/test/host_bar_zero_in_frame_test.dart` (2 tests, fail on the old code):
  at 852x393 the level list's title bar starts at the frame's top, device y **52** (was **84.84** = 52 +
  52 x 0.6314814814814815), and `party.hostBarHeightProvider` reads **0** for a screen inside the frame
  (`ShapeRaceScreen`, `GamesScreen`) and **52** on `ControllerScreen` outside it. Fix: `HostFrameGate` wraps the
  frame in a nested `ProviderScope` overriding `party.hostBarHeightProvider` with 0.
- **Steps 1–2 (night start).** New `packages/party_host/test/night_start_noscroll_test.dart` (20 tests, all fail on
  the old code): at the five sizes, 4 and 6 players, a fresh and a running night, the start screen holds **no
  Scrollable**, no overflow, and every line (awards title, awards row, cat line, players line, pick-round line) is
  wholly inside `hostFrameBody`. The card's content measures **286.0 frame px** everywhere (sizes, roster and
  night state do not change it); the body is 392, 452 or 572 frame px, so the net was never reached inside the
  frame. Fix: the scroll view is gone; the body is the column itself (Spacer kept, nothing shortened).
- `night_start_frame_test.dart` no longer asserts a scrollable is present (it asserts none is, same rule). Three
  controller tests that pinned the doubled bar are rewritten to the same intent (see below).
- **Blocker, not fixed (outside `allow:`):** two tests still draw the night start **unframed** at 852x393, where
  the old `HostFrameScreen` body is 393 - 64 - 84 = 245 px against the card's 286 px: the card now overflows by
  **41 px** (the figure S3 predicted) and they fail:
  `arena_touch_solo_night_test.dart` "a lone night player..." and `arena_touch_ready_test.dart` "a night's Bumper
  Round gives the phone host the same Ready button". Both were green before this change. Question 1 has the fix.
- **Checks:** `tools/check.sh format analyze host phone` → PASS format, PASS analyze, **FAIL host** (those two
  tests, plus one unrelated flake that passes alone: `live_stats_share_test` "a phone that said no..."), PASS
  phone (545 pass / 2 skip).

## What changed

- `controller_app/lib/src/host/host_frame_gate.dart` (61 → 72 lines): the `MediaQuery`'s child is now `ProviderScope(overrides:
  [party.hostBarHeightProvider.overrideWithValue(0)], child: party.HostFrame(child: child))`. The doc comment says
  why: the strip above the frame is the bar's room, so a screen still on `HostScreen` must not keep the bar's 52
  frame px again in the frame. The nested scope shares every other provider with the app's root scope; only this
  one value differs for the frame's subtree.
- `controller_app/test/host_bar_zero_in_frame_test.dart` (new, 62 lines): the two tests above. The first asserts
  `hostTitleBar`'s top = 52 at 852x393; the second reads the provider from the `ShapeRaceScreen`, the (offstage)
  `GamesScreen` and the `ControllerScreen`.
- `controller_app/test/host_title_bar_test.dart`: `expectRoomBelowTheBar` now expects the title bar at
  `topBarHeightPx` (it was `topBarHeightPx * (1 + scale)`, i.e. the bar added twice); the now-unused
  `frameScaleOf` went; the level list's scroll height is `540 - kToolbarHeight` = **484** frame px (was 432); the
  old menu's padding is `EdgeInsets.all(hostMenuPaddingPx)` = **24** all round (was 24, 12, 24, 24), and that
  test's name says so.
- `controller_app/test/host_mode_test.dart`: the solo-host test's join-screen hint is found with
  `find.textContaining` instead of an exact `find.text`. Inside the frame the join screen sees no bar, so it takes
  the roomy (TV) layout and keeps the keyboard hint beside the side hint; its plain text is no longer the hint
  alone. Same intent: the screen names the own player's tap to pick a side.
- `packages/party_host/lib/src/ui/night_start_screen.dart` (277 → 254 lines): `_StartBody` (LayoutBuilder +
  SingleChildScrollView + ConstrainedBox + IntrinsicHeight) is deleted; the screen's body is `_StartColumn`
  itself, whose doc comment now says the column never scrolls (DESIGN section 1, rule 6) and names the measured
  286 px against the 392 px shortest body.
- `packages/party_host/test/night_start_noscroll_test.dart` (new, 131 lines): the 20 tests (5 sizes x 2 rosters x
  fresh/running), at the same five sizes and seeds as `night_start_frame_test.dart`.
- `packages/party_host/test/night_start_frame_test.dart`: the "fits its body" test asserts the body holds no
  `Scrollable` (was: one, with `maxScrollExtent` 0); the rest of that test is unchanged.

## Computed values

| device | frame | body (frame px) | card (frame px) | spare |
| --- | --- | --- | --- | --- |
| 640x360 | 960x540 | 392 | 286 | 106 |
| 852x393 | 1170.687x540 | 392 | 286 | 106 |
| 1024x768 | 960x720 | 572 | 286 | 286 |
| 1280x800 | 960x600 | 452 | 286 | 166 |
| 1920x1080 | 960x540 | 392 | 286 | 106 |

- **286.0** = the awards title's top to the players' line bottom (254) + the pick-round line's own 32 px: title
  30 + space 12 + awards row 84 (awardTileHeightPx) + space 16 + cat line 48 (awardTileDiscPx) + space 16 +
  players line 48 + pick line 32. It is the same with 4 and with 6 players (the players line is one row), and
  the same with a running night (the night's own awards fill the same 84 px row). Measured with the look's real
  fonts (`loadLookFonts`), read off the widget rects in the new test, then the temporary print removed.
- **245 / 41** = the unframed 852x393 body (393 - 64 - 84) and what the card exceeds it by at the two arena
  tests (286 - 245).
- **84.84** = 52 + 52 x 0.6314814814814815, the old doubled bar at 852x393; now **52**.
- **484** = 540 - kToolbarHeight (the level list's list height now); menu top padding 24, not 12.
- New controller test values: title bar top **52.0** (closeTo, 1e-6); provider **0.0** inside, **52.0** outside
  (topBarHeightPx = barTopPaddingPx + barRowHeightPx).

## Decisions and deviations

1. **The nested scope sits around `HostFrame`, inside the gate's `MediaQuery`.** Either side of `HostFrame` gives
   its screens the same 0 (the frame does not read the provider); inside keeps the frame's whole subtree in one
   scope, which is what the brief describes ("gives its child a nested ProviderScope").
2. **The join screen now lays out as the TV's does inside the frame.** Zeroing the provider flips
   `join_screen.dart`'s `tight` flag off (it was on for the phone's bar), so the frame's join screen gets the
   roomier gaps and keeps the keyboard hint. It fits: the frame is 540 px high, the join screen's title bar is
   kToolbarHeight, so its body is 484 frame px, as on a TV. This is a visible change on the phone host and worth
   a look (Question 3).
3. **The two stale arena tests were left failing, not worked around.** A guard such as "keep the scroll when no
   `HostFrameInfo` is above" would pass them and is exactly the special case the brief and the guidelines rule
   out; they are outside `allow:` and get Question 1 instead.

## Self-check (review-rules.md part A, items 1-5)

1. **Every host setup** — TV/PC host: untouched (`party_host` paints the same screens; the gate is the phone
   app's alone), and the night start at 1920x1080 is in the new test. "Play on this phone":
   `host_mode_test`'s solo-host test (pad in device px, game in the frame) passes with the new hint finder;
   "Show on this device": `host_title_bar_test` "'Show on this device' loses the picker's back arrow too" (the
   gate wraps both host modes). A joined phone: `host_frame_wiring_test` "a joined phone is not in the frame".
   One build older: no protocol message, route or key changed; the provider is app-side.
2. **When kept state starts and ends** — the gate's `ProviderScope` holds a child container for the host
   subtree: it starts with the gate's element and is disposed with the route (the element owns it); it holds no
   timer, listener or cache of its own, and every other provider is the app root's instance. `host_mode_test`'s
   solo round mounts and disposes a host through it with no pending timer.
3. **How a new state combines** — nothing is added that pauses, hides, waits or blocks input: the gate changes
   one read value for its subtree. A full solo round still runs through the frame (`host_mode_test`), and the
   night's Ready flow is green at 960x540 (`arena_night_test`).
4. **Stay in the job's folder** — seven files: the two new tests, three rewritten tests, two lib files, all in
   `allow:`. The phone suite rewrote the six `site/shots/*.png` again (wph's Q3): I cannot restore them without a
   git command; the runner should discard them.
5. **Stop rather than overstep** — the two arena tests (outside `allow:`) are reported in Question 1 rather than
   edited, and no guard was added to make them pass.

## Hand-over

- Where the numbers are: the new no-scroll test's doc comments and this report's table (286 px); the gate's doc
  comment (52 / 84.84 / why); `host_bar_zero_in_frame_test.dart` (the two provider readings).
- The old code fails both new files for their stated reason: `host_bar_zero_in_frame_test` on the bar at 84.84
  and the provider at 52 inside, `night_start_noscroll_test` on `Scrollable` found (20 of 20).
- `night_screens_test.dart` (in `allow:`) needed no change: its night start tests pump at 960x540, where the card
  fits, and they are green.
- Open: the two arena touch tests (Question 1); `site/shots` (Question 2); the join screen's roomy layout
  (Question 3); the `live_stats_share_test` flake (Question 4).

## Questions

1. **The two unframed arena tests need a fix job that may touch them.** `arena_touch_solo_night_test` and
   `arena_touch_ready_test` pump `StubHome` at 852x393 with no frame, tap through the night start, and now
   overflow by 41 px there. The fix is the tests' own: pump them in `hostFrameBuilder` (as
   `night_start_frame_test` does) or at 960x540, where the body is 392 px. Should they be framed, and does that
   go in the same brief as `arena_touch_ready_test`'s other night case?
2. **The six `site/shots/*.png`** were rewritten by the phone suite (`site_shots.dart`), as in wph; they are
   outside `allow:` and cannot be restored without a git command. The runner should discard them.
3. **The join screen inside the frame** is now the TV's roomy layout (no `tight`), because the bar's provider is 0.
   Is that the intent of decision (e)? It fits with room to spare (484 frame px of body against the TV's layout),
   but it does change the phone host's join screen visibly.
4. **`live_stats_share_test` "a phone that said no is left out of the upload..."** failed once in the full `host`
   run with the two phone records in the other order (`['phone-no','phone-yes']` vs
   `['phone-yes','phone-no']`) and passes alone. It looks like an order/timing flake in that test, untouched here;
   worth a look in a later job.

## Commit message

Drop the night start's scroll net; zero the bar inside the frame

- The night start's body is its column alone: no SingleChildScrollView (286 frame px of content in 392, 452 and
  572 px bodies at the five sizes), so no host screen scrolls (DESIGN section 1, rule 6).
- HostFrameGate gives the frame a nested ProviderScope with hostBarHeightProvider = 0: the strip above the frame
  is the bar's room, so the old HostScreen screens keep no second inset (level list title bar back to 52 at
  852x393, was 84.84; its menu padding 24 all round, its list 484 frame px).
- New night_start_noscroll_test (20: five sizes, 4 and 6 players, fresh and running night; no Scrollable, every
  line inside the body) and host_bar_zero_in_frame_test (2); both fail on the old code.
- night_start_frame_test asserts no scrollable; three controller tests that pinned the doubled bar rewritten.
- Open: two arena touch tests draw the start unframed at 852x393 and overflow 41 px (need their own job).

## Status row

fstart done: the night start draws no scrollable (20 new tests at five sizes, 4/6 players, fresh/running; 286 px of content in a 392 px body) and the phone frame zeroes hostBarHeightProvider (level list back at 52, 2 new controller tests); open: two arena touch tests still draw the start unframed at 852x393 and overflow 41 px, the join screen now takes the roomy layout inside the frame, and the six site/shots PNGs need discarding.

## Delete

- none
