import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/demo/bot.dart';
import 'package:tvtest/src/demo/events.dart';

/// The bots' send policy and the take's event log
/// (docs/demo-video-runbook.md 2.3).
void main() {
  group('DemoBot.shouldSend', () {
    const still = GamepadState.neutral;

    test('a change always goes out', () {
      expect(DemoBot.shouldSend(const GamepadState(leftX: 0.5, mode: InputMode.sticks), still, Duration.zero), isTrue);
      expect(DemoBot.shouldSend(const GamepadState(buttons: {GamepadButton.a}), still, Duration.zero), isTrue);
    });

    test('an unchanged centred state is not resent', () {
      expect(DemoBot.shouldSend(still, still, const Duration(seconds: 5)), isFalse);
    });

    test('a held stick is resent at least every 100 ms', () {
      const held = GamepadState(leftX: 1, mode: InputMode.sticks);
      expect(DemoBot.shouldSend(held, held, const Duration(milliseconds: 99)), isFalse);
      expect(DemoBot.shouldSend(held, held, const Duration(milliseconds: 100)), isTrue);
    });

    test('the platform is bot, not sim or android', () {
      expect(DemoBot.platform, 'bot');
    });

    test('a bot identifies itself as a bot', () {
      final bot = DemoBot(name: 'Bot 2', id: 'demo-bot-2');
      addTearDown(bot.dispose);
      expect(bot.client.identity.platform, 'bot');
      expect(bot.client.identity.name, 'Bot 2');
      expect(bot.client.identity.capabilities, containsAll(['layout', 'status']));
    });
  });

  group('EventLog', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('events'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes one JSON line per event, with a wall-clock time', () {
      final log = EventLog(take: 'G3_take2', dir: dir.path, clock: () => DateTime.fromMillisecondsSinceEpoch(1000));
      log.add('scene_start');
      log.add('snap', {'player': 'P1', 'piece': 'nose'});

      final lines = File('${dir.path}/G3_take2_events.jsonl').readAsLinesSync();
      expect(lines, hasLength(2));
      expect(jsonDecode(lines.first), {'wall': 1000, 'name': 'scene_start'});
      expect(jsonDecode(lines.last), {'wall': 1000, 'name': 'snap', 'player': 'P1', 'piece': 'nose'});
      expect(log.names, ['scene_start', 'snap']);
    });
  });
}
