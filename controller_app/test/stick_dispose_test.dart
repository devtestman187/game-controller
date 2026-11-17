import 'package:controller/src/haptics.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/sticks.dart';
import 'package:controller/src/ui/stick_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

/// A stick's square, in logical pixels: radius 100, so a thumb 50 px from the
/// center reaches half travel.
const double _stickSize = 200;

/// A stick on screen that a test can take away while a thumb is on it, the
/// way a round end or a layout change does (B-031).
class _StickHost extends StatefulWidget {
  const _StickHost({super.key});

  @override
  State<_StickHost> createState() => _StickHostState();
}

class _StickHostState extends State<_StickHost> {
  var _showsStick = true;

  /// Takes the stick off the screen, disposing it where it stands.
  void removeStick() => setState(() => _showsStick = false);

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: _stickSize,
      height: _stickSize,
      child: _showsStick
          ? const AnalogStickView(side: StickSide.left, home: Rect.fromLTWH(0, 0, _stickSize, _stickSize))
          : const SizedBox.shrink(),
    ),
  );
}

void main() {
  group('a stick disposed with a thumb on it', () {
    late TestApp app;
    late ProviderContainer container;

    /// Pumps the stick on a phone's providers, with stick mode started (both
    /// sticks centered and sending), as the app's own start does.
    Future<GlobalKey<_StickHostState>> pumpStick(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      app = TestApp(FakeClient(), FakeDiscovery(), FakeHaptics(), prefs, FakeMotionSensors());
      final host = GlobalKey<_StickHostState>();
      await pumpFaked(tester, _StickHost(key: host), app: app);
      await tester.pump();
      container = ProviderScope.containerOf(tester.element(find.byType(_StickHost)));
      container.read(padProvider.notifier).switchMode(tilt: false, sticks: true);
      return host;
    }

    Offset stickCenterOf(WidgetTester tester) => tester.getCenter(find.byType(AnalogStickView));

    testWidgets('lifting the thumb after the stick is gone throws nothing', (tester) async {
      final host = await pumpStick(tester);
      final thumb = await tester.startGesture(stickCenterOf(tester));
      await thumb.moveBy(const Offset(40, 0));
      await tester.pump();
      // 40 of 100 px, past the 0.1 dead zone: (0.4 - 0.1) / 0.9 = 0.333.
      expect(container.read(padProvider).left, (x: 0.333, y: 0.0), reason: 'the thumb moved the stick');

      host.currentState!.removeStick();
      await tester.pump();
      expect(find.byType(AnalogStickView), findsNothing);

      await thumb.up();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'no setState or ref.read after dispose');
    });

    testWidgets('the stick taken away with the thumb on it sends its release', (tester) async {
      final host = await pumpStick(tester);
      final thumb = await tester.startGesture(stickCenterOf(tester));
      await thumb.moveBy(const Offset(0, -50));
      await tester.pump();
      // 50 of 100 px up: (0.5 - 0.1) / 0.9 = 0.444, negative upwards.
      expect(container.read(padProvider).left, (x: 0.0, y: -0.444));

      host.currentState!.removeStick();
      await tester.pump();

      expect(container.read(padProvider).left, stickCenter, reason: 'the TV must not keep a pushed stick');
      expect(app.client.inputs.last, endsWith('L 0.0,0.0 R 0.0,0.0'));
      await thumb.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a thumb still down when the whole screen goes throws nothing', (tester) async {
      await pumpStick(tester);
      final thumb = await tester.startGesture(stickCenterOf(tester));
      await thumb.moveBy(const Offset(0, -50));
      await tester.pump();

      // The app's own scope goes with the screen (a rebuild from the root).
      await tester.pumpWidget(const SizedBox.shrink());
      await thumb.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a thumb moved and lifted while the stick stays still moves and releases it', (tester) async {
      await pumpStick(tester);
      final thumb = await tester.startGesture(stickCenterOf(tester));
      await tester.pump();
      expect(container.read(padProvider).left, stickCenter, reason: 'a touch at the center is no deflection');

      await thumb.moveBy(const Offset(0, -50));
      await tester.pump();
      expect(container.read(padProvider).left, (x: 0.0, y: -0.444));

      await thumb.up();
      await tester.pump();
      expect(container.read(padProvider).left, stickCenter);
      expect(tester.takeException(), isNull);
    });
  });
}
