import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [child] drawn in a box of [box] inside a window of [window], as an image at
/// [pixelRatio].
Future<ui.Image> captureImage(
  WidgetTester tester,
  Widget child, {
  required Size window,
  required Size box,
  double pixelRatio = 1,
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(size: box, child: child),
        ),
      ),
    ),
  );
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() => boundary.toImage(pixelRatio: pixelRatio)))!;
}

/// Draws [child] in a box of [box] inside a window of [window], and returns
/// the box's pixels at [pixelRatio]: the width, the height and the raw RGBA
/// bytes.
Future<(int, int, Uint8List)> capture(
  WidgetTester tester,
  Widget child, {
  required Size window,
  required Size box,
  double pixelRatio = 1,
}) async {
  final image = await captureImage(tester, child, window: window, box: box, pixelRatio: pixelRatio);
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return (image.width, image.height, bytes.buffer.asUint8List());
}

/// The same frame as a PNG file's bytes.
Future<Uint8List> capturePng(WidgetTester tester, Widget child, {required Size window, required Size box}) async {
  final image = await captureImage(tester, child, window: window, box: box);
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
  return bytes.buffer.asUint8List();
}

/// The average difference per colour channel, 0 to 255.
double difference(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / a.length;
}

/// The colour at ([x], [y]) in a frame of [width] px, as 0xRRGGBB.
int pixel(Uint8List bytes, int width, int x, int y) {
  final i = 4 * (y * width + x);
  return bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2];
}
