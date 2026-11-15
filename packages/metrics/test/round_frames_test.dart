import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A session with one phone in it, so a round has a player to count.
SessionCollector collector() => SessionCollector(
  id: 's1',
  hostType: HostType.windows,
  hostApp: '0.15.0',
  startedAt: DateTime.utc(2026, 11, 15),
  startMs: 0,
)..joined('phone-a', number: 1, atMs: 0);

/// A session with one 60 s arena round at 60 Hz, played by one phone.
SessionCollector round() => collector()
  ..roundStarted(hz: 60)
  ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'});

/// The one round of [c]'s summary, as the report reads it.
Map roundOf(SessionCollector c) => (c.summary(1000)['rounds'] as List).single as Map;

/// [c]'s session totals for frames, as the summary keeps them.
Map framesOf(SessionCollector c) => c.summary(1000)['frames'] as Map;

/// The last line of [c]'s rounds CSV: its one round's row.
String rowOf(SessionCollector c) => csvRounds([c.summary(1000)]).split('\n').last;

void main() {
  test('the frames a game records after its round_end are that round\'s too', () {
    // The arena records round_end, then frames, then resets the counts
    // (arena_session step): the counts are the round's.
    final c = round()..frames(3000, 20);
    expect(roundOf(c), {'game': 'arena', 'hz': 60, 'timeS': 60.0, 'players': 1, 'framesDrawn': 3000, 'framesLate': 20});
    expect(framesOf(c), {'drawn': 3000, 'dropped': 20});
  });

  test('a second frames record after the same round adds to the session only', () {
    // Only the first record after a round_end belongs to the round.
    final c = round()
      ..frames(3000, 20)
      ..frames(100, 5);
    expect(roundOf(c)['framesDrawn'], 3000);
    expect(roundOf(c)['framesLate'], 20);
    expect(framesOf(c), {'drawn': 3100, 'dropped': 25});
  });

  test('an abandoned round takes no frames, since it has no round', () {
    final c = collector()
      ..roundStarted(hz: 60)
      ..roundEnded('arena', timeS: 60, modes: {'phone-a': 'dpad'}, abandoned: true)
      ..frames(500, 9);
    expect(c.summary(1000)['rounds'], isEmpty);
    expect(framesOf(c), {'drawn': 500, 'dropped': 9});
  });

  test('frames recorded with no round before them stay session totals', () {
    final c = collector()..frames(120, 3);
    expect(c.summary(1000)['rounds'], isEmpty);
    expect(framesOf(c), {'drawn': 120, 'dropped': 3});
  });

  test('the rounds CSV has the frames, the fps and the start offset after players', () {
    expect(roundsCsvHeader, endsWith(',players,frames_drawn,frames_late,fps,start_s,host_build'));
    // The 13 before, the three, the start offset and the host build (M14 stats).
    expect(roundsCsvHeader.split(','), hasLength(18));
  });

  test('a round row carries its frames and the fps it drew', () {
    // 3000 frames in 60 s: 50 a second.
    expect(rowOf(round()..frames(3000, 20)), 's1,windows,arena,60,60.0,,,,,0.15.0,,,1,3000,20,50.0,,');
  });

  test('the fps is the round\'s frames a second, to one decimal', () {
    final c = collector()
      ..roundStarted(hz: 60)
      ..roundEnded('arena', timeS: 12.5, modes: {'phone-a': 'dpad'})
      ..frames(830, 4);
    // 830 / 12.5 = 66.4.
    expect(rowOf(c).split(',').sublist(13, 16), ['830', '4', '66.4']);
  });

  test('a round that took no time has its frames but no fps', () {
    final c = collector()
      ..roundStarted(hz: 60)
      ..roundEnded('arena', timeS: 0, modes: {'phone-a': 'dpad'})
      ..frames(40, 1);
    expect(rowOf(c), 's1,windows,arena,60,0.0,,,,,0.15.0,,,1,40,1,,,');
  });

  test('a round from before the frames were kept leaves the three cells empty', () {
    final old = <String, Object?>{
      'id': 's1',
      'host': {'type': 'windows', 'app': '0.14.0'},
      'rounds': [
        {'game': 'arena', 'hz': 60, 'timeS': 12.5, 'players': 1},
      ],
    };
    expect(csvRounds([old]).split('\n').last, 's1,windows,arena,60,12.5,,,,,0.14.0,,,1,,,,,');
  });
}
