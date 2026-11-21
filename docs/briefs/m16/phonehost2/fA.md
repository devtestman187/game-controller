job: M16 phonehost2 fA — the score card takes the stage width; final scores drawn at all five sizes; the +n style asserted (REVIEW.md: 1 must, 2 coulds)
stop: after fA. Do not edit score_row.dart (the Arena job owns it in this wave), host_frame_screen.dart or night_widgets.dart.
read: docs/briefs/m16/phonehost2/REVIEW.md (findings "must ... night_scoreboard_widgets.dart:66", the two night_scoreboard_frame_test.dart coulds at :377 and :186; verified real by Claude: Align gives the card a loose width, so ToyCard's IntrinsicWidth sizes it to a row, about 380-430 of the 912 px stage) · packages/party_host/lib/src/ui/night_scoreboard_widgets.dart · packages/party_host/lib/src/ui/night_reveal_widgets.dart (how the reveal gives its card the body's width with LayoutBuilder + SizedBox) · packages/party_host/test/night_scoreboard_frame_test.dart (harness to copy) · docs/briefs/m16/phonehost2/COMMON.md
decisions: DESIGN section 1 rule 4 "Cards fill the stage width"; the stage is the frame width minus 2 x hostFrameGutterPx.

do:
1 Tests first, NEW file packages/party_host/test/night_scoreboard_card_test.dart (fail on old code): at the five sizes, 4 and 6 players, between rounds AND on the final scores: the card (key nightScoreboard) width equals the frame width minus 2 x hostFrameGutterPx (use the real frame width: 960, 1170.687 at 852x393); a score row's bar is wider than 300 frame px at 960 wide; the final scores' winner row is taller than the others and the one-button footer is on screen at each size (the old loop only drew it at 640x360); the "+n" text of a row has fontSize 20 (ToyType.frameSmall).
2 Fix: give the card the body's width in night_scoreboard_widgets.dart (LayoutBuilder + SizedBox(width: constraints.maxWidth), as the reveal does), keep the top alignment and the confetti. No other change.
3 Report: card widths measured per size.
in the report: `## Summary` (at most 30 lines), end `## Hand-over`.
self-check: docs/review-rules.md part A, items 1-5, one line each with the test that shows it.
tests: tests-first: new file above. Await async effects.
rules: aim 40-80 turns · no lib file you touch ends over 380 lines · tests first · write only inside allow: · stage nothing · no git add -A · tools/review.sh: no FAIL on your lines · leave docs/design/, site/shots/ and tv_test_app/windows/flutter/ alone.
allow: packages/party_host/lib/src/ui/night_scoreboard_widgets.dart · packages/party_host/test/night_scoreboard_card_test.dart · packages/party_host/test/night_scoreboard_frame_test.dart · docs/briefs/m16/phonehost2/fA-report.md
check: format analyze host
report: docs/briefs/m16/phonehost2/fA-report.md
