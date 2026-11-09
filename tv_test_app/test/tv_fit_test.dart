import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:tvtest/src/tv_text.dart';
import 'package:tvtest/src/ui/haptic_panel_screen.dart';
import 'package:tvtest/src/ui/home/controllers_panel.dart';
import 'package:tvtest/src/ui/home/home_screen.dart';
import 'package:tvtest/src/ui/home/log_panel.dart';
import 'package:tvtest/src/ui/home/pairing_panel.dart';
import 'package:tvtest/src/ui/latency_screen.dart';
import 'package:tvtest/src/ui/shader_spike_screen.dart';

import 'support/pump_app.dart';

/// The TV's screen: 960 x 540 at 1:1, which is how the TV app measures.
const tvSize = Size(960, 540);

/// Noon and late evening, so Auto's palette picks Sunny and Night.
DateTime noon() => DateTime(2026, 5, 1, 12);
DateTime evening() => DateTime(2026, 5, 1, 22);

/// The two controllers the sample host has: a connected iPhone and a Pixel
/// still pairing.
const sampleNames = ['iPhone 3F1C', 'Pixel'];

void main() {
  for (final (palette, clock) in [('Sunny', noon), ('Night', evening)]) {
    testWidgets('the home fits a 960 x 540 TV in $palette', (tester) async {
      await pumpApp(tester, clock: clock);
      expect(tester.takeException(), isNull, reason: 'nothing overflows at the TV size');

      // The title says what it needs: at 960 wide it is whole, never cut.
      final title = tester.renderObject<RenderParagraph>(find.text(TvText.name));
      final words = TextPainter(text: title.text, textDirection: TextDirection.ltr, maxLines: 1)..layout();
      expect(words.width, lessThanOrEqualTo(title.size.width + 0.5), reason: 'the title fits its box');

      // Both controllers' tiles are whole: their names are not cut, and they
      // sit inside the controllers panel.
      final panel = find.byType(ControllersPanel);
      expect(panel, findsOneWidget);
      final panelRect = tester.getRect(panel);
      for (final name in sampleNames) {
        final tile = find.descendant(of: panel, matching: find.text(name));
        expect(tile, findsOneWidget, reason: '$name has a tile');
        expect(tester.renderObject<RenderParagraph>(tile).didExceedMaxLines, isFalse, reason: '$name is not cut');
        final rect = tester.getRect(tile);
        expect(
          rect.top >= panelRect.top && rect.bottom <= panelRect.bottom,
          isTrue,
          reason: '$name sits inside the controllers panel (tile $rect, panel $panelRect)',
        );
      }

      // Each ping figure is one line: "max 140 ms" broke after "140" in a
      // fixed 126 px column at the TV's type (Claude's 3d review).
      for (final figure in ['12 ms', 'avg 20 ms', 'max 140 ms', 'input ~9 ms']) {
        final line = tester.renderObject<RenderParagraph>(find.descendant(of: panel, matching: find.text(figure)));
        final oneLine = TextPainter(text: line.text, textDirection: TextDirection.ltr, maxLines: 1)..layout();
        expect(line.size.height, lessThanOrEqualTo(oneLine.height + 0.5), reason: '"$figure" is one line');
      }

      // The header keeps to two button rows, in their own order.
      final buttons = find.descendant(of: find.byType(Header), matching: find.byType(HostButton));
      final tops = <double>{
        for (var i = 0; i < buttons.evaluate().length; i++) tester.getTopLeft(buttons.at(i)).dy.roundToDouble(),
      };
      expect(tops.length, lessThanOrEqualTo(2), reason: 'the header\'s buttons take at most two rows');

      // The version and the protocol are still on the screen, in the pairing
      // panel, under the code.
      final version = find.descendant(of: find.byType(PairingPanel), matching: find.textContaining('Version 0.'));
      expect(version, findsOneWidget);
    });
  }

  testWidgets('the home fits a 1280 x 720 TV, with its tiles in view', (tester) async {
    // A 720p box, the other size a TV reports (M13 9 review): the header keeps
    // to two rows, the title is whole and both controllers are in view without
    // scrolling.
    const screen = Size(1280, 720);
    await pumpApp(tester, size: screen);
    expect(tester.takeException(), isNull, reason: 'nothing overflows at 720p');

    final title = tester.renderObject<RenderParagraph>(find.text(TvText.name));
    final words = TextPainter(text: title.text, textDirection: TextDirection.ltr, maxLines: 1)..layout();
    expect(words.width, lessThanOrEqualTo(title.size.width + 0.5), reason: 'the title fits its box');

    final view = Offset.zero & screen;
    for (final name in sampleNames) {
      final tile = find.text(name).hitTestable();
      expect(tile, findsOneWidget, reason: '$name is in view, not scrolled to');
      final rect = tester.getRect(tile);
      expect(view.contains(rect.topLeft) && view.contains(rect.bottomRight), isTrue, reason: '$name is on the screen');
    }

    final buttons = find.descendant(of: find.byType(Header), matching: find.byType(HostButton));
    final tops = <double>{
      for (var i = 0; i < buttons.evaluate().length; i++) tester.getTopLeft(buttons.at(i)).dy.roundToDouble(),
    };
    expect(tops.length, lessThanOrEqualTo(2), reason: 'the header\'s buttons take at most two rows');
  });

  testWidgets('the narrow home scrolls and fits at 700 x 500', (tester) async {
    await pumpApp(tester, size: const Size(700, 500));
    expect(tester.takeException(), isNull);
    // It stacks: the header, the pairing panel, then the rest below.
    final home = find.byType(Scrollable).first;
    expect(tester.getTopLeft(find.byType(PairingPanel)).dy, greaterThan(tester.getTopLeft(find.byType(Header)).dy));
    // The title is whole here too.
    final title = tester.renderObject<RenderParagraph>(find.text(TvText.name));
    final words = TextPainter(text: title.text, textDirection: TextDirection.ltr, maxLines: 1)..layout();
    expect(words.width, lessThanOrEqualTo(title.size.width + 0.5));
    // The pieces below are reached by scrolling, and fit when they are.
    await tester.dragUntilVisible(find.byType(ControllersPanel), home, const Offset(0, -200));
    expect(tester.takeException(), isNull);
    await tester.dragUntilVisible(find.byType(LogPanel), home, const Offset(0, -200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the haptic test fits a 960 x 540 TV', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, find.text(TvText.hapticTest));
    await tester.pumpAndSettle();
    expect(find.byType(HapticPanelScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the latency screen fits a 960 x 540 TV', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, find.text(TvText.latency));
    await tester.pumpAndSettle();
    expect(find.byType(LatencyScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Look test fits a 960 x 540 TV', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, find.text(TvText.lookTest));
    // The shapes turn every frame, so the screen never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ShaderSpikeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
