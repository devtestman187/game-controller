import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/ui/diagnostics_screen.dart';
import 'package:controller/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/joined.dart';
import 'support/pump_app.dart';

/// The two palettes the phone can be set to.
const _palettes = ['sunny', 'night'];

/// The smallest touch target the bar's buttons keep, in dp.
const _minTargetDp = 48.0;

Future<void> _pump(WidgetTester tester, {required bool tv, required String palette}) async {
  await pumpApp(
    tester,
    paired: true,
    saved: {'look.choice': palette},
    extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
  );
}

void main() {
  setUpAll(loadPuzzles);

  for (final tv in [false, true]) {
    for (final palette in _palettes) {
      final look = '${tv ? 'TV' : 'menu'} look, $palette';

      testWidgets('the bar has one More button of at least 48x48 dp in the $look', (tester) async {
        await _pump(tester, tv: tv, palette: palette);
        final more = find.byKey(const Key('moreMenu'));
        expect(more, findsOneWidget);
        expect(find.byTooltip('More'), findsOneWidget);
        final size = tester.getSize(more);
        expect(size.width, greaterThanOrEqualTo(_minTargetDp), reason: 'width $size');
        expect(size.height, greaterThanOrEqualTo(_minTargetDp), reason: 'height $size');
        expect(find.byTooltip('Settings'), findsNothing, reason: 'Settings is in the menu, not in the bar');
        expect(find.byTooltip('Diagnostics'), findsNothing, reason: 'Diagnostics is in the menu, not in the bar');
      });

      testWidgets('More lists Settings above Diagnostics in the $look', (tester) async {
        await _pump(tester, tv: tv, palette: palette);
        await tester.tap(find.byKey(const Key('moreMenu')));
        await settle(tester);
        final settings = find.byKey(const Key('moreSettings'));
        final diagnostics = find.byKey(const Key('moreDiagnostics'));
        expect(settings, findsOneWidget);
        expect(diagnostics, findsOneWidget);
        expect(tester.getTopLeft(settings).dy, lessThan(tester.getTopLeft(diagnostics).dy));
      });

      testWidgets('More opens Settings in the $look', (tester) async {
        await _pump(tester, tv: tv, palette: palette);
        await tester.tap(find.byKey(const Key('moreMenu')));
        await settle(tester);
        await tester.tap(find.byKey(const Key('moreSettings')));
        await settle(tester);
        await settle(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
      });

      testWidgets('More opens Diagnostics in the $look', (tester) async {
        await _pump(tester, tv: tv, palette: palette);
        await tester.tap(find.byKey(const Key('moreMenu')));
        await settle(tester);
        await tester.tap(find.byKey(const Key('moreDiagnostics')));
        await settle(tester);
        await settle(tester);
        expect(find.byType(DiagnosticsScreen), findsOneWidget);
      });
    }
  }

  testWidgets('the compact bar over a game has the same More button', (tester) async {
    final app = await pumpApp(tester, paired: true);
    app.client.emit(connected);
    await settle(tester);
    app.client.nowMs = 1000;
    app.client.viewStart(arenaStart());
    await settle(tester);
    app.client.viewFrame(arenaFrame(0));
    await settle(tester);
    expect(find.byKey(const Key('moreMenu')), findsOneWidget);
    expect(find.byTooltip('Diagnostics'), findsNothing);
    await openDiagnostics(tester);
    expect(find.byType(DiagnosticsScreen), findsOneWidget);
  });

  testWidgets('"Show on this device" has no More menu and keeps the plain Diagnostics button', (tester) async {
    await pumpHostApp(tester);
    final host = await enterHostMode(tester, choice: HostChoice.onDevice);
    expect(find.byKey(const Key('moreMenu')), findsNothing);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(find.byTooltip('Diagnostics'), findsOneWidget);
    await tester.runAsync(host.dispose);
  });
}
