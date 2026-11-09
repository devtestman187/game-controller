import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';
import 'package:tvtest/src/ui/shader_spike_screen.dart';
import 'package:tvtest/src/ui/toy_gallery.dart';

import 'support/pump_app.dart';

/// Mounts the gallery by itself, in a TV screen's box.
Future<void> _pumpGallery(WidgetTester tester) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const ToyStillSky(
      child: MaterialApp(home: Scaffold(body: ToyGallery())),
    ),
  );
  await tester.pumpAndSettle();
}

/// The look the gallery builds for itself.
ToyLook _galleryLook(WidgetTester tester) =>
    tester.widget<ToyLookScope>(find.descendant(of: find.byType(ToyGallery), matching: find.byType(ToyLookScope))).look;

/// How far one scroll in these tests moves the gallery, in logical pixels:
/// enough to bring the badges into view and no more.
const _scrollStep = 120.0;

/// The four widgets are all in the gallery, and nothing overflowed.
///
/// The gallery is taller than a TV's section, so the badges are checked after
/// a scroll down, and the list is put back at the top for the next check.
Future<void> _expectGalleryContents(WidgetTester tester) async {
  final list = find.byType(Scrollable);
  expect(find.byType(ToyBackground), findsOneWidget);
  expect(find.byType(ToyButton), findsNWidgets(4));
  expect(find.byType(ToyCard), findsOneWidget);
  await tester.scrollUntilVisible(find.byKey(const Key('galleryBadges')), _scrollStep, scrollable: list);
  expect(find.byType(ToyBadge), findsNWidgets(6));
  expect(tester.takeException(), isNull);
  await tester.scrollUntilVisible(find.byKey(const Key('galleryPalette')), -_scrollStep, scrollable: list);
}

void main() {
  testWidgets('the gallery shows the four widgets in Sunny and in Night without an overflow', (tester) async {
    await _pumpGallery(tester);
    expect(_galleryLook(tester).palette, ToyPalette.sunny);
    await _expectGalleryContents(tester);
    await tester.tap(find.byKey(const Key('galleryPalette')));
    await tester.pumpAndSettle();
    expect(_galleryLook(tester).palette, ToyPalette.night);
    await _expectGalleryContents(tester);
  });

  testWidgets('the switch changes the background the gallery paints', (tester) async {
    await _pumpGallery(tester);
    expect(_galleryLook(tester).colors.background, ToyColors.sunny.background);
    await tester.tap(find.byKey(const Key('galleryPalette')));
    await tester.pumpAndSettle();
    expect(_galleryLook(tester).colors.background, ToyColors.night.background);
  });

  testWidgets('the Look test screen keeps its shader rows and has the gallery beside them', (tester) async {
    await pumpApp(tester);
    await tapVisible(tester, find.text('Look test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ShaderSpikeScreen), findsOneWidget);
    expect(find.byKey(const Key('lookRowShader')), findsOneWidget);
    await tester.tap(find.text('Widgets'));
    // Not pumpAndSettle: the shader rows turn for as long as the screen is
    // open, so a frame is always scheduled.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ToyGallery), findsOneWidget);
    expect(find.byType(ToyButton), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
