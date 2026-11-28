/// The City Rush board drawn in the toy look (M17 map2a): districts, start tiles, road lanes and
/// the Centre Plaza, as a 2.5D sticker map. The board never changes during a night, so the
/// whole layer is drawn once per size into an image ([CityStaticCache]) and later frames only
/// copy that image.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:connection/connection.dart' show LogSink;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:toy_look/toy_look.dart';

import '../board.dart';
import 'city_layout.dart';

/// How wide a district's backing strip is, in tiles: wide enough to show a rim around the road.
const cityDistrictWidthTiles = 1.5;

/// How wide a road's lane is, in tiles: narrower than a tile, so it reads as a path between them.
const cityLaneWidthTiles = 0.4;

/// How deep a tile's side face is, as a share of the tile: what makes the flat map read as 2.5D.
const cityTileDepthShare = 0.12;

/// How round a tile's corners are, as a share of the tile.
const cityTileRadiusShare = 0.2;

/// How much bigger the Centre Plaza is than a road tile, so it stands out as where every road ends.
const cityPlazaScale = 1.25;

/// Draws one frame of the board, and the cached static layer behind it.
final class CityPainter extends CustomPainter {
  /// Paints [board] as [layout] places it, in [look]'s colours and shader. [cache] holds the
  /// finished static layer; the painter repaints when it finishes a build.
  CityPainter({required this.layout, required this.board, required this.look, required this.cache})
    : super(repaint: cache);

  /// Where everything sits.
  final CityLayout layout;

  /// The districts to draw.
  final Board board;

  /// The colours, outline width and shader to draw in; no shader means the Canvas fallback.
  final ToyLook look;

  /// The image of the static layer, built on the first paint of a size.
  final CityStaticCache cache;

  /// Draws the board. The layout must have been built for the paint [size]: a layout for another
  /// size would misplace every tile, so that is refused rather than drawn wrong.
  @override
  void paint(Canvas canvas, Size size) {
    assert(size == layout.size, 'The layout is for ${layout.size}, but the paint size is $size');
    final image = cache.imageFor(layout.size);
    if (image != null) {
      canvas.drawImage(image, Offset.zero, Paint());
      return;
    }
    // The first frame of a size has no image yet: draw the layer directly, once, and ask for
    // the image so the next frames don't.
    paintStatic(canvas);
    cache.request(layout.size, paintStatic);
  }

  /// Draws every static part of the board straight onto [canvas]: what the cache renders once.
  void paintStatic(Canvas canvas) {
    final style = ToyShapeStyle(ink: look.colors.ink, outlineWidth: look.sizes.outlineWidth);
    for (final district in board.districts) {
      _paintDistrict(canvas, district, style);
    }
    for (final district in board.districts) {
      _paintRoad(canvas, district, style);
    }
    final side = layout.tileSize * cityPlazaScale;
    _paintTile(
      canvas,
      Rect.fromCenter(center: layout.plazaCenter, width: side, height: side),
      look.colors.caution,
      style,
    );
  }

  void _paintDistrict(Canvas canvas, District district, ToyShapeStyle style) {
    final path = Path()
      ..moveTo(layout.tileCenter(district.id, 0).dx, layout.tileCenter(district.id, 0).dy)
      ..lineTo(layout.plazaCenter.dx, layout.plazaCenter.dy);
    final backing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = layout.tileSize * cityDistrictWidthTiles + style.outlineWidth * 2
      ..color = style.ink;
    canvas.drawPath(path, backing);
    canvas.drawPath(
      path,
      backing
        ..strokeWidth = layout.tileSize * cityDistrictWidthTiles
        ..color = look.colors.board,
    );
    canvas.drawPath(
      path,
      backing
        ..strokeWidth = layout.tileSize * cityLaneWidthTiles
        ..color = look.colors.tray,
    );
  }

  void _paintRoad(Canvas canvas, District district, ToyShapeStyle style) {
    final isCorner = district.laneOf == null;
    for (var i = 0; i < district.road.length - 1; i++) {
      final colour = i == 0 ? (isCorner ? look.colors.good : look.colors.focus) : look.colors.paper;
      _paintTile(canvas, layout.tileRect(district.id, i), colour, style);
    }
  }

  void _paintTile(Canvas canvas, Rect top, Color colour, ToyShapeStyle style) {
    final radius = Radius.circular(top.width * cityTileRadiusShare);
    final depth = Offset(0, top.width * cityTileDepthShare);
    final side = RRect.fromRectAndRadius(top.shift(depth), radius);
    canvas.drawRRect(side, Paint()..color = toyShadeOf(colour));
    toyShape(canvas, Path()..addRRect(RRect.fromRectAndRadius(top, radius)), colour, style, shade: look.shade);
  }

  @override
  bool shouldRepaint(CityPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.board != board ||
      oldDelegate.look != look ||
      oldDelegate.cache != cache;
}

/// Renders the board's static layer once per size into a [ui.Image] and keeps it.
///
/// The image comes from a [ui.PictureRecorder]; the [ui.Picture] is disposed as soon as it is
/// rendered, never kept. A new size builds a new image and drops the old one.
class CityStaticCache extends ChangeNotifier {
  /// A cache that reports a failed build to [log], when given.
  CityStaticCache({LogSink? log}) : _log = log ?? ((_) {});

  final LogSink _log;
  ui.Image? _image;
  Size? _imageSize;
  Size? _wantedSize;
  int _buildCount = 0;
  bool _isDisposed = false;

  /// How many times the static layer has been drawn into an image: one per size, for tests.
  int get buildCount => _buildCount;

  /// The cached image when it was built for [size], else null.
  ui.Image? imageFor(Size size) => _imageSize == size ? _image : null;

  /// Builds the image for [size] unless it is built or already being built. The build is
  /// started here and finishes later; [addListener] callbacks run when it has.
  void request(Size size, void Function(Canvas canvas) draw) {
    if (_imageSize == size || _wantedSize == size) return;
    unawaited(build(size, draw));
  }

  /// Draws [draw] into a new image of [size] and keeps it, replacing the one before. A build
  /// that a later size has overtaken is thrown away. Completes when the image is kept, or when
  /// the build failed: the failure is logged, no image is kept and a later [request] retries.
  Future<void> build(Size size, void Function(Canvas canvas) draw) async {
    _wantedSize = size;
    _buildCount++;
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = await picture.toImage(size.width.ceil(), size.height.ceil());
    } on Object catch (error) {
      // The engine can refuse an image (empty or too big a size); the board stays drawn directly.
      _log('City map image for $size failed: $error');
      if (_wantedSize == size) _wantedSize = null;
      return;
    } finally {
      picture.dispose();
    }
    if (_isDisposed || _wantedSize != size) {
      image.dispose();
      return;
    }
    _image?.dispose();
    _image = image;
    _imageSize = size;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}
