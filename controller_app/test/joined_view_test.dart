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
    /// The app connected to a host that shows the Arena, with a status panel
    /// up and the first frame drawn.
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
  });
}
