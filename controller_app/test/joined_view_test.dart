import 'package:connection/connection.dart';
import 'package:controller/src/controls_settings.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/storage.dart';
import 'package:controller/src/ui/controls_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_game/test_game.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

/// The Arena a test's frames carry: one player in the middle of the field,
/// nothing in its way.
final arena = ArenaSnapshot(
  round: 1,
  roundTimeS: 30,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: const Rect.fromLTRB(0.9, 0.4, 1, 0.6),
  hazards: const [],
  players: const [ArenaPlayerView(id: 'phone-1', x: 0.5, y: 0.5)],
);

/// The start the host sends for [arena], at 60 frames a second.
ViewStartMessage arenaStart() =>
    ViewStartMessage(game: arenaModule.id, snapshotVersion: arenaModule.snapshotVersion, setup: arenaSetup, hz: 60);

/// Step [n] of [arena] at host time [atMs], with the sounds it fired.
FrameMessage arenaFrame(int n, {int atMs = 1000, List<String> sounds = const []}) =>
    FrameMessage(n: n, atMs: atMs, snapshot: arena.toJson(), sounds: sounds);

/// The opacity the controls are drawn with, over the game behind them.
double layerOpacity(WidgetTester tester) => tester
    .widget<Opacity>(find.ancestor(of: find.byKey(const Key('faceButtons')), matching: find.byType(Opacity)).first)
    .opacity;

/// The opacity the bar draws an item with (m12-phone-layout §0.7b): the
/// control's opacity while a game shows behind it.
double barOpacity(WidgetTester tester, Key key) =>
    tester.widget<Opacity>(find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)).first).opacity;

/// The app connected to a host that shows the Arena, with a status panel up
/// and the first frame drawn.
Future<TestApp> joined(
  WidgetTester tester, {
  Size screen = const Size(852, 393),
  FakeViewPadding padding = const FakeViewPadding(),
}) async {
  final app = await pumpApp(tester, paired: true, screen: screen, padding: padding);
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
  group('the phone\'s capabilities (m12 §0.1)', () {
    test('the hello lists view, and the host\'s own player\'s does not', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final identity = loadIdentity(prefs);
      expect(identity.toHello().capabilities, contains(Capability.view), reason: 'a phone can show a game');

      final own = ownPlayerIdentity(identity);
      expect(own.toHello().capabilities, isNot(contains(Capability.view)), reason: 'the host draws its own game');
      expect(own.controllerId, identity.controllerId, reason: 'the same player, without one capability');
      expect(own.capabilities, [Capability.metrics, Capability.rating, Capability.layout, Capability.status]);
    });
  });

  group('the joined view (m12 §5)', () {
    testWidgets('a started view draws the Arena behind the controls, dims them and hides the status panel', (
      tester,
    ) async {
      final app = await pumpApp(tester, paired: true, saved: {'controlsOpacity': 0.6});
      app.client.emit(connected);
      app.client.setStatus(StatusMessage(text: 'Left 3/6'));
      await settle(tester);
      expect(find.byKey(const Key('statusPanel')), findsOneWidget);
      expect(layerOpacity(tester), ControlsSettings.maxOpacity, reason: 'nothing behind the controls yet');

      app.client.nowMs = 1000;
      app.client.viewStart(arenaStart());
      await settle(tester);
      expect(find.byKey(const Key('arena')), findsNothing, reason: 'nothing is drawn before the first frame');
      app.client.viewFrame(arenaFrame(0));
      await settle(tester);

      expect(find.byKey(const Key('arena')), findsOneWidget);
      expect(layerOpacity(tester), 0.6, reason: 'the saved controlsOpacity');
      expect(find.byKey(const Key('statusPanel')), findsNothing, reason: 'the game draws its own status');

      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished));
      await settle(tester);
      expect(find.byKey(const Key('arena')), findsNothing);
      expect(layerOpacity(tester), ControlsSettings.maxOpacity);
      expect(find.byKey(const Key('statusPanel')), findsOneWidget);
    });

    testWidgets('a game this app does not know says to update the app', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.nowMs = 1000;
      app.client.viewStart(const ViewStartMessage(game: 'mystery', snapshotVersion: 1, setup: {}, hz: 60));
      await settle(tester);

      expect(find.text(updateAppText), findsOneWidget);
      expect(find.byKey(const Key('arena')), findsNothing);
    });

    testWidgets('each frame\'s sounds play once through the party sound player', (tester) async {
      final sounds = party_test.FakeSoundPlayer();
      final app = await pumpApp(tester, paired: true, extra: [party.soundPlayerProvider.overrideWithValue(sounds)]);
      // Three steps, each arriving on time: the phone's clock is the host's,
      // as it is on a fast network.
      app.client.nowMs = 1000;
      app.client.viewStart(arenaStart());
      await settle(tester);
      app.client.viewFrame(arenaFrame(1, atMs: 1000, sounds: const ['hit']));
      app.client.nowMs = 1016;
      app.client.viewFrame(arenaFrame(2, atMs: 1016));
      app.client.nowMs = 1032;
      app.client.viewFrame(arenaFrame(3, atMs: 1032, sounds: const ['snap']));
      await settle(tester);
      expect(sounds.played, ['hit', 'snap'], reason: 'in step order');

      await settle(tester);
      expect(sounds.played, hasLength(2), reason: 'a frame\'s sounds play once, however many ticks draw it');
    });

    testWidgets('the game fills the safe area while the controls and their metrics keep the body below the bar', (
      tester,
    ) async {
      // A notch: 48 + 48 across and 24 down are not ours to draw on.
      await joined(tester, padding: const FakeViewPadding(left: 48, top: 24, right: 48));
      expect(find.byKey(const Key('arena')), findsOneWidget);

      // The screen is 852 × 393; inside the safe area it is 756 × 369, and
      // the game takes all of it, from the very top.
      expect(tester.getRect(find.byType(FrameView)), const Rect.fromLTWH(48, 24, 756, 369));
      // The bar is its 4 px top padding plus the 48-high row, so the controls
      // and their touch map keep 369 − 52 = 317 px below it.
      expect(tester.getRect(find.byType(ControlsLayer)), const Rect.fromLTWH(48, 76, 756, 317));
      final container = ProviderScope.containerOf(tester.element(find.byType(ControlsLayer)));
      final metrics = container.read(phoneMetricsProvider);
      expect(metrics.active, isTrue, reason: 'connected, so the touch metrics record');
      final map = metrics.segment?.map;
      expect(map?.widthMm, closeTo(756 / phonePxPerMm, 1e-9), reason: 'the body\'s width, not the screen\'s');
      expect(map?.heightMm, closeTo(317 / phonePxPerMm, 1e-9), reason: 'the body\'s height, not the safe area\'s');
    });

    testWidgets('a new client starts with no view, as when this phone starts hosting', (tester) async {
      await joined(tester);
      expect(find.byKey(const Key('arena')), findsOneWidget);

      // This phone starts hosting: its own player's client takes the screens
      // (m12 §3), and that client has seen no view.
      final container = ProviderScope.containerOf(tester.element(find.byType(ControlsLayer)));
      container.read(ownClientProvider.notifier).set(FakeClient());
      await settle(tester);

      expect(find.byKey(const Key('arena')), findsNothing);
      expect(layerOpacity(tester), ControlsSettings.maxOpacity);
    });

    testWidgets('showing the app again starts the sound engine once while a game is shown', (tester) async {
      final sounds = party_test.FakeSoundPlayer();
      final app = await pumpApp(tester, paired: true, extra: [party.soundPlayerProvider.overrideWithValue(sounds)]);
      app.client.nowMs = 1000;
      app.client.viewStart(arenaStart());
      await settle(tester);
      expect(sounds.restarts, 0);

      // The phone locked or another app took it, then back: iOS stopped the
      // app's sound (s5c).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect(sounds.restarts, 1);
    });
  });

  group('the bar over a game (m12-phone-layout §0.7b)', () {
    testWidgets('the full bar goes compact: the badge, the dot and three icons at the controls\' opacity', (
      tester,
    ) async {
      final app = await pumpApp(tester, paired: true, saved: {'controlsOpacity': 0.6});
      app.client.emit(connected.copyWith(player: 1));
      await settle(tester);
      // Controller mode has the full bar: the host's name, the ping, the labels.
      expect(find.byKey(const Key('connectionChip')), findsOneWidget);
      expect(find.textContaining('Android TV'), findsOneWidget);
      expect(find.byKey(const Key('modeMenu')), findsNothing);

      app.client.nowMs = 1000;
      app.client.viewStart(arenaStart());
      await settle(tester);
      app.client.viewFrame(arenaFrame(0));
      await settle(tester);

      // Over the game: the player's badge and the link's dot on the left, the
      // mode, Settings and Diagnostics as icons on the right.
      expect(find.byKey(const Key('playerBadge')), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.byKey(const Key('connectionDot')), findsOneWidget);
      expect(find.byKey(const Key('modeMenu')), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byTooltip('Diagnostics'), findsOneWidget);
      // Nothing in the middle: no host name, no ping, no status panel.
      expect(find.byKey(const Key('connectionChip')), findsNothing);
      expect(find.textContaining('Android TV'), findsNothing);
      expect(find.byKey(const Key('pingStats')), findsNothing);
      expect(find.byKey(const Key('statusPanel')), findsNothing);
      // Drawn at the controls' opacity, the saved one.
      expect(barOpacity(tester, const Key('modeMenu')), 0.6);
      expect(barOpacity(tester, const Key('playerBadge')), 0.6);
      expect(barOpacity(tester, const Key('connectionDot')), 0.6);
    });

    testWidgets('the one mode icon opens the three modes, and picking one switches the pad', (tester) async {
      await joined(tester);
      expect(find.byKey(const Key('inputSummary')), findsOneWidget, reason: 'the D-pad mode is on');

      await tester.tap(find.byKey(const Key('modeMenu')));
      await settle(tester);
      expect(find.text('D-pad'), findsOneWidget);
      expect(find.text('Gyro'), findsOneWidget);
      expect(find.text('Sticks'), findsOneWidget);

      await tester.tap(find.text('Sticks'));
      await settle(tester);
      expect(find.byKey(const Key('leftStick')), findsOneWidget);
      expect(find.byKey(const Key('inputSummary')), findsNothing);

      // Back again, the same way.
      await tester.tap(find.byKey(const Key('modeMenu')));
      await settle(tester);
      await tester.tap(find.text('D-pad'));
      await settle(tester);
      expect(find.byKey(const Key('inputSummary')), findsOneWidget);
    });

    testWidgets('the mode menu holds the mode in use\'s settings, which open the full bar\'s dialog', (tester) async {
      await joined(tester);

      // D-pad has nothing to tune: the menu is the three modes alone.
      await tester.tap(find.byKey(const Key('modeMenu')));
      await settle(tester);
      expect(find.text('Stick settings'), findsNothing);
      expect(find.text('Gyro settings'), findsNothing);
      await tester.tap(find.text('Sticks'));
      await settle(tester);

      // Sticks adds "Stick settings" below a divider (s7d2 Q4), and it opens
      // the dialog the full bar's tune button opens.
      await tester.tap(find.byKey(const Key('modeMenu')));
      await settle(tester);
      expect(find.text('Stick settings'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      await tester.tap(find.text('Stick settings'));
      await settle(tester);
      expect(find.byKey(const Key('stickFloating')), findsOneWidget);

      // Done closes it, and the pad is still on the sticks.
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.byKey(const Key('leftStick')), findsOneWidget);
    });

    testWidgets('the compact bar keeps the full bar\'s touch sizes and the pad\'s body below it (C14 to C16)', (
      tester,
    ) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(connected.copyWith(player: 1));
      await settle(tester);
      // The full bar's two icon buttons: the sizes the compact bar must keep.
      final settings = tester.getSize(find.byTooltip('Settings'));
      final diagnostics = tester.getSize(find.byTooltip('Diagnostics'));

      app.client.nowMs = 1000;
      app.client.viewStart(arenaStart());
      await settle(tester);
      app.client.viewFrame(arenaFrame(0));
      await settle(tester);

      expect(tester.getSize(find.byTooltip('Settings')), settings);
      expect(tester.getSize(find.byTooltip('Diagnostics')), diagnostics);
      final mode = tester.getSize(find.byKey(const Key('modeMenu')));
      expect(mode.width, greaterThanOrEqualTo(settings.width), reason: 'the one mode icon is no smaller');
      expect(mode.height, greaterThanOrEqualTo(settings.height), reason: 'the one mode icon is no smaller');
      // The bar is still 52 px: the pad and its touch map keep the same body.
      expect(tester.getSize(find.byType(ControlsLayer)), const Size(852, 341));
    });

    testWidgets('the full bar comes back when the game ends', (tester) async {
      final app = await joined(tester);
      expect(find.byKey(const Key('modeMenu')), findsOneWidget);

      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished));
      await settle(tester);

      expect(find.byKey(const Key('connectionChip')), findsOneWidget);
      expect(find.textContaining('Android TV'), findsOneWidget);
      expect(find.text('D-pad'), findsOneWidget, reason: 'the mode labels are back');
      expect(find.byKey(const Key('modeMenu')), findsNothing);
      expect(find.byKey(const Key('connectionDot')), findsNothing);
    });
  });

  group('waiting for the host (m12-joined-view §0.3)', () {
    testWidgets('an away host counts its round down once a second, and coming back hides the card', (tester) async {
      final app = await joined(tester);
      app.client.hostAway(30);
      await settle(tester);
      expect(find.text('Waiting for the host to come back'), findsOneWidget);
      expect(find.text('The game goes on if they\'re back in 30 s'), findsOneWidget);

      // 5 s pass on the phone's clock, and the card ticks once.
      app.client.nowMs += 5000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The game goes on if they\'re back in 25 s'), findsOneWidget);

      app.client.hostBack();
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
    });

    testWidgets('a countdown that ran out says the host may have left', (tester) async {
      final app = await joined(tester);
      app.client.hostAway(2);
      await settle(tester);
      app.client.nowMs += 3000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The host may have left'), findsOneWidget);
    });

    testWidgets('a link that drops over a game counts the grace, and reconnecting clears it', (tester) async {
      final app = await joined(tester);
      app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv));
      await settle(tester);
      expect(find.text('The game goes on if they\'re back in 30 s'), findsOneWidget);

      app.client.nowMs += 5000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The game goes on if they\'re back in 25 s'), findsOneWidget);

      app.client.emit(connected);
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
    });

    testWidgets('a phone with no game shown says nothing when its link drops', (tester) async {
      final app = await pumpApp(tester, paired: true);
      app.client.emit(ClientSnapshot(status: ClientStatus.reconnecting, target: tv));
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
      expect(find.text('Waiting for the host to come back'), findsNothing);
    });

    testWidgets('a new view clears the wait', (tester) async {
      final app = await joined(tester);
      app.client.hostAway(30);
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsOneWidget);

      app.client.viewStart(arenaStart());
      await settle(tester);
      expect(find.byKey(const Key('waitingCard')), findsNothing);
    });
  });

  group('a round the host abandoned (m12 §0.5)', () {
    testWidgets('says the host was away too long, then goes after a moment', (tester) async {
      final app = await joined(tester);
      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.abandoned));
      await settle(tester);
      expect(find.byKey(const Key('abandonedNotice')), findsOneWidget);
      expect(find.text('The host was away too long, so the round ended.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('abandonedNotice')), findsNothing);
    });

    testWidgets('a round that finished shows no notice', (tester) async {
      final app = await joined(tester);
      app.client.viewEnd(const ViewEndMessage(reason: ViewEndReason.finished));
      await settle(tester);
      expect(find.byKey(const Key('abandonedNotice')), findsNothing);
    });
  });
}
