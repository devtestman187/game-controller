import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/automation/marker_code.dart';
import 'package:party_host/src/ui/marker_strip.dart';

import 'support/host_harness.dart';

/// Mounts the app's own shell, as the TV app puts it over every route, with a
/// launch that did or did not say `THUMBPARTY_MARKER=1` (M15 fix8).
Future<void> pumpShell(WidgetTester tester, {required bool marker, bool stillSky = true}) async {
  await pumpHost(
    tester,
    screen: const AutomationShell(child: AutomationGate(child: StubHome())),
    stillSky: stillSky,
    overrides: [automationSettingsProvider.overrideWithValue(AutomationSettings(marker: marker))],
  );
}

/// Every marker row on the screen, as the painters that draw them.
Iterable<MarkerPainter> rowsOnScreen(WidgetTester tester) =>
    tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((paint) => paint.painter).whereType<MarkerPainter>();

/// The frame the row on the screen carries.
MarkerReading? frameOnScreen(WidgetTester tester) {
  final rows = rowsOnScreen(tester).toList();
  expect(rows, hasLength(1), reason: 'one row, and only with the flag on');
  return decodeMarkerCells(rows.single.cells).reading;
}

void main() {
  testWidgets('with the bench flag off no strip is drawn at all', (tester) async {
    await pumpShell(tester, marker: false);
    expect(rowsOnScreen(tester), isEmpty, reason: 'every ordinary launch draws no marker row');
  });

  testWidgets('with the flag on the row carries a frame its own checksum vouches for', (tester) async {
    await pumpShell(tester, marker: true, stillSky: false);
    final first = frameOnScreen(tester);
    expect(first, isNotNull, reason: 'the painter\'s own cells decode');
    expect(first!.pressFlip, isFalse, reason: 'no press yet');
    await tester.pump(const Duration(milliseconds: 16));
    final second = frameOnScreen(tester);
    expect(second!.counter, (first.counter + 1) % markerCounterWrap, reason: 'one counter step per frame');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a probe press flips the cell and it holds until the next press', (tester) async {
    await pumpShell(tester, marker: true, stillSky: false);
    final container = ProviderScope.containerOf(tester.element(find.byType(AutomationGate)));
    expect(frameOnScreen(tester)!.pressFlip, isFalse);
    container.read(automationProbeFlipProvider.notifier).flip();
    await tester.pump();
    expect(frameOnScreen(tester)!.pressFlip, isTrue, reason: 'the frame the press lands in');
    await tester.pump(const Duration(milliseconds: 16));
    expect(frameOnScreen(tester)!.pressFlip, isTrue, reason: 'held until the next press');
    container.read(automationProbeFlipProvider.notifier).flip();
    await tester.pump();
    expect(frameOnScreen(tester)!.pressFlip, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
