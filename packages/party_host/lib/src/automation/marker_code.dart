/// The host's marker (M15 fix8): the row of cells the host draws in the
/// top-left corner of its picture, so a viewer can read a frame's number, the
/// host's clock and whether a probe press was applied out of the video itself.
///
/// [docs/streaming-marker.md] is the spec both sides follow; this file is its
/// pure half (the cell order, the checksum and the bits), with no Flutter in
/// it, so the encoder, the reference decoder and the player page's JS are
/// checked against one table of test vectors.
library;

/// The picture width the cell size is given at, in px: a picture of another
/// width scales every cell by its width over this one, as the decoder does.
const markerReferenceWidthPx = 1920;

/// One cell's side at [markerReferenceWidthPx], in px: large enough that H.264
/// at the session's 10 Mbit/s keeps its edges (docs/streaming-marker.md).
const markerCellPx = 16;

/// The light cells that frame the row at each end, with the black cells beside
/// them: they say where the row starts and that it was read at the right size.
const markerBorderCells = 1;

/// The two sync cells: light then dark, the row's start mark.
const markerSyncCells = 2;

/// The bits of the frame counter: it wraps at [markerCounterWrap].
const markerCounterBits = 16;

/// The bits of the host clock the row carries: its low 32.
const markerHostMsBits = 32;

/// The cell that flips colour on the frame a probe press was applied in.
const markerPressFlipCells = 1;

/// The bits of the checksum.
const markerChecksumBits = 4;

/// The cells a frame's content fills, borders aside: 55.
const markerValueCells =
    markerSyncCells + markerCounterBits + markerHostMsBits + markerPressFlipCells + markerChecksumBits;

/// Every cell of the row, the two border cells included: 57.
const markerCellCount = markerValueCells + 2 * markerBorderCells;

/// The frame counter's wrap: a 16-bit count, so a long run reuses numbers.
const markerCounterWrap = 1 << markerCounterBits;

/// The clock's wrap: the row carries the low 32 bits of the host's clock.
const markerHostMsWrap = 1 << markerHostMsBits;

/// The first sync cell's index in [markerValueCells] (the borders are not in
/// it).
const markerSyncIndex = 0;

/// The first counter cell's index in [markerValueCells].
const markerCounterIndex = markerSyncIndex + markerSyncCells;

/// The first clock cell's index in [markerValueCells].
const markerHostMsIndex = markerCounterIndex + markerCounterBits;

/// The press-flip cell's index in [markerValueCells].
const markerPressFlipIndex = markerHostMsIndex + markerHostMsBits;

/// The first checksum cell's index in [markerValueCells].
const markerChecksumIndex = markerPressFlipIndex + markerPressFlipCells;

/// What one frame's row says: its counter, the host clock it was stamped with
/// and the press flip at that moment.
final class MarkerReading {
  const MarkerReading({required this.counter, required this.hostMs, required this.pressFlip});

  /// The frame counter, 0 to [markerCounterWrap] - 1; it wraps.
  final int counter;

  /// The low 32 bits of the host's clock in ms, as the press probe stamps a
  /// press (M15 c2).
  final int hostMs;

  /// Whether the press-flip cell was light: it flips on the frame a probe
  /// press was applied in.
  final bool pressFlip;

  @override
  bool operator ==(Object other) =>
      other is MarkerReading && other.counter == counter && other.hostMs == hostMs && other.pressFlip == pressFlip;

  @override
  int get hashCode => Object.hash(counter, hostMs, pressFlip);

  @override
  String toString() => 'MarkerReading(counter: $counter, hostMs: $hostMs, pressFlip: $pressFlip)';
}

/// What a row says: the frame it carries, or why it could not be read. A
/// checksum that does not match is [problem], never a guess (M15 fix8).
final class MarkerRead {
  const MarkerRead.reading(MarkerReading this.reading) : problem = null;

  const MarkerRead.unreadable(String this.problem) : reading = null;

  /// The frame the row carries, or null when it is unreadable.
  final MarkerReading? reading;

  /// Why the row could not be read: a mid-grey cell, the wrong sync cells or a
  /// checksum mismatch.
  final String? problem;

  /// Whether [reading] is a value the checksum vouched for.
  bool get isReadable => reading != null;
}

/// One frame's content cells, most significant bit first: the two sync cells,
/// the counter, the clock, the press flip and the checksum. Light is true; the
/// border cells are not in it.
List<bool> encodeMarker({required int counter, required int hostMs, required bool pressFlip}) {
  final cells = <bool>[true, false];
  _appendBits(cells, counter & (markerCounterWrap - 1), markerCounterBits);
  _appendBits(cells, hostMs & (markerHostMsWrap - 1), markerHostMsBits);
  cells.add(pressFlip);
  _appendBits(cells, markerChecksum(counter: counter, hostMs: hostMs, pressFlip: pressFlip), markerChecksumBits);
  return cells;
}

/// The checksum of one frame: the xor of every nibble of the counter and the
/// clock, with the press flip as the lowest bit of the lowest nibble.
int markerChecksum({required int counter, required int hostMs, required bool pressFlip}) {
  var sum = pressFlip ? 1 : 0;
  var value = (counter & (markerCounterWrap - 1)) << markerHostMsBits | (hostMs & (markerHostMsWrap - 1));
  for (var nibble = 0; nibble < (markerCounterBits + markerHostMsBits) ~/ markerChecksumBits; nibble++) {
    sum ^= value & _nibbleMask;
    value >>= markerChecksumBits;
  }
  return sum;
}

/// The frame [cells] carries, or why they cannot be one: a short or long row,
/// the wrong sync cells, or a checksum that does not match. [cells] are the
/// content cells only ([markerValueCells] of them), most significant first.
MarkerRead decodeMarkerCells(List<bool> cells) {
  if (cells.length != markerValueCells) {
    return MarkerRead.unreadable('the row has ${cells.length} content cells, not $markerValueCells');
  }
  if (!cells[markerSyncIndex] || cells[markerSyncIndex + 1]) {
    return const MarkerRead.unreadable('the sync cells are not light then dark');
  }
  final counter = _valueAt(cells, markerCounterIndex, markerCounterBits);
  final hostMs = _valueAt(cells, markerHostMsIndex, markerHostMsBits);
  final pressFlip = cells[markerPressFlipIndex];
  final checksum = _valueAt(cells, markerChecksumIndex, markerChecksumBits);
  if (checksum != markerChecksum(counter: counter, hostMs: hostMs, pressFlip: pressFlip)) {
    return const MarkerRead.unreadable('the checksum does not match');
  }
  return MarkerRead.reading(MarkerReading(counter: counter, hostMs: hostMs, pressFlip: pressFlip));
}

/// The bits one nibble of the checksum's xor covers.
const _nibbleMask = (1 << markerChecksumBits) - 1;

/// Adds [bits] of [value], most significant first.
void _appendBits(List<bool> cells, int value, int bits) {
  for (var i = bits - 1; i >= 0; i--) {
    cells.add(value & (1 << i) != 0);
  }
}

/// The number [bits] cells of [cells] hold from [start], most significant
/// first.
int _valueAt(List<bool> cells, int start, int bits) {
  var value = 0;
  for (var i = 0; i < bits; i++) {
    value = value << 1 | (cells[start + i] ? 1 : 0);
  }
  return value;
}
