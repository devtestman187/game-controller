import 'package:controller/src/ui/diagnostics_screen.dart';
import 'package:controller/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';
import 'support/test_font.dart';

/// The screens the phone draws, at the sizes it is held in: the smallest
/// landscape phone (iPhone SE), the usual one, and a tablet.
const sizes = [Size(667, 375), Size(852, 393), Size(1180, 820)];

/// The two palettes the phone can be set to.
const palettes = ['sunny', 'night'];

/// Runs [body] at every size in both palettes, expecting what it drew to fit:
/// nothing on the phone may overflow its box or throw as it lays out.
Future<void> eachLook(WidgetTester tester, String screen, Future<void> Function(Size size, String palette) body) async {
  for (final size in sizes) {
    for (final palette in palettes) {
      // The last look's routes would stay on top of this one's: an empty tree
      // drops them.
      await tester.pumpWidget(const SizedBox.shrink());
      await body(size, palette);
      expect(tester.takeException(), isNull, reason: 'the $screen at $size in $palette');
    }
  }
}

/// The app with [palette] chosen, at [size].
Future<TestApp> pump(WidgetTester tester, Size size, String palette, {bool paired = false}) =>
    pumpApp(tester, paired: paired, screen: size, saved: {'look.choice': palette});

/// The app playing the Arena, as [joined] has it, in [palette]: a game behind
/// the bars and the cards over it.
Future<TestApp> playing(WidgetTester tester, Size size, String palette) async {
  final app = await pump(tester, size, palette, paired: true);
  app.client.emit(connected);
  app.client.setStatus(StatusMessage(text: 'Left 3/6'));
  await settle(tester);
  app.client.nowMs = 1000;
  app.client.viewStart(arenaStart());
  await settle(tester);
  app.client.viewFrame(arenaFrame(0));
  await settle(tester);
  return app;
}

void main() {
  // The screens are measured with a real font, as a device draws them (see
  // test_font.dart): without it every line is as wide as its letters and the
  // fit comes out too tight.
  setUpAll(loadHostFonts);

  testWidgets('the Connect screen fits', (tester) async {
    await eachLook(tester, 'Connect screen', (size, palette) async {
      await pump(tester, size, palette);
      expect(find.text('Connect to a TV'), findsOneWidget);
    });
  });

  testWidgets('the Settings screen fits', (tester) async {
    await eachLook(tester, 'Settings screen', (size, palette) async {
      await pump(tester, size, palette, paired: true);
      await openSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  testWidgets('the Diagnostics screen fits', (tester) async {
    await eachLook(tester, 'Diagnostics screen', (size, palette) async {
      await pump(tester, size, palette, paired: true);
      await tester.tap(find.byTooltip('Diagnostics'));
      await settle(tester);
      expect(find.byType(DiagnosticsScreen), findsOneWidget);
    });
  });

  testWidgets('the bar and its status panel fit', (tester) async {
    await eachLook(tester, 'bar with its status panel', (size, palette) async {
      final app = await pump(tester, size, palette, paired: true);
      app.client.emit(connected);
      app.client.setStatus(StatusMessage(text: 'Left 3/6'));
      await settle(tester);
      expect(find.byKey(const Key('statusPanel')), findsOneWidget);
    });
  });

  testWidgets('the waiting card fits', (tester) async {
    await eachLook(tester, 'waiting card', (size, palette) async {
      final app = await playing(tester, size, palette);
      app.client.hostAway(30);
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsOneWidget);
    });
  });

  testWidgets('the abandoned card fits', (tester) async {
    await eachLook(tester, 'abandoned card', (size, palette) async {
      final app = await playing(tester, size, palette);
      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.abandoned));
      await settle(tester);
      expect(find.byKey(const Key('abandonedNotice')), findsOneWidget);
    });
  });

  testWidgets('the rating card fits, on both its steps', (tester) async {
    await eachLook(tester, 'rating card', (size, palette) async {
      final app = await pump(tester, size, palette, paired: true);
      app.client.emit(connected);
      await tester.pump();
      app.client.ask(const RatingAskMessage(id: 'r1', game: 'arena'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('rate-bad')));
      await tester.pump();
      expect(find.byKey(const Key('rate-send')), findsOneWidget);
    });
  });

  testWidgets('the host start sheet fits', (tester) async {
    await eachLook(tester, 'host start sheet', (size, palette) async {
      await pump(tester, size, palette);
      await tester.tap(find.byKey(const Key('hostGame')));
      await settle(tester);
      expect(find.byKey(const Key('hostStartSheet')), findsOneWidget);
    });
  });
}
