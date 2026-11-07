import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

const codec = MessageCodec();

Message? roundTrip(Message m) => codec.decode(codec.encode(m));

Map<String, Object?> wire(Message m) => jsonDecode(codec.encode(m)) as Map<String, Object?>;

void main() {
  group('view_start (M12)', () {
    test('the module, snapshot version, setup and frame rate round-trip', () {
      const start = ViewStartMessage(
        game: 'shape_race',
        snapshotVersion: 1,
        setup: {'puzzle': 'boat', 'level': 2, 'timeLimitS': 90, 'teams': true},
        hz: 60,
      );
      final back = roundTrip(start) as ViewStartMessage;
      expect(back, start);
      expect(back.setup['puzzle'], 'boat');
      expect(back.hz, 60);
    });

    test('the Arena sends an empty setup', () {
      const start = ViewStartMessage(game: 'arena', snapshotVersion: 1, setup: {}, hz: 30);
      expect((roundTrip(start) as ViewStartMessage).setup, isEmpty);
    });
  });

  group('frame (M12)', () {
    test('a frame with sounds, acks and a roster round-trips', () {
      final frame = FrameMessage(
        n: 42,
        atMs: 672,
        snapshot: {'v': 1, 't': 61000},
        sounds: ['snap', 'success'],
        acks: {'p1': 12, 'p2': 3},
        roster: {'p1': (number: 1, name: 'Ada'), 'p2': (number: 2, name: '')},
      );
      final back = roundTrip(frame) as FrameMessage;
      expect(back, frame);
      expect(back.snapshot['t'], 61000);
      expect(back.sounds, ['snap', 'success']);
      expect(back.acks['p1'], 12);
      expect(back.roster['p1'], (number: 1, name: 'Ada'));
      expect(back.roster['p2'], (number: 2, name: ''));
    });

    test('sounds are left out of the frame when there are none', () {
      final json = wire(FrameMessage(n: 0, atMs: 0, snapshot: const {}));
      expect(json.containsKey('snd'), isFalse);
      expect(json['acks'], isEmpty);
      expect(json['pl'], isEmpty);
      expect(
        (codec.decode(codec.encode(FrameMessage(n: 0, atMs: 0, snapshot: const {}))) as FrameMessage).sounds,
        isEmpty,
      );
    });

    test('the roster is [number, name] on the wire', () {
      final json = wire(FrameMessage(n: 1, atMs: 16, snapshot: const {}, roster: {'p1': (number: 3, name: 'Bo')}));
      expect(json['pl'], {
        'p1': [3, 'Bo'],
      });
    });

    test('a 4-player frame with a 1.8 KB snapshot encodes under 2.5 KB', () {
      final snapshot = <String, Object?>{
        'v': 1,
        'o': 'split',
        'b': [
          for (final board in ['b1', 'b2'])
            {
              'sd': 1234567,
              'pc': [
                for (var i = 0; i < 20; i++) {'i': 'pc$i', 'x': 100 + i, 'y': 200 + i, 'r': i, 'h': board},
              ],
            },
        ],
      };
      final frame = FrameMessage(
        n: 500,
        atMs: 8320,
        snapshot: snapshot,
        sounds: ['snap', 'pickup', 'success'],
        acks: {'p1': 120, 'p2': 118, 'p3': 76, 'p4': 4},
        roster: {
          'p1': (number: 1, name: 'Ada'),
          'p2': (number: 2, name: 'Bo'),
          'p3': (number: 3, name: 'Cy'),
          'p4': (number: 4, name: 'Di'),
        },
      );
      final snapshotBytes = jsonEncode(snapshot).length;
      expect(snapshotBytes, inInclusiveRange(1700, 1900), reason: 'the snapshot is a 4-player Shape Race frame');
      expect(codec.encode(frame).length, lessThan(2500));
    });
  });

  group('view_end (M12)', () {
    test('every reason round-trips', () {
      for (final reason in ViewEndReason.all) {
        final end = ViewEndMessage(reason: reason);
        expect((roundTrip(end) as ViewEndMessage).reason, reason);
      }
      expect(ViewEndReason.all, ['finished', 'quit', 'abandoned']);
    });

    test('an unknown reason is rejected, naming the field', () {
      final frame = jsonEncode({'v': protocolVersion, 't': 'view_end', 'reason': 'bored'});
      expect(
        () => codec.decode(frame),
        throwsA(isA<ProtocolFormatException>().having((e) => e.message, 'message', contains('"reason"'))),
      );
    });
  });

  group('malformed fields name the field', () {
    final cases = <({String what, Map<String, Object?> json, String field})>[
      (
        what: 'view_start without a game',
        json: {'t': 'view_start', 'sv': 1, 'setup': <String, Object?>{}, 'hz': 60},
        field: 'game',
      ),
      (
        what: 'view_start with a string version',
        json: {'t': 'view_start', 'game': 'a', 'sv': '1', 'hz': 60},
        field: 'sv',
      ),
      (
        what: 'view_start with a list setup',
        json: {'t': 'view_start', 'game': 'a', 'sv': 1, 'setup': [], 'hz': 60},
        field: 'setup',
      ),
      (
        what: 'view_start with a string rate',
        json: {'t': 'view_start', 'game': 'a', 'sv': 1, 'setup': <String, Object?>{}, 'hz': '60'},
        field: 'hz',
      ),
      (what: 'frame without a step number', json: {'t': 'frame', 'at': 1, 's': <String, Object?>{}}, field: 'n'),
      (
        what: 'frame with a string time',
        json: {'t': 'frame', 'n': 1, 'at': '1', 's': <String, Object?>{}},
        field: 'at',
      ),
      (what: 'frame without a snapshot', json: {'t': 'frame', 'n': 1, 'at': 1}, field: 's'),
      (
        what: 'frame with a string sounds list',
        json: {'t': 'frame', 'n': 1, 'at': 1, 's': {}, 'snd': 'snap'},
        field: 'snd',
      ),
      (what: 'frame with a list acks', json: {'t': 'frame', 'n': 1, 'at': 1, 's': {}, 'acks': []}, field: 'acks'),
      (
        what: 'frame with a string ack',
        json: {
          't': 'frame',
          'n': 1,
          'at': 1,
          's': {},
          'acks': {'p1': '3'},
        },
        field: 'acks',
      ),
      (
        what: 'frame with a roster that is a list',
        json: {'t': 'frame', 'n': 1, 'at': 1, 's': {}, 'pl': []},
        field: 'pl',
      ),
      (
        what: 'frame with a roster entry of the wrong length',
        json: {
          't': 'frame',
          'n': 1,
          'at': 1,
          's': {},
          'pl': {
            'p1': [1],
          },
        },
        field: 'pl',
      ),
      (
        what: 'frame with a string player number',
        json: {
          't': 'frame',
          'n': 1,
          'at': 1,
          's': {},
          'pl': {
            'p1': ['1', 'Ada'],
          },
        },
        field: 'pl',
      ),
      (what: 'view_end without a reason', json: {'t': 'view_end'}, field: 'reason'),
    ];
    for (final c in cases) {
      test(c.what, () {
        final frame = jsonEncode({'v': protocolVersion, ...c.json});
        expect(
          () => codec.decode(frame),
          throwsA(isA<ProtocolFormatException>().having((e) => e.message, 'message', contains('"${c.field}"'))),
        );
      });
    }
  });

  test('a view message from a newer host is still null for an unknown type', () {
    expect(codec.decode(jsonEncode({'v': protocolVersion, 't': 'view_pause'})), isNull);
  });

  group('metrics stages and view (M12)', () {
    MetricsMessage batch({Map<String, List<int>> stages = const {}, ({int frames, int gaps, int late})? view}) =>
        MetricsMessage(segment: 's1', index: 2, mode: 'dpad', durationMs: 20000, stages: stages, view: view);

    test('stages and view counts round-trip', () {
      final m = batch(
        stages: {
          'frame_jitter': [0, 12, 3],
          'touch_to_frame': [40],
        },
        view: (frames: 60, gaps: 1, late: 2),
      );
      final back = roundTrip(m) as MetricsMessage;
      expect(back, m);
      expect(back.stages['frame_jitter'], [0, 12, 3]);
      expect(back.stages['touch_to_frame'], [40]);
      expect(back.view, (frames: 60, gaps: 1, late: 2));
    });

    test('both are left out of the frame when empty', () {
      final json = wire(batch());
      expect(json.containsKey('stages'), isFalse);
      expect(json.containsKey('view'), isFalse);
      expect((codec.decode(codec.encode(batch())) as MetricsMessage).stages, isEmpty);
      expect((codec.decode(codec.encode(batch())) as MetricsMessage).view, isNull);
    });

    test('a batch from an older phone, without stages or view, still decodes', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'metrics',
        'seg': 's1',
        'i': 3,
        'mode': 'gyro',
        'ms': 5000,
        'end': false,
        'data': {'presses': 4},
      });
      final back = codec.decode(frame) as MetricsMessage;
      expect(back.index, 3);
      expect(back.stages, isEmpty);
      expect(back.view, isNull);
    });

    test('maxStageSamples is 256 per stage, and 257 is rejected', () {
      expect(MetricsMessage.maxStageSamples, 256);
      Map<String, Object?> withSamples(int count) => {
        't': 'metrics',
        'seg': 's',
        'i': 0,
        'mode': 'dpad',
        'ms': 1,
        'data': <String, Object?>{},
        'stages': {'frame_jitter': List.filled(count, 4)},
      };
      final full = codec.decode(jsonEncode({'v': protocolVersion, ...withSamples(256)})) as MetricsMessage;
      expect(full.stages['frame_jitter'], hasLength(256));
      expect(
        () => codec.decode(jsonEncode({'v': protocolVersion, ...withSamples(257)})),
        throwsA(isA<ProtocolFormatException>().having((e) => e.message, 'message', contains('"stages"'))),
      );
    });

    test('stage samples must be integers, and stage names may be any string', () {
      Map<String, Object?> batchJson(Object samples) => {
        't': 'metrics',
        'seg': 's',
        'i': 0,
        'mode': 'dpad',
        'ms': 1,
        'data': <String, Object?>{},
        'stages': {'frame_jitter': samples},
      };
      final back = codec.decode(
        jsonEncode({
          'v': protocolVersion,
          ...batchJson([1, 2]),
        }),
      ) as MetricsMessage;
      expect(back.stages['frame_jitter'], [1, 2]);
      expect(
        () => codec.decode(
          jsonEncode({
            'v': protocolVersion,
            ...batchJson(['1']),
          }),
        ),
        throwsA(isA<ProtocolFormatException>()),
      );
      expect(
        () => codec.decode(jsonEncode({'v': protocolVersion, ...batchJson('1')})),
        throwsA(isA<ProtocolFormatException>().having((e) => e.message, 'message', contains('"stages"'))),
      );
    });

    test('view counts must be integers, and the field must be an object', () {
      Map<String, Object?> batchJson(Object view) => {
        't': 'metrics',
        'seg': 's',
        'i': 0,
        'mode': 'dpad',
        'ms': 1,
        'data': <String, Object?>{},
        'view': view,
      };
      expect(
        () => codec.decode(
          jsonEncode({
            'v': protocolVersion,
            ...batchJson({'frames': '1', 'gaps': 0, 'late': 0}),
          }),
        ),
        throwsA(isA<ProtocolFormatException>()),
      );
      expect(
        () => codec.decode(jsonEncode({'v': protocolVersion, ...batchJson([])})),
        throwsA(isA<ProtocolFormatException>().having((e) => e.message, 'message', contains('"view"'))),
      );
    });
  });
}
