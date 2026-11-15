import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A summary of one player in one mode and one round, with the host's and the
/// phone's app versions. A null leaves the key out, as an older host's export
/// does.
Map<String, Object?> summary({String? hostApp = '0.12.0', String? app = '0.13.2'}) => {
  'schema': summarySchema,
  'id': 'a1',
  'host': {'type': 'windows', 'app': ?hostApp},
  'date': '2026-11-15',
  'durationS': 60,
  'players': [
    {
      'install': 'phone-a',
      'player': 1,
      'platform': 'android',
      'app': ?app,
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
  group('the stats CSV names the app builds', () {
    test('the header ends with host_app and app, so old columns keep their place', () {
      expect(ModeRow.csvHeader, endsWith(',host_app,app'));
      expect(ModeRow.csvHeader.split(','), hasLength(35)); // The 33 before, plus the two.
      expect(
        csv([summary()]).split('\n').first,
        'session,date,host,install,device,model,platform,mode,minutes,touches,presses,empty,near,slide,'
        'rapid,games,wins,good,okay,bad,early_switch,first_mode,input_median_ms,input_p95_ms,'
        'frustration_per_min,open_minutes,touch_median_ms,touch_p95_ms,jitter_median_ms,jitter_p95_ms,'
        'view_frames,view_gaps,view_late,host_app,app',
      );
    });

    test('a row ends with the host app and the player app', () {
      final fields = rowsOf(summary()).single.toCsv().split(',');
      expect(fields, hasLength(35));
      expect(fields.sublist(33), ['0.12.0', '0.13.2']);
      expect(csv([summary()]).split('\n').last, endsWith(',0.12.0,0.13.2'));
    });

    test('a summary with no app leaves both cells empty, never a crash', () {
      final fields = rowsOf(summary(hostApp: null, app: null)).single.toCsv().split(',');
      expect(fields, hasLength(35));
      expect(fields.sublist(33), ['', '']);
      expect(csv([summary(hostApp: null, app: null)]).split('\n').last, endsWith(',,'));
    });
  });

  group('the round CSV names the host app', () {
    test('host_app is the tenth column, where a1 put it', () {
      expect(roundsCsvHeader.split(',')[9], 'host_app');
    });

    test('a round row carries the host app', () {
      final lines = csvRounds([summary()]).split('\n');
      expect(
        lines.first,
        'session,host,game,hz,time_s,battery_start,battery_end,thermal,tags,host_app,winner,'
        'draw,players,frames_drawn,frames_late,fps,start_s',
      );
      // 60 s at 60 Hz, with no battery reading, no tags and no winner (M14 a2).
      expect(lines.last, 'a1,windows,arena,60,60.0,,,,,0.12.0,,,,,,,');
    });

    test('a summary with no app leaves the cell empty', () {
      expect(csvRounds([summary(hostApp: null)]).split('\n').last, 'a1,windows,arena,60,60.0,,,,,,,,,,,,');
    });
  });
}
