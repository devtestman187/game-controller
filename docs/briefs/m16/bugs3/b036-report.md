# B-036 report: the winner banner and the hidden round strip

## Summary

STATUS: stopped. The banner does not fit above the results card with six players and Robo in the 540-high frame. Details under Blocked.

What changed:
- `WinnerBanner` (new, `packages/party_host/lib/src/ui/winner_banner.dart`): a paper box with the ink edge, `look.type.title` in ink, one line, scaled down with `FittedBox`.
- `ArenaResults` passes `title: ''` to `HostFrameScreen` (the back arrow stays). `_ResultsBody` draws the banner in a `Column` above the card (gap `ToySizes.space12`). The banner key is `winnerBanner`; the card key `arenaResults` is unchanged.
- `ArenaView` and `ArenaBoard`: new `showHud` (default true). `ArenaBoard` wraps the `ArenaHud` in a `Visibility` with `maintainSize`, `maintainState` and `maintainAnimation`, so the field keeps its size.
- `GameField`: new `showHud` (default true), passed to `ArenaView`. `game_screen.dart` passes `showHud: _stage != _Stage.results`.
- New tests in `packages/party_host/test/winner_banner_test.dart` (2 tests).

Test counts I saw (flutter test, each file on its own):
- `winner_banner_test.dart`: +2, all pass. Before the lib change: both fail (no `winnerBanner` key; the strip still shown during results).
- Banner geometry: centre x within 1 px of `size.width / 2` at 960x540 and framed 360x640, in both looks; banner bottom <= card top; title rect inside the banner box.
- `arena_results_test.dart`, `night_screens_test.dart`: pass.
- `end_night_arena_test.dart`: +4, all pass when run alone.
- `arena_results_frame_test.dart`: FAILS. 4 tests with `[E]`: "every text on the results is at least 20 frame px", "no scroll, 52 px rows and the footer on", "the card fills the stage width, and the footer's buttons share its 480 px budget", "the winner's row is washed gold and wears the crown, and every row keeps the 52 px line". Each reports `A RenderFlex overflowed by 79 pixels on the bottom` ("nothing overflows the frame") or 19 px.
- `test_game` `arena_view_test.dart` and `arena_hud_test.dart`: +18, all pass.

Self-check (review-rules part A):
1. Host setups: a TV and a phone host are both covered by the frame test's device list (the 1920x1080 TV case and the 640x360 phone case); the banner test covers the framed 360x640 phone and the 960x540 desk. The phone "Play on this phone" and "Show on this device" paths are not run by these tests; not checked.
2. Kept state: the HUD's space is kept by `maintainSize`; no state is added. Nothing is started or ended by this change.
3. Combinations: pause menu, host away, "Get ready", dropped link and leaving are not covered by new tests; the results stage is the only one whose HUD changes.
4. Files: all inside `allow:`, except that the churn step in `tools/mine.sh` touched other files (see Hand-over).
5. Blocked item: stopped rather than editing `host_frame_screen.dart` or `score_row.dart` (not allowed).
6. Looks: the banner test runs both menu and TV looks; the frame test runs both looks at five devices. Only the banner has a fixed height from its text and the title type; no fixed pixel height was added.

## Decisions

- The banner is a plain `Container` in `WinnerBanner`, with `ToySizes.space24` / `space8` padding and `ToySizes.cardCorner` corners, both existing tokens. No crown, no new colour, no new font.
- `showHud` uses `Visibility` with all three `maintain*` flags, as the brief said. Its default is `true`, so every other caller is unchanged.
- The winner's title moved from the header into the banner; the header is `''`. `_ResultsBody` got a `title` parameter (5 parameters in all).
- The round-strip test is in the party_host results file (`winner_banner_test.dart`) and runs the menu look only, through the real round (openArena, then play to the results).
- No new test in the `test_game` files; their existing pins all pass without edits.

## Blocked

The banner does not fit above the card with six players plus Robo.

- The results body is 392 frame px in a 540-high frame (`arena_results_frame_test.dart`, its own note).
- The card holds 7 rows x 52 = 364 px, plus 16 px of card padding = 380 px. Only 12 px is left, and the banner needs about 79 px (the measured overflow of 79 px with a 12 px gap).
- Two frame-test pins fail on it: "nothing overflows the frame" for the 6-player cases (79 px), and the other frame pins that the overflow breaks.
- The job does not allow changing the frame (`host_frame_screen.dart`) or the rows (`score_row.dart`), and it does not allow editing the frame test pins, so no fix fits inside the allow list without a design decision.

I did not weaken or edit any frame test. The lib code stays as written, so the six-player results overflow by 79 px on the bottom. That is a real layout bug until the owner decides.

## Hand-over

Questions for the owner (numbered in the final message):
1. Where should the banner go when the card is full (six players + Robo)? Options:
   a. Let the card scroll under the banner when it is taller than the body (needs `scrollBody` on the card and a change to the "no scroll" frame pin). Recommended: smallest change that keeps the banner above the card.
   b. Move the banner into the header row (needs a change in `host_frame_screen.dart`, outside this job's allow list).
   c. Shrink the rows (outside the 52 px pin) so the card leaves room.
2. Shape Race's "Left wins!" stays as it is (per the brief); it is a follow-up.
3. Not verified: the phone "Play on this phone" and "Show on this device" paths; pause, host away and dropped link on the results stage.

Worktree side effect (must check): `tools/mine.sh` printed `churn: reverted 9 generated file(s)` on each run. Before the first run, `git status` showed 9 modified files that were not mine: `site/shots/dpad.png`, `join.png`, `menus.png`, `results.png`, `sticks.png`, `tilt.png`, `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h`, `generated_plugins.cmake`, and `docs/briefs/m16/bugs3/run.log`. After the runs, the first 9 are clean again, and `run.log` is still modified. I did not run any git command that changes anything, and I cannot restore those files. The owner should check whether the 8 uncommitted changes were lost.

## Commit message — a draft

Banner the Arena party-mode winner and hide the round strip on results (B-036)

Not committed: the six-player results card overflows the frame (see report, Blocked).

## Status row

B-036: banner, round-strip hide and tests written; open: the six-player card overflows by 79 px (needs an owner decision on the banner's place), and 4 frame pins fail until then.

## Delete

- none
