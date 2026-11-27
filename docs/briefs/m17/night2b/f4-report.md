## Summary

Job f4 (night2b setup screen): three fixes, no layout change.

- Row labels, the picker help line and the cat note now use the chips' text floor: at least 14 dp on the device, through `nightSetupAtLeastDp`. One helper, `nightSetupBodyStyle`, builds the style for all three.
- Done stays the footer's button (84 frame px, 31.5 dp at 360x640, 28 dp at 320x640). A new test pins that exemption by name.
- The Hardest test is renamed to what it checks, and now asserts: with Hardest Medium, no Block Castle variant is in the playable pool; and with Easiest set above Hardest, Hardest moves up.

Tests-first: the label-floor test was written before the lib change and failed on the base at 360x640 and 320x640, in both menu and TV looks (4 failures). After the fix, `tools/mine.sh` reports OK, 24 tests.

Computed values:
- Frame body size is 22 px (`_bodyFramePx`). At 360x640 the floor is 14 / 0.375 = 37.33 frame px. At 320x640 it is 14 / (320/960) = 42 frame px.
- Block Castle is tier hard (`packages/test_game/maps/block-castle.json`). With Hardest Medium, its Arena Race and Bumper Round variants drop out of the playable pool; Shape Race and the other maps remain, so the pool is not empty.
- Easiest Hard with Hardest Medium sets min = hard and max = hard.

Decisions:
- The label-floor check reads each text's `fontSize` and multiplies by the scale from `HostFrameInfo.maybeOf`, as the brief asks.
- The Done test asserts the on-screen height is under 48 dp (the name's claim) and that it is on screen; it loops over both phones and both looks.
- The Block Castle assert uses `testMaps()` and `launchVariants`/`variantPool` from `night_pick.dart`, which is the same library the app's provider uses in tests.

Self-check (review-rules part A):
1. Host setups: both phones and both looks run the label-floor and Done tests (`at 360x640/menu`, `at 320x640/tv`, ...). TV host and phone host are covered by the TV and menu looks. A phone on "Play on this phone", a phone on "Show on this device", a joined phone and a peer one build older are not covered by this job's tests, since they are outside the setup screen.
2. Kept state: none added. The setup screen holds no state beyond the settings provider, which is unchanged.
3. Combinations: the label floor and Done changes apply the same way with a running night (chips disabled, labels unchanged). Covered by the existing running-night test, which still passes.
4. Files: only the four files in `allow:` plus this report.
5. Nothing stopped.
6. Every look: menu and TV at both phone sizes (the label-floor and Done tests). No fixed pixel height was added.

## Hand-over

Open: the chip size test (`night_setup_screen_test.dart`, the phone loop) still divides by `phone.value.width / 960` for the chip text scale. The brief did not name it, so I left it. It should read the scale from `HostFrameInfo` too.

Question: did the brief mean the chip test too? If so it is a one-line change in the same file.

## Commit message — a draft

night setup: label text at 14 dp, clearer Hardest and Done tests

Row labels, the picker help line and the cat note now use the chips'
14 dp text floor (nightSetupBodyStyle), so they are as readable as the
chips on a phone. Done keeps the footer's button; a test pins that it
is under 48 dp and on screen at both phone sizes. The Hardest test is
renamed and asserts that Hardest Medium leaves no Block Castle in the
playable pool, and that Easiest above Hardest moves Hardest up. The
label-floor test was written first and failed on the base.

## Status row

M17 night2b f4: setup labels, help line and cat note at the 14 dp text floor; Done footer pinned by test; Hardest test renamed and asserting Block Castle and Easiest-above-Hardest. Open: chip size test still divides by 960, not HostFrameInfo.

## Delete

- none
