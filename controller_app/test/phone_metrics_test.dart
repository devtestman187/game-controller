import 'package:connection/connection.dart' show LogBuffer;
import 'package:controller/src/gyro.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/phone_metrics.dart';
import 'package:controller/src/sticks.dart';
import 'package:controller/src/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' as app;

const mm = phonePxPerMm;

/// The body of the test phone (852 x 393 minus the top bar), roughly.
const body = Size(852, 330);

void main() {
  group('touch map', () {
    test('a touch just beside B is a near miss on B; a blank spot is an empty tap', () {
      final map = touchMapFor(mode: PadMode.dpad, body: body, mm: mm);
      final square = padLayout(body, mm: mm).faceButtons;
      final b = square.topLeft + FaceGeometry.classic.centers[ControllerButton.b]! * square.width;
      // 3 mm right of the buttons' square, level with B.
      final beside = Offset(square.right + 3 * mm, b.dy);
      final hit = map.hit(beside.dx / mm, beside.dy / mm);
      expect(hit.control, isNull);
      expect(hit.nearest, 'b');
      expect(hit.distanceMm, closeTo(3, 0.2));
      // On B itself.
      expect(map.hit(b.dx / mm, b.dy / mm).control, 'b');
      // The top middle of the screen is far from everything.
      final blank = map.hit(body.width / 2 / mm, 2);
      expect(blank.control, isNull);
      expect(blank.distanceMm, greaterThan(Thresholds.nearMissMm));
    });

    test('stick mode has every control, fixed sticks a little beyond their circles', () {
      final map = touchMapFor(mode: PadMode.sticks, body: body, mm: mm, sticks: const StickSettings());
      expect(map.shapes.map((s) => s.control).toSet(), {
        'ls',
        'rs',
        'dpad',
        'a',
        'b',
        'x',
        'y',
        'lb',
        'rb',
        'select',
        'start',
      });
      final l = stickLayout(body, mm: mm);
      final edge = l.leftStick.center + Offset(l.leftStick.width / 2 * 1.1, 0);
      expect(map.hit(edge.dx / mm, edge.dy / mm).control, 'ls');
    });

    test('floating sticks take their whole zone', () {
      final map = touchMapFor(mode: PadMode.sticks, body: body, mm: mm, sticks: const StickSettings(floating: true));
      final zone = stickLayout(body, mm: mm).leftZone;
      expect(map.hit((zone.left + 2) / mm, (zone.bottom - 2) / mm).control, 'ls');
    });

    test('gyro mode has the tilt area instead of the D-pad', () {
      final map = touchMapFor(mode: PadMode.gyro, body: body, mm: mm);
      expect(map.shapes.map((s) => s.control), contains('tilt'));
      expect(map.shapes.map((s) => s.control), isNot(contains('dpad')));
    });
  });

  group('segments', () {
    test('records only while active; a mode switch ends one segment and starts the next', () {
      var now = 0;
      final sent = <MetricsMessage>[];
      final m = PhoneMetrics(send: sent.add, now: () => now)..setMode('dpad', const {'haptics': true});
      m.held({'a'});
      expect(m.segment, isNull, reason: 'not connected yet');

      m.setActive(true);
      now = 1000;
      m.held({'a'});
      now = 1200;
      m.held({});
      now = 5000;
      m.setMode('sticks', const {'haptics': true, 'floating': false});
      expect(sent, hasLength(1));
      final first = sent.single;
      expect(first.mode, 'dpad');
      expect(first.ended, isTrue);
      expect(first.durationMs, 5000);
      expect(first.data['presses'], {'a': 1});
      expect(first.data['settings'], {'haptics': true});

      now = 6000;
      m.disconnected(); // Flushed, not ended: the mode goes on.
      expect(sent.last.mode, 'sticks');
      expect(sent.last.ended, isFalse);
      expect(sent.last.data['start'], 5000);

      m.setActive(false);
      expect(sent.last.ended, isTrue);
      expect(sent.last.segment, sent[1].segment);
      expect(sent.last.index, greaterThan(sent[1].index));
      m.held({'b'});
      expect(m.segment, isNull);
    });

    test('a settings change starts a new segment; the same settings do not', () {
      final sent = <MetricsMessage>[];
      final m = PhoneMetrics(send: sent.add, now: () => 0)
        ..setMode('sticks', const {'buttonSize': 0.75})
        ..setActive(true)
        ..setMode('sticks', const {'buttonSize': 0.75});
      expect(sent, isEmpty);
      m.setMode('sticks', const {'buttonSize': 0.9});
      expect(sent.single.ended, isTrue);
      expect(m.segment!.settings, {'buttonSize': 0.9});
    });
  });

  group('in the app', () {
    testWidgets('a tap beside B arrives as a near miss on B in the next batch', (tester) async {
      final a = await app.pumpApp(tester, paired: true);
      a.client.emit(app.connected);
      await tester.pump();

      final square = tester.getRect(find.byKey(const Key('faceButtons')));
      await tester.tapAt(Offset(square.right + 3 * mm, square.center.dy));
      await tester.pump();
      // Switching modes sends the D-pad segment.
      await tester.tap(find.text('Sticks'));
      await app.settle(tester);
      final batch = a.client.metrics.firstWhere((b) => b.mode == 'dpad' && b.ended);
      expect(batch.data['near'], {'b': 1});
      expect(batch.data['touches'], 1);
    });

    testWidgets('nothing is recorded in the demo or with stats turned off', (tester) async {
      final a = await app.pumpApp(tester, paired: true, saved: const {'shareStats': false});
      a.client.emit(app.connected);
      await tester.pump();
      await tester.tap(find.text('Sticks'));
      await app.settle(tester);
      expect(a.client.metrics, isEmpty);
    });

    testWidgets('the rating prompt sends a face with the tags picked', (tester) async {
      final a = await app.pumpApp(tester, paired: true);
      a.client.emit(app.connected);
      await tester.pump();
      a.client.ask(const RatingAskMessage(id: 'r1', game: 'arena'));
      await app.settle(tester);
      expect(find.byKey(const Key('ratingPrompt')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tag-${RatingTag.laggy}')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('rate-bad')));
      await app.settle(tester);
      expect(find.byKey(const Key('ratingPrompt')), findsNothing);
      expect(a.client.ratings.single.id, 'r1');
      expect(a.client.ratings.single.face, RatingFace.bad);
      expect(a.client.ratings.single.tags, [RatingTag.laggy]);
    });

    testWidgets('the rating prompt fits the smallest phone in landscape (iPhone SE): every tag and Skip on screen', (tester) async {
      final a = await app.pumpApp(tester, paired: true, screen: const Size(667, 375));
      a.client.emit(app.connected);
      await tester.pump();
      a.client.ask(const RatingAskMessage(id: 'r1', game: 'arena'));
      await app.settle(tester);
      final screen = Offset.zero & tester.view.physicalSize;
      bool inside(Rect outer, Rect r) => outer.contains(r.topLeft) && outer.contains(r.bottomRight - const Offset(1, 1));
      for (final key in [
        for (final tag in RatingTag.all) 'tag-$tag',
        'rate-good',
        'rate-okay',
        'rate-bad',
        'rate-skip',
      ]) {
        final finder = find.byKey(Key(key));
        final rect = tester.getRect(finder);
        expect(inside(screen, rect), isTrue, reason: '$key at $rect is off the screen');
        // Inside a scrolling area, it must also be in the part that shows
        // without scrolling (on the emulator the fourth tag was cut off).
        final scroll = find.ancestor(of: finder, matching: find.byType(Scrollable));
        if (scroll.evaluate().isNotEmpty) {
          final visible = tester.getRect(scroll.first);
          expect(inside(visible, rect), isTrue, reason: '$key at $rect is cut off (visible area $visible)');
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a prompt from the TV is logged when it arrives', (tester) async {
      final log = LogBuffer();
      final a = await app.pumpApp(tester, paired: true, log: log);
      a.client.emit(app.connected);
      await tester.pump();
      a.client.ask(const RatingAskMessage(id: 'r1', game: 'arena'));
      await app.settle(tester);
      expect(log.lines.map((l) => l.message), contains('The TV asks how the controls felt (arena)'));
    });

    testWidgets('the rating prompt can be skipped, and skips itself after a while', (tester) async {
      final a = await app.pumpApp(tester, paired: true);
      a.client.emit(app.connected);
      await tester.pump();
      a.client.ask(const RatingAskMessage(id: 'r1', game: 'arena'));
      await app.settle(tester);
      await tester.tap(find.byKey(const Key('rate-skip')));
      await app.settle(tester);
      expect(a.client.ratings.single.skipped, isTrue);

      a.client.ask(const RatingAskMessage(id: 'r2', game: 'arena'));
      await app.settle(tester);
      await tester.pump(const Duration(seconds: 21));
      await app.settle(tester);
      expect(a.client.ratings.last.id, 'r2');
      expect(a.client.ratings.last.skipped, isTrue);
      expect(find.byKey(const Key('ratingPrompt')), findsNothing);
    });

    testWidgets('Settings shows that stats are recorded, and the switch is saved', (tester) async {
      final a = await app.pumpApp(tester, paired: true);
      await app.openSettings(tester);
      await app.scrollTo(tester, find.byKey(const Key('settingsShareStats')));
      expect(find.textContaining('Never names'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settingsShareStats')));
      await tester.pump();
      expect(a.prefs.getBool('shareStats'), isFalse);
    });

    test('the hello lists metrics and rating, the device kind and the screen size', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final identity = loadIdentity(prefs, isTablet: true, screenMm: const Size(160, 250));
      final hello = identity.toHello();
      expect(hello.capabilities, [Capability.metrics, Capability.rating]);
      expect(hello.device!.kind, DeviceInfo.tablet);
      expect((hello.device!.widthMm, hello.device!.heightMm), (250, 160));
      final detailed = withDeviceDetails(identity, model: 'Google Pixel Tablet', os: 'Android 15', haptics: false);
      expect(detailed.device!.model, 'Google Pixel Tablet');
      expect(detailed.device!.widthMm, 250);
    });
  });
}
