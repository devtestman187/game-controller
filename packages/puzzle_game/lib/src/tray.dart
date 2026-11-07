import 'dart:math';
import 'dart:ui';

import 'puzzle.dart';

/// The gap a tray's packing leaves at its edges and between its rows, in
/// world units; a layout that sizes a tray to its pieces adds it to the
/// pieces' extent on each side.
const trayGap = 2.0;

/// Packs pieces into a tray [width] wide, tallest box first, in rows from the
/// left with a gap of [trayGap] at the edges and between rows. Each piece
/// after the first in a row starts [overlap] of the previous box's width
/// before that box's right edge (overlap 0: a [trayGap] after it instead); a
/// new row starts when the box would pass width - 2. With overlap > 0, a
/// piece's overlap is reduced in steps of 0.05 (down to 0) while any piece
/// already placed would be left less than 55% visible (sample each placed
/// piece's shape on a 0.5 grid; a point is hidden when a later piece's shape
/// contains it). Returns each piece's box position (top left, relative to the
/// tray's top left), the packing order (bottom to top) and the height used.
({Map<int, Offset> at, List<int> order, double height}) packTray(
  Puzzle puzzle,
  Map<int, double> angles,
  double width, {
  double overlap = 0,
  double scale = 1,
}) {
  final shapes = [for (final spec in puzzle.pieces) spec.shape];
  final boxes = [for (final (i, spec) in puzzle.pieces.indexed) _scaledBox(spec.shape.bounds(angles[i]!), scale)];
  final order = [for (var i = 0; i < puzzle.pieces.length; i++) i]
    ..sort((a, b) {
      final byHeight = boxes[b].height.compareTo(boxes[a].height);
      return byHeight != 0 ? byHeight : a.compareTo(b);
    });

  // Each piece's shape sampled on a 0.5 grid inside its box, relative to its
  // centre: the points its visibility is measured on. They depend only on the
  // shape, its angle and the scale, so they're kept between calls (the split
  // layout packs the same pieces at many tray widths).
  final samples = <int, List<Offset>>{};
  List<Offset> samplesOf(int i) =>
      samples[i] ??= ((_samples[shapes[i]] ??= {})[(angles[i]!, scale)] ??= _sample(shapes[i], angles[i]!, scale));

  final at = <int, Offset>{}; // each box's top left
  final centres = <int, Offset>{}; // each piece's centre
  final row = <int>[];
  final total = <int, int>{}; // sampled points
  final visible = <int, int>{}; // points still in view
  var y = trayGap;
  var rowHeight = 0.0;

  /// How many of [p]'s points a piece at [boxTopLeft] hides, and whether that
  /// would leave any piece already in the row below 55% visible.
  ({Map<int, int> hidden, bool tooMuch}) hideAt(int q, Offset boxTopLeft) {
    final rect = Rect.fromLTWH(boxTopLeft.dx, boxTopLeft.dy, boxes[q].width, boxes[q].height);
    final shape = shapes[q];
    final centre = boxTopLeft - boxes[q].topLeft;
    final polygon = shape.circle ? null : _scaledPlaced(shape, centre, angles[q]!, scale);
    final hidden = <int, int>{};
    var tooMuch = false;
    for (final p in row) {
      final rectP = Rect.fromLTWH(at[p]!.dx, at[p]!.dy, boxes[p].width, boxes[p].height);
      if (!rectP.overlaps(rect)) continue;
      var count = 0;
      for (final local in samplesOf(p)) {
        final point = centres[p]! + local;
        if (!rect.contains(point)) continue;
        final inside = polygon == null ? (point - centre).distance <= shape.radius * scale : _inside(polygon, point);
        if (inside) count++;
      }
      hidden[p] = count;
      if (visible[p]! - count < total[p]! * 0.55) tooMuch = true;
    }
    return (hidden: hidden, tooMuch: tooMuch);
  }

  for (final i in order) {
    final box = boxes[i];
    var place = Offset(trayGap, y);
    if (row.isNotEmpty) {
      final prev = row.last;
      final prevBox = boxes[prev];
      // The left edge for a piece overlapping the box before it by [o].
      Offset leftAt(double o) =>
          Offset(o > 0 ? at[prev]!.dx + prevBox.width * (1 - o) : at[prev]!.dx + prevBox.width + trayGap, y);

      var hidden = <int, int>{};
      var wrap = false;
      var o = overlap;
      place = leftAt(o);
      var check = place.dx + box.width > width - trayGap;
      while (!check) {
        final result = hideAt(i, place);
        if (!result.tooMuch) {
          hidden = result.hidden;
          break;
        }
        if (o <= 0) {
          // Even without overlap another piece in the row would be hidden:
          // start a new row instead.
          check = true;
          break;
        }
        o = max(0, o - 0.05);
        place = leftAt(o);
        check = place.dx + box.width > width - trayGap;
      }
      if (check) {
        wrap = true;
      } else if (hidden.isNotEmpty) {
        for (final MapEntry(:key, :value) in hidden.entries) {
          visible[key] = visible[key]! - value;
        }
      }
      if (wrap) {
        row.clear();
        y += rowHeight + trayGap;
        rowHeight = 0;
        place = Offset(trayGap, y);
      }
    }
    at[i] = place;
    centres[i] = place - box.topLeft;
    row.add(i);
    rowHeight = max(rowHeight, box.height);
    total[i] = samplesOf(i).length;
    visible[i] = total[i]!;
  }
  return (at: at, order: order, height: y + rowHeight + trayGap);
}

/// Sampled shapes, by shape, then angle and scale.
final _samples = Expando<Map<(double, double), List<Offset>>>('tray samples');

List<Offset> _sample(PieceShape shape, double angle, double scale) {
  final box = _scaledBox(shape.bounds(angle), scale);
  final points = <Offset>[];
  for (var x = box.left; x < box.right; x += 0.5) {
    for (var y = box.top; y < box.bottom; y += 0.5) {
      final point = Offset(x, y);
      if (shape.contains(point, Offset.zero, angle, scale: scale)) points.add(point);
    }
  }
  return List.unmodifiable(points);
}

Rect _scaledBox(Rect box, double scale) =>
    scale == 1 ? box : Rect.fromLTRB(box.left * scale, box.top * scale, box.right * scale, box.bottom * scale);

/// The shape's corners placed at [at], turned by [angle] and scaled about
/// [at].
List<Offset> _scaledPlaced(PieceShape shape, Offset at, double angle, double scale) {
  final points = shape.placed(at, angle);
  if (scale == 1) return points;
  return [for (final p in points) at + (p - at) * scale];
}

/// Whether [point] is inside the polygon [points] (the even-odd rule).
bool _inside(List<Offset> points, Offset point) {
  var inside = false;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    if ((a.dy > point.dy) != (b.dy > point.dy) && point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}
