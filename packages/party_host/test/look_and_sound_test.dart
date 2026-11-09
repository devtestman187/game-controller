import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('the Mute, Sounds and Music rows draw in Sunny and Night', (tester) async {
    await pumpHost(tester, screen: const LookAndSoundScreen());
    for (final palette in ['Sunny', 'Night']) {
      expect(find.byKey(const Key('soundVolume')), findsOneWidget, reason: palette);
      expect(find.byKey(const Key('musicVolume')), findsOneWidget, reason: palette);
      expect(find.byKey(const Key('soundMute')), findsOneWidget, reason: palette);
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Silences the music and every sound on this device.'), findsOneWidget);
      expect(find.text('Sounds'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('Plays on the game picker and join screen.'), findsOneWidget);

      await tester.tap(find.text(palette));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the Sounds slider steps by 10 and saves, and the Music slider saves', (tester) async {
    await pumpHost(tester, screen: const LookAndSoundScreen());
    final container = _container(tester);
    expect(container.read(soundSettingsProvider).soundVolume, 80);

    // The slider takes the focus like the rows beside it, and right steps it by
    // a tenth (the remote's and the phone's way to move it).
    final slider = find.byKey(const Key('soundVolume'));
    // The slider's own focus node: a tap or a Tab would take it the same way.
    final focus = tester
        .widgetList<Focus>(find.descendant(of: slider, matching: find.byType(Focus)))
        .firstWhere((f) => f.focusNode != null);
    focus.focusNode!.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(container.read(soundSettingsProvider).soundVolume, 90);
    expect(container.read(lookPrefsProvider).getInt('sound.volume'), 90);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(container.read(soundSettingsProvider).soundVolume, 80, reason: 'left steps back by ten');

    final music = tester
        .widgetList<Focus>(find.descendant(of: find.byKey(const Key('musicVolume')), matching: find.byType(Focus)))
        .firstWhere((f) => f.focusNode != null);
    music.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(container.read(soundSettingsProvider).musicVolume, 50);
    expect(container.read(lookPrefsProvider).getInt('sound.musicVolume'), 50);
  });

  testWidgets('Mute saves', (tester) async {
    await pumpHost(tester, screen: const LookAndSoundScreen());
    final container = _container(tester);
    await tester.tap(find.byKey(const Key('soundMute')));
    await tester.pumpAndSettle();
    expect(container.read(soundSettingsProvider).muted, isTrue);
    expect(container.read(lookPrefsProvider).getBool('sound.muted'), isTrue);
  });
}
