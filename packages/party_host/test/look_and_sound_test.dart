import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The look's providers in the app [pumpHost] mounted.
ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LookAndSoundScreen)));

void main() {
  testWidgets('Night saves the Look setting, and the app turns Night', (tester) async {
    await pumpHost(tester, screen: const LookAndSoundScreen());
    final container = _container(tester);
    expect(container.read(lookSettingsProvider).choice, LookChoice.auto);
    // Midday, so Auto draws the Sunny palette to start with.
    expect(Theme.of(tester.element(find.byType(LookAndSoundScreen))).canvasColor, ToyColors.sunny.background);

    await tester.tap(find.text('Night'));
    await tester.pumpAndSettle();

    expect(container.read(lookSettingsProvider).choice, LookChoice.night);
    expect(container.read(lookPrefsProvider).getString('look.choice'), 'night');
    // The app's theme is made from the look, so every screen turns with it.
    expect(Theme.of(tester.element(find.byType(LookAndSoundScreen))).canvasColor, ToyColors.night.background);
    expect(find.byKey(const Key('lookChoice')), findsOneWidget);
  });

  testWidgets('Sunny saves too, and the line under the choices says what Auto does', (tester) async {
    await pumpHost(tester, screen: const LookAndSoundScreen(), clock: () => DateTime(2026, 11, 8, 20));
    final container = _container(tester);
    expect(
      Theme.of(tester.element(find.byType(LookAndSoundScreen))).canvasColor,
      ToyColors.night.background,
      reason: 'Auto at 20:00 is Night',
    );
    expect(find.text('Auto: Sunny from 7:00 to 19:00, Night otherwise'), findsOneWidget);

    await tester.tap(find.text('Sunny'));
    await tester.pumpAndSettle();
    expect(container.read(lookPrefsProvider).getString('look.choice'), 'sunny');
    expect(Theme.of(tester.element(find.byType(LookAndSoundScreen))).canvasColor, ToyColors.sunny.background);
  });

  testWidgets('the Effects switch saves, and the look drops its shaders', (tester) async {
    await pumpHost(tester, screen: const LookAndSoundScreen());
    final container = _container(tester);
    expect(container.read(toyLookProvider).effects, isTrue);
    expect(find.text(HostText.effectsLine), findsOneWidget);
    expect(find.text('Moving backgrounds, shading and bounces. Turn off on a slow device.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lookEffects')));
    await tester.pumpAndSettle();

    expect(container.read(lookPrefsProvider).getBool('look.effects'), isFalse);
    expect(container.read(toyLookProvider).effects, isFalse);
    expect(container.read(toyLookProvider).shade, isNull);
    expect(container.read(toyLookProvider).backdrop, isNull);
  });
}
