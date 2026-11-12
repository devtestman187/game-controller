import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The host's own frame, for the automation interface's `GET screenshot`
/// (M15 a2). The shell wraps its app in [boundary], so the picture is exactly
/// what the screen draws, on every host that draws one.
///
/// A PNG is what a viewer, a demo video or a test compares against; it is the
/// same call on Windows, Linux, Android TV and a phone, and it returns null
/// only when there is no frame to take (the app not mounted yet, or a host in
/// the background that Flutter stopped drawing).
class ScreenFrames {
  /// The boundary the automation captures. The shell puts [boundary] above
  /// its app, and this keeps the one key every capture reads.
  final GlobalKey key = GlobalKey(debugLabel: 'automationFrame');

  /// [child], inside the boundary every capture reads.
  Widget boundary(Widget child) => RepaintBoundary(key: key, child: child);

  /// The frame now, as PNG bytes, or null when nothing is drawn.
  Future<Uint8List?> capturePng() async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
