import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/map_files.dart';
import 'support/map_sheet.dart';

/// The flags a map draws (M14 bug B-007): a pennant whose foot stands at a
/// wall, or in front of a post, must be drawn over it, or its pole and cloth
/// vanish behind the wall's fill as Block Castle's two bottom flags did. Every
/// map in the library is painted as the TV paints a round's field, and each
/// flag's pole is checked where the cloth cannot reach.
const mapBox = Size(320, 180);

/// How far up a flag's pole the check sits, as a share of the piece's own size
/// (its pole is 1.25 of it): low enough to clear the cloth, which hangs from
/// the pole's top down to about 0.83 of it, and the top of a post a flag may
/// stand on, and high enough that a wall at the foot would hide it.
const poleCheckShare = 0.75;

/// How far a pole's pixel may sit from the look's ink: a stroke's core pixel is
/// the ink itself, while a wall's fill is a token of its own, far from it.
const inkGap = 8;

/// [snapshot] drawn at [mapBox] in [sunny], as [ArenaPainter] draws a round:
/// raw RGBA bytes of the picture.
Future<Uint8List> painted(WidgetTester tester, ArenaSnapshot snapshot) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  ArenaPainter(snapshot, const {}, look: sunny, moments: ArenaMoments()).paint(canvas, mapBox);
  final picture = recorder.endRecording();
  final image = (await tester.runAsync(() => picture.toImage(mapBox.width.toInt(), mapBox.height.toInt())))!;
  final data = (await tester.runAsync(() => image.toByteData()))!;
  return data.buffer.asUint8List();
}

void main() {
  final ink = sunny.colors.ink.toARGB32() & 0xFFFFFF;

  for (final map in mapLibrary()) {
    final flags = map.decor.where((piece) => piece.kind == DecorKind.flag).toList();
    if (flags.isEmpty) continue;
    testWidgets('${map.id}: each flag pole stands in front of the walls', (tester) async {
      final snapshot = mapSnapshot(map);
      final bytes = await painted(tester, snapshot);
      for (final piece in snapshot.decor.where((piece) => piece.kind == DecorKind.flag)) {
        final foot = Offset(piece.at.dx * mapBox.width, piece.at.dy * mapBox.height);
        final up = piece.size * mapBox.shortestSide * poleCheckShare;
        final x = foot.dx.round();
        final y = (foot.dy - up).round();
        final pole = pixel(bytes, mapBox.width.toInt(), x, y);
        expect(
          colourGap(pole, ink),
          lessThanOrEqualTo(inkGap),
          reason:
              'the flag at (${piece.at.dx}, ${piece.at.dy}) is hidden at ($x, $y): '
              'its pole is 0x${pole.toRadixString(16)}, not the ink 0x${ink.toRadixString(16)}',
        );
      }
    });
  }
}
