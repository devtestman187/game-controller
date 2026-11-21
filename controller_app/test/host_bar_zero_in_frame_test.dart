import 'package:controller/src/ui/controller_screen.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';

void main() {
  setUpAll(loadPuzzles);

  testWidgets('the level list\'s title bar starts at the frame\'s top, under the phone\'s bar', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await settle(tester);

    // The frame starts at the bar (M16 phonehost2 wph), and the level list is
    // still on the old `HostScreen`: its title bar would keep the bar's 52
    // frame px again, drawn on top of the bar's own 52 device px, putting the
    // bar at 84.84 device px at 852x393 (wph question 2). The gate zeroes the
    // provider inside the frame, so the bar stays at the frame's top: 52.
    final bar = tester.getRect(
      find.descendant(of: find.byType(party.ShapeRaceScreen), matching: find.byKey(const Key('hostTitleBar'))),
    );
    expect(
      bar.top,
      closeTo(topBarHeightPx, 1e-6),
      reason: 'the title bar starts at the frame\'s top (52), not at 84.84 where the bar was added twice',
    );

    await tester.runAsync(host.dispose);
  });

  testWidgets('the bar\'s height reads 0 inside the frame and 52 outside it', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester);
    await tester.tap(find.byKey(const Key('pickShapeRace')));
    await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
    await settle(tester);

    final inside = ProviderScope.containerOf(tester.element(find.byType(party.ShapeRaceScreen)));
    expect(
      inside.read(party.hostBarHeightProvider),
      0,
      reason: 'the gate\'s strip is the bar\'s room inside the frame',
    );
    final picker = ProviderScope.containerOf(tester.element(find.byType(party.GamesScreen, skipOffstage: false)));
    expect(picker.read(party.hostBarHeightProvider), 0, reason: 'every host screen in the frame reads no bar');
    final outside = ProviderScope.containerOf(tester.element(find.byType(ControllerScreen).first));
    expect(
      outside.read(party.hostBarHeightProvider),
      topBarHeightPx,
      reason: 'the bar over the frame is still this phone\'s own height',
    );

    await tester.runAsync(host.dispose);
  });
}
