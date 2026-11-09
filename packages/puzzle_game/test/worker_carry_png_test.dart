import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';
import 'support/worker_carry.dart';
import 'support/worker_run.dart' show cellBox;

/// The eight cells: the four ways a worker walks with the door, then the door
/// turned the four quarter turns.
final cells = <(String, CarryWalker)>[
  ('walking right', CarryWalker.walking(0)),
  ('walking left', CarryWalker.walking(180)),
  ('walking up', CarryWalker.walking(-90)),
  ('walking down', CarryWalker.walking(90)),
  ('turn 0°', CarryWalker.turned(0)),
  ('turn 90°', CarryWalker.turned(90)),
  ('turn 180°', CarryWalker.turned(180)),
  ('turn 270°', CarryWalker.turned(270)),
];

/// How wide the row's name needs.
const captionWidth = 96.0;

/// What a cell's label takes, under it.
const labelHeight = 20.0;

/// The report's picture (m13 s14): one worker carrying the house's door from
/// its left, eight cells — walking right, left, up and down, then the door
/// turned 0°, 90°, 180° and 270° — drawn by the painter in Sunny with the
/// look's own fonts, so the side it keeps for the whole carry can be looked at.
void main() {
  setUpAll(loadLookFonts);

  testWidgets('writes docs/design/m13-carry-side.png', (tester) async {
    final look = sunny;
    final style = look.type.body.copyWith(fontSize: 12, color: look.colors.ink);
    final box = Size(captionWidth + cells.length * cellBox.width, cellBox.height + labelHeight);
    final bytes = await capturePng(
      tester,
      Row(
        children: [
          SizedBox(
            width: captionWidth,
            height: box.height,
            child: Center(
              child: Text('the door', style: style, textAlign: TextAlign.center),
            ),
          ),
          for (final (name, walker) in cells)
            Column(
              children: [
                carryCell(walker, look),
                SizedBox(
                  height: labelHeight,
                  child: Center(child: Text(name, style: style)),
                ),
              ],
            ),
        ],
      ),
      window: box,
      box: box,
      look: look,
    );
    final file = File('../../docs/design/m13-carry-side.png')..writeAsBytesSync(bytes);
    expect(file.lengthSync(), greaterThan(5000));
  });
}
