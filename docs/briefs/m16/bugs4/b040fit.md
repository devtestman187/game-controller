job: M16 bugs4 b040fit — the joined phone's result card scales down to fit a small landscape phone
stop: after it. No new text, no night-winner line (job b040win does that), no protocol or host change.
read: docs/briefs/templates/COMMON.md · controller_app/lib/src/ui/result_card.dart:19-70 · controller_app/test/m14_phone_test.dart:98-135 · controller_app/test/phone_fit_test.dart:1-45 (pumpApp screen: size, saved: {'look.choice': palette} for 'sunny' and 'night') · owner B-040 (Nov 23): "Phone did not see waiting for the host message". Measured: at 568x320 a card with 6 standing rows puts the 'Waiting for the host' line at y 341 (off screen, 58 px overflow); 4 rows overflow by 2 px, and a Shape Race picture adds more.
changes: ResultCard.build (card scales down uniformly when taller or wider than the room) · key 'resultCard' (new, on the ToyCard)
turns: 50
expected-min: 25
do:
1 Tests first: new controller_app/test/result_card_fit_test.dart. Copy the setup of m14_phone_test 'a result end keeps the last frame...' (pumpApp paired, connected, arenaStart via support/joined.dart, viewEnd with a ViewResult carrying 6 standings, points, round 1 of 3, coins count) and setUpAll(loadHostFonts) as phone_fit_test does. For sizes 568x320, 667x375, 852x393 and palettes sunny and night: assert tester.takeException() is null, and the rect of Key('resultWaiting') lies inside the screen (top >= 0, bottom <= height) and Key('resultCard') rect inside the screen. Run it, see it fail at 568x320, then change lib.
2 result_card.dart ResultCard.build: keep the 420 px card width, but let the card shrink as a whole when the room is smaller: wrap the ToyCard in a FittedBox(fit: BoxFit.scaleDown) over a SizedBox(width: the smaller of _cardWidth and the room's width), with 8 px of clear room round it (ToySizes.space8), inside a LayoutBuilder or the existing Center. Give the ToyCard Key('resultCard'). The text must stay the same size when the room is big enough: at 852x393 with 2 rows scale is 1.
3 Run the new test, controller_app/test/m14_phone_test.dart and result_photo_test.dart; fix only pinned positions in allowed files.
allow: controller_app/lib/src/ui/result_card.dart · controller_app/test/result_card_fit_test.dart · controller_app/test/m14_phone_test.dart · controller_app/test/result_photo_test.dart · docs/briefs/m16/bugs4/b040fit-report.md
check: format analyze phone
report: docs/briefs/m16/bugs4/b040fit-report.md
