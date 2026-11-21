# b034 — the host frame's footer gets a full rounded outline (B-034)

## Summary

The frame's footer band (`hostFrameFooterBand`) was a paper strip closed by a
line of ink along its top only; every other card on a screen is a rounded ink
outline, so the footer read as a different kind of surface. It now uses
`Border.all` in ink at the look's `outlineWidth` and
`BorderRadius.circular(ToySizes.cardCorner)`, exactly as `AwardTile` and
`ToyCard` draw their cards. The band keeps `hostFrameFooterInsetPx` (8 frame
px) from the frame's sides and bottom, so every side of the outline is inside
the frame and none is cut by the screen's edge; its top stays at the footer's
top, because the body is above it there. The footer is still 84 px: the inset
comes out of the band (76 px tall), not out of the footer.

The buttons are unchanged: centred in the band, ending at the stage's edge.
The band's side padding is `hostFrameGutterPx - hostFrameFooterInsetPx` (24 - 8
= 16), so 8 + 16 = 24 frame px from the frame's edge to the buttons, as before.
The vertical padding is the outline's width (4 px, TV look), the row is centred
in what is left (76 - 8 = 68 px, a 64 px button with 2 px slack each side), so a
button has 6 frame px of band above and below it: 4 px of ink plus 2 px of slack.

New test file `host_frame_footer_outline_test.dart` (5 tests, one per frame
size: 640x360, 852x393, 1024x768, 1280x800, 1920x1080) checks the band's
decoration (ink on all four sides at the look's outline width, paper fill,
`ToySizes.cardCorner` radius), its geometry (top at the footer's top, 8 frame px
inside the footer's left, right and bottom), the footer's 84 px height, and
both buttons whole and inside the outline. On the old code it fails at the
first side check: `border.right.width` was 0 (the border had only a top) and
`borderRadius` was null.

Test counts seen: the new file 5/5 pass; the 13 footer test files together
208/208 pass. `tools/check.sh format analyze host phone`: format PASS, analyze
PASS, phone PASS; host FAILs on one unrelated test
(`live_stats_share_test.dart`: the saved players come back
`['phone-no', 'phone-yes']` where the test expects `['phone-yes', 'phone-no']`),
which passes when that file is run alone and on a second full run — a flaky
ordering in a test this diff does not touch. `tools/review.sh`: 0 fail, 0 note.

Decisions:
- Only the sides and the bottom are inset; the band's top is the footer's top.
  The brief says "inset from the frame edges", and the top of the footer is not
  a frame edge (the body is above it), so a top inset would only shrink the band.
- The side padding gives the inset back, so the buttons keep ending 24 frame px
  from the frame's edge (the stage's gutter) and the games picker's pin holds.
- `hostFrameFooterInsetPx` is a public, documented frame-geometry constant next
  to `hostFrameGutterPx` (tests read it); no other constant was needed.

## Existing tests changed (and why)

1. `packages/party_host/test/night_start_frame_test.dart`, per size (5 tests):
   "the footer is a paper band with an ink line above it" became "…in a
   rounded ink outline". It pinned `tester.getRect(band) == getRect(footer)`
   ("the band fills the footer, edge to edge"), which the job changes on
   purpose. Its intent — the band is the paper surface the buttons stand on,
   closed by ink — is kept: paper fill, ink on the top (and now the bottom) and
   the band's place inside the footer (top at the footer's top, 8 frame px in
   from its sides and bottom).
2. `packages/party_host/test/games_screen_frame_test.dart`, one test: "the
   settings button stands on the footer band under its ink line" became
   "…inside its ink outline". It computed the button's offset from a hard 84 px
   footer and a top-only line; it now computes it from the band's own height
   and the outline on both sides, which is the same intent (the button is
   centred in the band, ink above and below it). Its right-edge pin
   (`settings.right == (960 - hostFrameGutterPx) * scale`) is unchanged and
   still passes.

`night_reveal_tie_test.dart`'s band padding test needed no change: the band is
still symmetric around its buttons, and its `above >= inkWidth` check still
holds (6 >= 4).

## Computed values

- TV look: `outlineWidth` 4, `buttonHeight` 64, so band height 84 - 8 = 76,
  row 76 - 2*4 = 68, button slack (68 - 64) / 2 = 2, button top inside the band
  4 + 2 = 6 frame px (lit in the changed games picker pin).
- Band width at frame 960: 960 - 2*8 = 944; inner row 944 - 2*16 = 912; buttons
  end at 960 - 24 = 936, the stage's edge.
- Drawn at the TV (s = 2): band rect observed in a failing old pin
  `LTRB(16, 912, 1904, 1064)` = 8, 456, 952, 532 frame px — the insets, the
  footer's top and the 76 px height all as computed.
- 640x360 (s = 2/3): inset 5.333 device px each side and at the bottom, band
  50.667 device px tall.

## Not sure about

- The host suite's flake above: not caused by this diff (it is a stats test);
  left alone as the brief says.
- Whether the owner wants the band's rounded top corners to sit right under
  the body's last line or a little lower; the brief fixes only the sides and
  bottom inset, so the top is flush as the old ink line was.

## Self-check (review-rules.md part A)

1. Every host setup: one widget for TV, PC and both phone modes; the new test
   runs it at the TV, a tablet, a laptop and two phones. Test:
   `host_frame_footer_outline_test.dart` (5 sizes).
2. Kept state: none — no state, timer, flag or cache is added or moved; the
   band is pure layout. Test: same file.
3. New state combined with others: none — nothing pauses, hides, waits or
   blocks input. Test: `host_frame_screen_safe_area_test.dart` passes unchanged.
4. Stay in the folder: only `host_frame_screen.dart`, the new test, the two
   edited tests and this report were written.
5. Stop rather than overstep: nothing outside `allow:` was needed; the brief
   did not contradict the code.

## Hand-over

The footer is now a rounded card with an ink outline on all four sides at every
size, its buttons unchanged and inside it, and the footer's 84 px unchanged.
Everything in the brief's read list passes. Open: the unrelated host-suite
flakiness in `live_stats_share_test.dart` (report above), and the owner's word
on the band's flush top if they want one.

## Commit message

B-034: outline the host frame's footer on all four sides

The footer band painted a line of ink along its top only, while every other
card on a host screen is a rounded outline. It now uses Border.all in the
look's ink at ToySizes.cardCorner, like AwardTile, and stands 8 frame px
inside the frame's sides and bottom (hostFrameFooterInsetPx) so no side of
the outline is cut by the edge. The footer stays 84 px, the band gives the
inset back in its side padding, and the buttons stay centred and end at the
stage's edge. A new test pins the outline, radius and inset at the five
frame sizes; two footer pins follow the new geometry.

## Status row

Done: B-034 — the host frame's footer draws a rounded ink outline on all four sides (8 px inset, 84 px footer, buttons unchanged), pinned at five sizes. Open: owner's call on a flush top; unrelated live_stats_share_test flake in the host suite.

## Delete

- none
