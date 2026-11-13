import 'dart:io';

import 'package:metrics/metrics.dart';
import 'package:test/test.dart';

/// A viewer whose page read the host's marker row (M15 fix8), written as the
/// player's marker batch writes it, with the f8-3 probe run's numbers:
///
/// * marker glass 368 ms at the callback (p95 379, 8 batches) and the marker's
///   own press 372 (p95 400, 39 presses);
/// * the card probe's press 238 (p95 386, 38 presses) and the stream chain's
///   total 567 (p95 599, 4 frames);
/// * the clock offset 3666.5 ms kept with a 10 ms uncertainty, so the check
///   allows max(25, 2 × 10) = 25 ms;
/// * 1205 frames read, 1200 readable, and five unreadable: two checksums, one
///   sync, one canvas and one other.
///
/// So the presses differ by 372 − 238 = 134 ms (a disagreement of 134 ms) and
/// the marker's glass is 368 − 567 = −199 ms from the chain's total.
Map<String, Object?> markerSession() => {
  'id': 'mark',
  'stream': {
    'viewers': [
      {
        'id': 'v1',
        'kind': StreamKind.browser,
        'platform': 'chrome',
        'stages': {
          StreamStage.capture: {'n': 8, 'median': 2, 'p95': 2, 'max': 2},
          StreamStage.encode: {'n': 8, 'median': 29, 'p95': 29, 'max': 29},
          StreamStage.total: {'n': 4, 'median': 567, 'p95': 599, 'max': 599, 'source': 'stages'},
          StreamStage.pressToScreen: {'n': 38, 'median': 238, 'p95': 386, 'max': 395, 'source': 'probe'},
          StreamMarker.glass: {'n': 8, 'median': 368, 'p95': 379, 'max': 379},
          StreamMarker.press: {'n': 39, 'median': 372, 'p95': 400, 'max': 407},
        },
        'gauges': {
          StreamMarker.offset: {'n': 8, 'mean': 3666.5, 'p95': 3666.5, 'max': 3666.5},
          StreamMarker.offsetUncertainty: {'n': 8, 'mean': 10, 'p95': 10, 'max': 10},
          StreamMarker.decodedDisplay: {'n': 8, 'mean': 186.56, 'p95': 292.2, 'max': 292.2},
        },
        'counters': {
          StreamMarker.frames: 1205,
          StreamMarker.readable: 1200,
          StreamMarker.checksumBad: 2,
          StreamMarker.syncBad: 1,
          StreamMarker.canvasBad: 1,
          StreamMarker.otherBad: 1,
        },
        'facts': {
          StreamMarker.displayFrom: 'expected-receive',
          'rvfc.presentationTime': '22.25 23.75 25.20',
          'rvfc.expectedDisplayTime': '22.25 23.76 25.20',
          'rvfc.receiveTime': '21.97 23.47 24.91',
          'rvfc.processingDuration': '0.9 2.4 8.3',
          'rvfc.presentedFrames': '1117 1199 1275',
          'rvfc.width': '1920 1920 1920',
          'rvfc.height': '1080 1080 1080',
          'rvfc.mediaTime': '20.84 22.35 23.81',
          'rvfc.rtpTimestamp': '0 135301 265009',
        },
      },
    ],
  },
};

/// [markerSession] with only the two presses and the offset's uncertainty, so
/// the verdict's edges can be asked directly: the marker's press [markerMs],
/// the card's [cardMs] and an uncertainty of [uncertaintyMs].
Map<String, Object?> pressSession(int markerMs, int cardMs, num uncertaintyMs) => {
  'id': 'edge',
  'stream': {
    'viewers': [
      {
        'id': 'v1',
        'kind': StreamKind.browser,
        'platform': 'chrome',
        'stages': {
          StreamStage.pressToScreen: {'n': 3, 'median': cardMs, 'p95': cardMs + 100, 'max': cardMs + 120},
          StreamMarker.press: {'n': 3, 'median': markerMs, 'p95': markerMs + 20, 'max': markerMs + 30},
        },
        'gauges': {
          StreamMarker.offsetUncertainty: {'n': 3, 'mean': uncertaintyMs, 'p95': uncertaintyMs, 'max': uncertaintyMs},
        },
        'counters': {StreamMarker.frames: 10},
      },
    ],
  },
};

/// A viewer whose page read no marker row: the stream chain's total and three
/// other stages, and nothing the marker wrote. This is job f8-4's fixture for
/// the report as it printed before the check existed.
Map<String, Object?> noMarkerSession() => {
  'id': 'plain',
  'stream': {
    'viewers': [
      {
        'id': 'v1',
        'kind': StreamKind.browser,
        'platform': 'chrome',
        'stages': {
          StreamStage.capture: {'n': 3, 'median': 2, 'p95': 4, 'max': 6},
          StreamStage.encode: {'n': 3, 'median': 10, 'p95': 12, 'max': 14},
          StreamStage.total: {'n': 3, 'median': 32, 'p95': 46, 'max': 52, 'source': 'stages'},
        },
        'gauges': {
          'lossPct': {'n': 2, 'mean': 0.5, 'p95': 0.7, 'max': 0.7},
        },
        'counters': {'framesReceived': 900},
      },
    ],
  },
};

/// The check's value, p95 and n after its label, the padding collapsed.
List<String> checkOf(String text, String check) {
  final at = text.indexOf(check);
  expect(at, isNonNegative, reason: 'the table has a "$check" row');
  return text.substring(at + check.length).split('\n').first.trim().split(RegExp(r'\s+'));
}

void main() {
  group('the independent check (M15 fix8)', () {
    test('the marker\'s numbers beside the card\'s, and what each pair differs by', () {
      final text = streamReport([markerSession()]);

      expect(text, contains('Independent check'));
      // 368/379 over 8 batches, 372/400 over 39 presses, 238/386 over 38, 567/599 over 4.
      expect(checkOf(text, 'marker glass'), ['368', '379', '8']);
      expect(checkOf(text, 'marker press>screen'), ['372', '400', '39']);
      expect(checkOf(text, 'press>screen (card)'), ['238', '386', '38']);
      expect(checkOf(text, 'stream total'), ['567', '599', '4']);
      // 372 − 238 = 134 ms, and 368 − 567 = −199 ms.
      expect(checkOf(text, 'presses differ'), ['134', '-', '-']);
      expect(checkOf(text, 'glass - total'), ['-199', '-', '-']);
      // The offset, its RTT/2 and the decoded-to-display mean, one decimal.
      expect(checkOf(text, 'clock offset'), ['3666.5', '3666.5', '8']);
      expect(checkOf(text, 'offset uncertainty'), ['10.0', '10.0', '8']);
      expect(checkOf(text, 'decoded to display'), ['186.6', '292.2', '8']);
      // 1200 of 1205 readable, and 2 + 1 + 1 + 1 = 5 unreadable by reason.
      expect(checkOf(text, 'frames read'), ['1205', '-', '-']);
      expect(checkOf(text, 'frames readable'), ['1200', '-', '-']);
      expect(checkOf(text, 'unreadable: checksum'), ['2', '-', '-']);
      expect(checkOf(text, 'unreadable: sync'), ['1', '-', '-']);
      expect(checkOf(text, 'unreadable: canvas'), ['1', '-', '-']);
      expect(checkOf(text, 'unreadable: other'), ['1', '-', '-']);
    });

    test('the verdict: agree under the allowance, DISAGREE by the gap over it', () {
      // |134| against max(25, 2 × 10) = 25 ms.
      expect(streamReport([markerSession()]), contains('DISAGREE by 134 ms (25.0 ms allowed)'));
      // A gap of 24 ms is under the 25 ms floor, 25 ms is not.
      expect(streamReport([pressSession(260, 236, 10)]), contains('agree (24 ms apart, 25.0 ms allowed)'));
      expect(streamReport([pressSession(261, 236, 10)]), contains('DISAGREE by 25 ms (25.0 ms allowed)'));
      // An uncertainty of 20 ms allows 2 × 20 = 40 ms instead of the floor.
      expect(streamReport([pressSession(275, 236, 20)]), contains('agree (39 ms apart, 40.0 ms allowed)'));
      expect(streamReport([pressSession(276, 236, 20)]), contains('DISAGREE by 40 ms (40.0 ms allowed)'));
      // The gap is signed in the table but compared as a size.
      expect(streamReport([pressSession(236, 276, 20)]), contains('DISAGREE by 40 ms'));
    });

    test('the browser\'s own fields: which it gave and which it left out', () {
      final text = streamReport([markerSession()]);

      expect(text, contains('mark/v1 rVFC: expected-receive'));
      expect(text, contains('provided presentationTime, expectedDisplayTime, receiveTime'));
      expect(text, contains('not provided captureTime'), reason: 'this headless Chrome has no captureTime');
    });

    test('a count the page never sent is a dash, not a zero', () {
      final session = markerSession();
      final viewer = ((session['stream'] as Map)['viewers'] as List).first as Map;
      (viewer['counters'] as Map).remove(StreamMarker.canvasBad);

      expect(checkOf(streamReport([session]), 'unreadable: canvas'), ['-', '-', '-']);
    });

    test('a run whose page read no marker row prints what it printed before', () {
      final text = streamReport([noMarkerSession()]);

      expect(text, isNot(contains('Independent check')));
      expect(text, isNot(contains('marker')));
      // The report the code printed before this table existed (this job's
      // fixture), so a run that read no marker row is byte for byte what it was.
      final fixture = File('test/fixtures/report_no_marker.txt').readAsStringSync();
      expect(text, fixture.replaceAll('\r\n', '\n'));
    });
  });
}
