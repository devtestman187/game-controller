import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'look.dart';

/// [child] drawn in a box of [box] inside a window of [window], as a PNG
/// file's bytes, in [look]'s colours: what `tools/level.sh render` writes.
Future<Uint8List> capturePng(
  WidgetTester tester,
  Widget child, {
  required Size window,
  required Size box,
  ToyLook? look,
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: withLook(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(size: box, child: child),
          ),
        ),
        look: look,
      ),
    ),
  );
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
  return bytes.buffer.asUint8List();
}
