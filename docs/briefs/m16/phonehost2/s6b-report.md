# S6b — puzzle results in HostFrameScreen, badge number floor

## Summary

Stopped before the results layout; decision (c) is done.
- **Done — (c) the badge number floor.** Inside the host frame `PlayerBadge` draws a disc of at least
  `badgeNumberMinDiameterPx` = 37 px, because `ToyBadge` draws the number at 0.55 of the disc (toy_look's private
  `_numberShare`): 38 -> 20.9 px, 36 -> 19.8 px (under the floor), 28 -> 15.4 px. Outside the frame — a
  controller's pad — the badge keeps the size it asks for, so controller_app is unchanged.
- **Stopped — (a) and (b) the results in the frame.** The brief's footer (at most two buttons in the 84 px footer)
  cannot hold a series' five controls, so Shuffle, Play again and Change teams move to the body's right column —
  and that breaks `test/host_focus_ring_test.dart:221-250`, which is **not in `allow:`**. It walks the pad across
  the results: `nextPuzzle` -right-> `shuffle` -right-> `rematch` -down-> `resultsBack` -left-> `changeTeams`.
- **Measured, not guessed** (two throwaway probes, then deleted):
  - footer `[Next puzzle, Back]` + body column `[Shuffle, Play again, Change teams]`: right from Next puzzle
    lands on **Back** (then right stays, down stays, left -> Next puzzle, up -> Change teams). The walk's first
    step wants Shuffle.
  - footer `[Next puzzle]` only + body column `[Shuffle, Play again, Change teams, Back]`: right from Next puzzle
    does not move; left -> Back; up -> Change teams.
- The only layout that gives that walk is today's five-button two-row Wrap in the body (first row
  `[first, shuffle, replay]`, second `[changeTeams, resultsBack]`) — i.e. the way-on in the body, which DESIGN
  section 1 rule 5 forbids ("Way-on buttons never live in the body") and (b) forbids.
- Footer capacity: the footer is 84 px and holds one row. Inside the frame the look keeps the *device's* sizes
  (`ToyLook.withType` changes the type only), so a button is 48 px (phone look) or 64 px (TV look); two rows need
  48 + 12 + 48 = 108 or 64 + 12 + 64 = 140 px > 84.
- **Not touched**: puzzle_screen.dart, puzzle_results_widgets.dart, puzzle_screen_results.dart,
  puzzle_screen_widgets.dart, puzzle_results_test.dart, puzzle_screen_test.dart, screen_fit_test.dart — the
  in-round board and the plain card widths are as they were (d).

## What changed

- `packages/party_host/lib/src/ui/player_badge.dart`
  - `badgeNumberShare = 0.55` — how `ToyBadge` sizes the number against the disc (toy_look's private
    `_numberShare`), documented as a copy because the floor is this widget's to keep.
  - `badgeNumberFloorPx = 20.0` — DESIGN section 1, rule 3's text floor.
  - `badgeNumberMinDiameterPx = 37.0` — 20 / 0.55 = 36.36 rounded up, so the number sits over the floor.
  - `PlayerBadge.build` hands `ToyBadge` `math.max(size, 37)` when `HostFrameInfo.maybeOf(context) != null`, else
    `size`. Class and member comments say why.
- `packages/party_host/test/player_badge_test.dart`: the character test unchanged; added "outside the frame a
  pad keeps the badge size it asks for" (28 stays 28).
- `packages/party_host/test/puzzle_results_frame_test.dart` (NEW, the brief's file, badge part only): the five
  devices from `host_frame_screen_test.dart`, each with a frame badge at 38 and 28 whose number is >= 20 frame px
  and whose disc is never shrunk; and one test of the exact diameters (38 -> 38, 36 -> 37, 28 -> 37). The
  results' own five-size tests (picture left of the text, footer buttons, no scrollable) are still owed by the
  layout job.

## Computed values

- Number px = 0.55 x diameter: 38 -> 20.9 · 37 -> 20.35 · 36 -> 19.8 · 28 -> 15.4 · 33 (controller pad's
  `playerBadgeDiameter`, outside the frame) -> 18.15, unchanged.
- Floor diameter: 20 / 0.55 = 36.36 -> 37 (rounded up).
- Frames and bodies (from `host_frame_screen_test.dart`): 640x360 -> 960x540, s .667, body 392 · 852x393 ->
  1170.687x540, s .728, body 392 · 1024x768 -> 960x720, s 1.067, body 572 · 1280x800 -> 960x600, s 1.333, body
  452 · 1920x1080 -> 960x540, s 2, body 392.

## Tests rewritten / added

- `player_badge_test.dart`: one test added, none weakened. `puzzle_results_frame_test.dart`: new, 6 tests (five
  device cases + the exact diameters).
- Not rewritten because no layout changed: `puzzle_results_test.dart`, `puzzle_screen_test.dart`,
  `screen_fit_test.dart`.
- The tests the brief expects to break with (a)/(b) — `puzzle_results_test`'s first two tests and
  `host_focus_ring_test`'s results test — still pass, because (a)/(b) are not implemented.

## Questions

1. **Who owns the walk?** Either add `packages/party_host/test/host_focus_ring_test.dart` to `allow:` for S6b
   (its results walk becomes: right -> Back in the footer, up -> the body's column, left -> Change teams), or
   approve the series' five-button Wrap staying in the body (a rule 5 exception), or split the job into plain
   rounds + a night (footer fits) and the series.
2. Is the footer allowed a *single* row of two buttons only, as measured, or may a series substitute a compact
   two-row group (it does not fit 84 px with the look's 48/64 px buttons)?
3. The brief's list of tests to fix (`puzzle_results_test`, `puzzle_screen_test`, `player_badge_test`,
   `screen_fit_test`) misses `host_focus_ring_test`; should later move briefs derive that list by running the
   suite after the move instead?

## Suggestions

- Give `ToyBadge` (toy_look) a `minNumberPx` or an exported number share in a job that owns toy_look, so
  `PlayerBadge` stops copying 0.55.
- A frame results test can assert "no scrollable" only once the layout drops the current `SingleChildScrollView`
  at `puzzle_screen.dart:351-368` (the review's approved staging net); the results' body should then be a plain
  column like the night start's.

## Hand-over

- Decision (c) is in and green: `PlayerBadge` floors the disc at 37 px inside `HostFrame`, the pad keeps its
  size, and `puzzle_results_frame_test.dart` guards the floor at the five devices. The next S6b brief can add the
  results' layout tests to that same file.
- The results layout needs one `allow:` line (`test/host_focus_ring_test.dart`) or a decision that the series'
  buttons stay in the body. Everything else in the brief's map stands: `HostFrameScreen` with the winner headline
  as the title, pictures left and the sides' rows right, the plain round's `[Play again, Back]` and a night's
  `[Next, End night]` in the footer (both fit two wide), `Change teams` moving to the body's right column.

## Self-check (review-rules part A)

1. **Every host setup** — a TV or PC host, a phone host, and a joined phone: the badge only changes inside
   `HostFrame`, and only for a disc asked under 37 px (a phone look's row badge is 36 -> 37; a TV look's is 48,
   unchanged); joined phones and controller pads draw no host badge, and no message changes, so an older build is
   unaffected. Test: `puzzle_results_frame_test.dart` (five devices, 38 and 28) and `player_badge_test.dart` (the
   pad's 28 kept).
2. **When kept state starts and ends** — nothing is held, timed, counted or remembered: the diameter is computed
   from the requested size and the box it is drawn in. Test: not affected (the two badge tests).
3. **How a new state combines with the others** — no pause, hide, wait or input block is added, so no pair
   changes. Test: not affected.
4. **Stay in the job's folder** — three files touched, all in `allow:`: `lib/src/ui/player_badge.dart`,
   `test/player_badge_test.dart`, `test/puzzle_results_frame_test.dart` (plus this report).
5. **Stop rather than overstep** — (a)/(b) need `test/host_focus_ring_test.dart`, outside `allow:`; measured at
   two footer layouts above, and the brief's own four-test list does not cover it.

## Commit message

Floor a badge's number at 20 frame px inside the host frame

- PlayerBadge: inside HostFrame a disc narrower than 37 px grows to it, since ToyBadge draws the number at 0.55 of
  the disc (36 px -> 19.8 px, under DESIGN rule 3's 20 px); outside the frame a controller's pad keeps its size.
- Constants badgeNumberShare, badgeNumberFloorPx and badgeNumberMinDiameterPx (37 = 20 / 0.55 rounded up).
- Tests: a new five-device frame guard at the results' badge sizes 38 and 28, the exact 38/36/28 diameters, and
  the pad's 28 kept outside the frame.
- S6b stopped before the results layout: the brief's two-button footer moves the series' first pad steps and
  host_focus_ring_test pins that walk outside allow: (see the report).

## Status row

S6b stopped after (c): the badge number floor inside the host frame (37 px disc floor, five-device guard, pad sizes kept); open — the results in HostFrameScreen (a)/(b), blocked on host_focus_ring_test's series walk (not in allow:) and on the two-button footer's capacity.

## Delete

- none
