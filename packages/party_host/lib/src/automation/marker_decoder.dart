import 'marker_code.dart';

/// The luminance below which a cell reads as black, after the cell's 3x3
/// centre average: docs/streaming-marker.md's rule, which survives H.264 at
/// the session's bitrate and a blur. A cell in between is unreadable.
const markerDarkBelow = 80;

/// The luminance above which a cell reads as white, after the same average.
const markerLightAbove = 160;

/// Reads the marker out of [pixels], the row's own crop of a picture: its rows
/// of luminance, 0 (black) to 255 (white), the first row at the top.
///
/// The crop is cut into [markerCellCount] columns of equal width, and each cell
/// is read from the mean of the 3x3 pixels at its centre, as the page's reader
/// does (docs/streaming-marker.md); the row's height may be one cell or more,
/// and its middle row is the one read. A cell between [markerDarkBelow] and
/// [markerLightAbove] makes the whole row unreadable rather than a guess.
MarkerRead decodeMarker(List<List<int>> pixels) {
  if (pixels.isEmpty || pixels.first.isEmpty) return const MarkerRead.unreadable('the crop is empty');
  final widthPx = pixels.first.length;
  if (widthPx < markerCellCount) {
    return MarkerRead.unreadable('the crop is $widthPx px wide, too narrow for $markerCellCount cells');
  }
  final cellPx = widthPx ~/ markerCellCount;
  final centreY = pixels.length ~/ 2;
  final lights = <bool>[];
  for (var cell = 0; cell < markerCellCount; cell++) {
    final level = _centreMean(pixels, cell * cellPx + cellPx ~/ 2, centreY);
    if (level < markerDarkBelow) {
      lights.add(false);
    } else if (level > markerLightAbove) {
      lights.add(true);
    } else {
      return MarkerRead.unreadable('the cell at $cell is neither black nor white ($level)');
    }
  }
  for (var border = 0; border < markerBorderCells; border++) {
    if (!lights[border] || !lights[markerCellCount - 1 - border]) {
      return MarkerRead.unreadable('the border cells are not light at cell $border');
    }
  }
  return decodeMarkerCells(lights.sublist(markerBorderCells, markerCellCount - markerBorderCells));
}

/// The mean luminance of the 3x3 pixels centred on [x], [y], over the pixels the
/// crop has (a centre on the crop's edge averages what is there).
int _centreMean(List<List<int>> pixels, int x, int y) {
  var sum = 0;
  var count = 0;
  for (var dy = -1; dy <= 1; dy++) {
    final row = y + dy;
    if (row < 0 || row >= pixels.length) continue;
    for (var dx = -1; dx <= 1; dx++) {
      final column = x + dx;
      if (column < 0 || column >= pixels[row].length) continue;
      sum += pixels[row][column];
      count++;
    }
  }
  return (sum / count).round();
}
