import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/automation/marker_code.dart';

/// A value as the 55 content cells it encodes to, written as one string of 0
/// and 1, most significant cell first: the form docs/streaming-marker.md's
/// vector table uses, so the Dart and the page's JS tests read the same rows.
String cellsOf(int counter, int hostMs, bool pressFlip) =>
    encodeMarker(counter: counter, hostMs: hostMs, pressFlip: pressFlip).map((cell) => cell ? '1' : '0').join();

/// The spec's own vectors (docs/streaming-marker.md, "Test vectors"): counter,
/// clock, press flip and the cells they spell.
const vectors = <(int, int, bool, String)>[
  (0, 0, false, '1000000000000000000000000000000000000000000000000000000'),
  (1, 1, true, '1000000000000000010000000000000000000000000000000110001'),
  (0xABCD, 0x01234567, false, '1010101011110011010000000100100011010001010110011100000'),
  (0xFFFF, 0xFFFFFFFF, true, '1011111111111111111111111111111111111111111111111110001'),
  (0x0001, 0x00000002, false, '1000000000000000010000000000000000000000000000001000011'),
  (12345, 987654321, true, '1000110000001110010011101011011110011010001011000110110'),
];

void main() {
  test('a row is the spec\'s 55 cells: sync, counter, clock, press flip, checksum', () {
    final cells = encodeMarker(counter: 0, hostMs: 0, pressFlip: false);
    expect(cells.length, 55, reason: '2 sync + 16 counter + 32 clock + 1 flip + 4 checksum');
    expect(cells.take(2), [true, false], reason: 'the sync cells are light then dark');
    expect(cells.length, markerValueCells);
    expect(markerCellCount, 57, reason: 'and one light border cell at each end');
  });

  test('the spec\'s vectors encode to the cells the page reads', () {
    for (final (counter, hostMs, pressFlip, expected) in vectors) {
      expect(cellsOf(counter, hostMs, pressFlip), expected, reason: 'counter $counter, clock $hostMs, flip $pressFlip');
      expect(
        decodeMarkerCells(encodeMarker(counter: counter, hostMs: hostMs, pressFlip: pressFlip)).reading,
        MarkerReading(counter: counter, hostMs: hostMs, pressFlip: pressFlip),
      );
    }
  });

  test('every value round trips, the whole clock and counter range included', () {
    final cases = <(int, int, bool)>[
      (0, 0, false),
      (0, 0xFFFFFFFF, true),
      (0xFFFF, 0, false),
      (0xFFFF, 0xFFFFFFFF, true),
    ];
    for (var i = 0; i < 500; i++) {
      cases.add((i * 7919 % markerCounterWrap, i * 104729 % markerHostMsWrap, i.isOdd));
    }
    for (final (counter, hostMs, pressFlip) in cases) {
      final read = decodeMarkerCells(encodeMarker(counter: counter, hostMs: hostMs, pressFlip: pressFlip));
      expect(read.reading, MarkerReading(counter: counter, hostMs: hostMs, pressFlip: pressFlip));
    }
  });

  test('a checksum that does not match is unreadable, never a guess', () {
    final cells = encodeMarker(counter: 42, hostMs: 1000, pressFlip: false);
    cells[markerChecksumIndex] = !cells[markerChecksumIndex];
    final read = decodeMarkerCells(cells);
    expect(read.isReadable, isFalse);
    expect(read.problem, contains('checksum'));
  });

  test('sync cells that are not light then dark make the row unreadable', () {
    final cells = encodeMarker(counter: 42, hostMs: 1000, pressFlip: false);
    cells[markerSyncIndex] = false;
    expect(decodeMarkerCells(cells).problem, contains('sync'));
    cells[markerSyncIndex] = true;
    cells[markerSyncIndex + 1] = true;
    expect(decodeMarkerCells(cells).problem, contains('sync'));
    expect(decodeMarkerCells(cells.sublist(1)).problem, contains('content cells'));
  });

  test('the counter wraps at 16 bits and the clock keeps its low 32', () {
    final cells = encodeMarker(counter: markerCounterWrap + 3, hostMs: markerHostMsWrap + 5, pressFlip: false);
    final read = decodeMarkerCells(cells).reading;
    expect(read?.counter, 3, reason: 'a 16-bit counter, so 65539 is 3');
    expect(read?.hostMs, 5, reason: 'the low 32 bits of the host clock');
    expect(cellsOf(markerCounterWrap + 3, markerHostMsWrap + 5, false), cellsOf(3, 5, false));
  });
}
