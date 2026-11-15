import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A summary of one player in one mode and one round. Its app versions may
/// hold a comma: session.dart's `_technical` keeps one (a model such as
/// "iPhone15,2" has it), so a peer's app string such as "1.0,2" reaches the
/// summary as written.
Map<String, Object?> summary({String hostApp = '0.12.0', String app = '0.13.2'}) => {
  'schema': summarySchema,
  'id': 'a1',
  'host': {'type': 'windows', 'app': hostApp},
  'date': '2026-11-15',
  'durationS': 60,
  'players': [
    {
      'install': 'phone-a',
      'player': 1,
      'platform': 'android',
      'app': app,
      'modes': {
        'dpad': {'ms': 60000, 'activeMs': 60000},
      },
      'segments': [
        {
          'id': 's1',
          'mode': 'dpad',
          'ms': 60000,
          'activeMs': 60000,
          'ended': true,
          'data': {'start': 0},
        },
      ],
      'ratings': [],
    },
  ],
  'rounds': [
    {'game': 'arena', 'hz': 60, 'timeS': 60.0},
  ],
  'frames': {'drawn': 0, 'dropped': 0},
};

void main() {
  group('an app version with a comma stays one cell', () {
    test('the stats CSV row has as many fields as its header', () {
      final lines = csv([summary(app: '1.0,2')]).split('\n');
      expect(lines.first.split(','), hasLength(35));
      expect(lines.last.split(','), hasLength(35));
      expect(lines.last, endsWith(',0.12.0,1.0;2'));
    });

    test('the rounds CSV row has as many fields as its header', () {
      final lines = csvRounds([summary(hostApp: '1.0,2')]).split('\n');
      expect(lines.first.split(','), hasLength(17));
      expect(lines.last.split(','), hasLength(17));
      expect(lines.last.split(',')[9], '1.0;2');
    });
  });
}
