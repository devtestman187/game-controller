import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../automation/automation_providers.dart';
import '../automation/marker_code.dart';
import '../providers.dart';

/// The black a marker cell reads as 0 with: pure, not the look's ink, because
/// the page's thresholds are luminance and the picture is encoded.
const markerDarkColor = Color(0xFF000000);

/// The white a marker cell reads as 1 with.
const markerLightColor = Color(0xFFFFFFFF);

/// The marker row over the picture (M15 fix8): the bench's second, independent
/// measurement, drawn into the very frame the game draws, so a player page
/// reads a frame's number, the host's clock and a probe press out of the video
/// (docs/streaming-marker.md).
///
/// `AutomationShell` mounts it only when the launch's `THUMBPARTY_MARKER` said
/// on; no ordinary run and no phone build has the strip at all. A ticker asks
/// for a frame while it is up, so every frame the app draws carries the row.
class MarkerStrip extends ConsumerStatefulWidget {
  const MarkerStrip({super.key});

  @override
  ConsumerState<MarkerStrip> createState() => _MarkerStripState();
}

class _MarkerStripState extends ConsumerState<MarkerStrip> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// The frame counter: one per frame the strip was drawn in, wrapping at
  /// [markerCounterWrap].
  var _counter = 0;

  /// The host's clock when this frame's build began, in ms, low
  /// [markerHostMsBits] bits kept.
  var _hostMs = 0;

  /// Whether the press-flip cell is light: it flips on the frame a probe press
  /// was applied in, and holds until the next press.
  var _pressFlip = false;

  @override
  void initState() {
    super.initState();
    _hostMs = ref.read(gameHostProvider).nowMs % markerHostMsWrap;
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// One frame: the counter and the host's clock are stamped at the start of
  /// the frame's build, and drawn in that same frame (docs/streaming-marker.md
  /// says what lies between the stamp and the glass).
  void _tick(Duration _) {
    final atMs = ref.read(gameHostProvider).nowMs;
    setState(() {
      _counter = (_counter + 1) % markerCounterWrap;
      _hostMs = atMs % markerHostMsWrap;
    });
  }

  @override
  Widget build(BuildContext context) {
    // A probe press flips the cell in the frame it lands in, on the same
    // provider the latency card flips on (M15 c2).
    ref.listen(automationProbeFlipProvider, (previous, next) {
      if (next > (previous ?? 0)) setState(() => _pressFlip = !_pressFlip);
    });
    final cells = encodeMarker(counter: _counter, hostMs: _hostMs, pressFlip: _pressFlip);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A cell is 16 px at a 1920 px picture, and the page scales the same
          // way (docs/streaming-marker.md).
          final cellPx = constraints.maxWidth * markerCellPx / markerReferenceWidthPx;
          return Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              child: SizedBox(
                width: cellPx * markerCellCount,
                height: cellPx,
                child: CustomPaint(painter: MarkerPainter(cells: cells)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Paints one row of the marker: the black background (which is every 0 cell),
/// the two light border cells and the frame's own cells.
class MarkerPainter extends CustomPainter {
  MarkerPainter({required this.cells});

  /// The frame's content cells, most significant first, as [encodeMarker]
  /// makes them.
  final List<bool> cells;

  @override
  void paint(Canvas canvas, Size size) {
    final cellPx = size.width / markerCellCount;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = markerDarkColor);
    final light = Paint()..color = markerLightColor;
    for (var cell = 0; cell < markerCellCount; cell++) {
      if (!_isLight(cell)) continue;
      canvas.drawRect(Rect.fromLTRB(cell * cellPx, 0, (cell + 1) * cellPx, size.height), light);
    }
  }

  /// Whether cell [index] of the row is light: the border cells always are, and
  /// the content cells are [cells].
  bool _isLight(int index) {
    if (index < markerBorderCells || index >= markerBorderCells + markerValueCells) return true;
    return cells[index - markerBorderCells];
  }

  @override
  bool shouldRepaint(MarkerPainter oldDelegate) => !listEquals(cells, oldDelegate.cells);
}
