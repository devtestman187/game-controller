import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import 'support/frames.dart';
import 'support/look.dart' show sunny;
import 'support/look_fonts.dart';

/// One swatch's box.
const cell = Size(110, 64);

/// The space between swatches and round the sheet.
const gap = 6.0;

/// One token: its colour, then its name and hex.
Widget swatch(PieceColor token, ToyLook look) => ColoredBox(
  color: look.colors.paper,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 98,
        height: 32,
        decoration: BoxDecoration(
          color: Color(token.color),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: look.colors.ink, width: 1.5),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${token.name} · ${token.hex}',
          style: look.type.body.copyWith(fontSize: 11, color: look.colors.ink),
        ),
      ),
    ],
  ),
);

/// The sheet: the tokens six to a row, each shown on its colour.
Widget sheet(ToyLook look) => Padding(
  padding: const EdgeInsets.all(gap),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var row = 0; row < PiecePalette.all.length; row += 6)
        Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final token in PiecePalette.all.skip(row).take(6))
                Padding(
                  padding: const EdgeInsets.only(right: gap),
                  child: SizedBox.fromSize(size: cell, child: swatch(token, look)),
                ),
            ],
          ),
        ),
    ],
  ),
);

/// The sheet's own size: six swatches a row, two rows, with a gap round and
/// between them.
final box = Size(gap + 6 * (cell.width + gap) + gap, gap + 2 * (cell.height + gap) + gap);

void main() {
  setUpAll(loadLookFonts);

  testWidgets('writes docs/design/puzzles/colours.png', (tester) async {
    final picture = await capturePng(tester, sheet(sunny), window: box, box: box, look: sunny);
    final file = File('../../docs/design/puzzles/colours.png')..createSync(recursive: true);
    file.writeAsBytesSync(picture);
    expect(file.lengthSync(), greaterThan(2000));
  });
}
