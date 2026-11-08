import 'package:connection/connection.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/ui/bar_connection.dart';
import 'package:controller/src/ui/connect_screen.dart';
import 'package:controller/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart'
    show HostText, PhoneText, SettingsText, ToyButton, ToyButtonPainter, ToyCard, ToyLook, ToyLookScope, ToyPalette;
import 'package:protocol/protocol.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';

/// The look the phone draws, for a test that has no widget to ask.
final sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);

/// The card behind [key], as it built.
ToyCard cardOf(WidgetTester tester, Key key) => tester.widget<ToyCard>(find.byKey(key));

/// The colour the button behind [button] paints its pill, as a test sees it: an
/// unset colour means `good`, so the widget's own field doesn't say.
Color fillOf(WidgetTester tester, Finder button) =>
    (tester
            .widgetList<CustomPaint>(find.descendant(of: button, matching: find.byType(CustomPaint)))
            .map((paint) => paint.painter)
            .whereType<ToyButtonPainter>()
            .single)
        .fill;

/// The button whose label is [label].
Finder buttonSaying(String label) => find.byWidgetPredicate((w) => w is ToyButton && w.label == label);

void main() {
  group('the Connect screen (M13 3c)', () {
    testWidgets('"Host a game" is a ToyButton in good, and Settings a paper one', (tester) async {
      await pumpApp(tester);
      final look = ToyLookScope.of(tester.element(find.byType(ConnectScreen)));
      expect(tester.widget<ToyButton>(find.byKey(const Key('hostGame'))).label, PhoneText.hostAGame);
      expect(fillOf(tester, find.byKey(const Key('hostGame'))), look.colors.good);
      expect(fillOf(tester, buttonSaying(PhoneText.settings)), look.colors.paper);
    });

    testWidgets('the address field is the theme\'s paper field with ink text, at night too', (tester) async {
      // Claude's 3c review: the field drew its own stock border, and text on
      // paper must be ink, never Night's white onBackground.
      await pumpApp(tester, saved: {'look.choice': 'night'});
      final look = ToyLookScope.of(tester.element(find.byType(ConnectScreen)));
      expect(look.palette, ToyPalette.night);
      final field = tester.widget<TextField>(find.byKey(const Key('manualAddress')));
      expect(field.style?.color, look.colors.ink);
      expect(field.decoration?.border, isNull, reason: 'the theme draws the edge');
    });

    testWidgets('each host found is a paper row with the ink edge', (tester) async {
      final app = await pumpApp(tester);
      app.discovery.emit(DiscoveryState(running: true, everFound: true, hosts: [DiscoveredHost(address: tv)]));
      await tester.pump();
      final look = ToyLookScope.of(tester.element(find.byType(ConnectScreen)));
      final row = tester.widget<DecoratedBox>(find.byKey(Key('hostRow-${tv.name}')));
      final decoration = row.decoration as ShapeDecoration;
      expect(decoration.color, look.colors.paper);
      expect((decoration.shape as RoundedRectangleBorder).side.color, look.colors.ink);
    });
  });

  group('the Settings screen (M13 3c)', () {
    testWidgets('each section is a ToyCard with its name in the header band, Look and sound first', (tester) async {
      await pumpApp(tester, paired: true);
      await openSettings(tester);
      final headers = tester.widgetList<ToyCard>(find.byType(ToyCard)).map((card) => card.header).toList();
      expect(headers, containsAll([HostText.lookAndSound, SettingsText.haptics, PhoneText.gyro, PhoneText.sticks]));
      expect(headers.first, HostText.lookAndSound, reason: 'the look comes before the controls it changes');
      final cards = find.byType(ToyCard);
      expect(
        tester.getTopLeft(cards.at(1)).dy,
        greaterThan(tester.getTopLeft(cards.at(0)).dy),
        reason: 'Haptics comes after the look',
      );
    });

    testWidgets('Defaults resets the controls and leaves the look as it was', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: {'look.choice': 'night', 'gyroSensitivity': 1.5});
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('resetSettings')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmReset')));
      await settle(tester);
      expect(
        app.prefs.getString('look.choice'),
        'night',
        reason: 'the look is a display choice, not a control setting',
      );
      expect(app.prefs.getDouble('gyroSensitivity'), 1.0, reason: 'the controls go back to the defaults');
      expect(ToyLookScope.of(tester.element(find.byType(SettingsScreen))).palette, ToyPalette.night);
    });
  });

  group('the cards over the pad (M13 3c)', () {
    testWidgets('the waiting card has a caution header', (tester) async {
      final app = await joined(tester);
      app.client.hostAway(30);
      await settle(tester);
      final look = ToyLookScope.of(tester.element(find.byKey(const Key('waitingCard'))));
      final card = cardOf(tester, const Key('waitingCard'));
      expect(card.header, PhoneText.waiting);
      expect(card.headerColor, look.colors.caution);
    });

    testWidgets('the abandoned card has a bad header', (tester) async {
      final app = await joined(tester);
      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.abandoned));
      await settle(tester);
      final look = ToyLookScope.of(tester.element(find.byKey(const Key('abandonedNotice'))));
      expect(cardOf(tester, const Key('abandonedNotice')).headerColor, look.colors.bad);
    });

    testWidgets('the rating card has a focus header', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected);
      await tester.pump();
      app.client.ask(const RatingAskMessage(id: 'r1', game: 'arena'));
      await settle(tester);
      final prompt = find.byKey(const Key('ratingPrompt'));
      final look = ToyLookScope.of(tester.element(prompt));
      final card = tester.widget<ToyCard>(find.descendant(of: prompt, matching: find.byType(ToyCard)));
      expect(card.header, PhoneText.howDidItFeel);
      expect(card.headerColor, look.colors.focus);
    });
  });

  group('the bar over the pad (M13 3c)', () {
    test('the link dot takes good, caution, focus and paper, never a text colour', () {
      expect(linkDotColor(sunny, ClientStatus.connected), sunny.colors.good);
      expect(linkDotColor(sunny, ClientStatus.reconnecting), sunny.colors.caution);
      expect(linkDotColor(sunny, ClientStatus.connecting), sunny.colors.caution);
      expect(linkDotColor(sunny, ClientStatus.waitingForCode), sunny.colors.focus);
      // No link is a paper dot with its ink edge: a faded ink dot was lost on
      // the Night sky (Claude's 3c review).
      expect(linkDotColor(sunny, ClientStatus.failed), sunny.colors.paper);
      expect(linkDotColor(sunny, ClientStatus.idle), sunny.colors.paper);
    });

    testWidgets('the bar\'s text and icons are onBackground', (tester) async {
      await pumpApp(tester, paired: true);
      final look = ToyLookScope.of(tester.element(find.byType(BarConnection)));
      final chip = tester.widget<ActionChip>(find.byKey(const Key('connectionChip')));
      expect(chip.labelStyle!.color, look.colors.onBackground);
      final settings = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.settings_outlined));
      expect((settings.icon as Icon).color, look.colors.onBackground);
    });
  });

  group('PhoneText (M13 3c)', () {
    test('a link with its ping, and a ping over 30 s', () {
      expect(PhoneText.linkWithPing('Android TV', 9), 'Android TV · 9 ms');
      expect(PhoneText.linkWithPing('Android TV', null), 'Android TV · – ms');
      expect(PhoneText.pingStats(5, 22, 130), '30 s: min 5 · avg 22 · max 130 ms');
      // A p95 not yet known is a dash, not 0 (Claude's 3c review).
      expect(SettingsText.summaryWithP95('min 5', 300), 'min 5, p95 300 ms');
      expect(SettingsText.summaryWithP95('min 5', null), 'min 5, p95 – ms');
    });

    test('a host\'s row, a player, a share and a TV event', () {
      expect(PhoneText.hostLine(PhoneText.hostKindWord('phone'), '192.168.1.51:45780'), 'Phone · 192.168.1.51:45780');
      expect(SettingsText.playerOnTv(2), 'P2 on the TV');
      expect(SettingsText.share(0.4), '40%');
      expect(SettingsText.percent(70), '70%');
      expect(SettingsText.eventStrength('hit', 70), 'hit 70%');
      expect(PhoneText.ratingTag(RatingTag.laggy), 'Laggy');
      expect(PhoneText.modeName('dpad'), PhoneText.dpad);
    });
  });
}
