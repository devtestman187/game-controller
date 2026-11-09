import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/frames.dart';
import 'support/look.dart';
import 'support/look_fonts.dart';
import 'support/worker_run.dart';

/// The eight frames of one step cycle, as eighths of it.
const phases = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875];

/// How wide the row's name needs.
const captionWidth = 96.0;

/// What a row's frame label takes, under its cell.
const labelHeight = 20.0;

/// The report's strip (m13 s12): one whole step cycle of the worker walking
/// right, empty-handed in the first row and shoving the crate it carries in the
/// second, drawn by the painter in Sunny with the look's own fonts, eight
/// frames a row, so the feet, the arms, the bob and the flop can be looked at.
void main() {
  setUpAll(loadLookFonts);

  testWidgets('writes docs/design/m13-worker-run.png', (tester) async {
    final look = sunny;
    final style = look.type.body.copyWith(fontSize: 12, color: look.colors.ink);
    Widget caption(String text) => SizedBox(
      width: captionWidth,
      height: cellBox.height + labelHeight,
      child: Center(
        child: Text(text, style: style, textAlign: TextAlign.center),
      ),
    );
    Widget row(String name, {required bool held}) => Row(
      children: [
        caption(name),
        for (final (i, phase) in phases.indexed)
          Column(
            children: [
              runCell(walkedToRun(phase, held: held), look),
              SizedBox(
                height: labelHeight,
                child: Center(child: Text('${i + 1}/8', style: style)),
              ),
            ],
          ),
      ],
    );
    final box = Size(captionWidth + phases.length * cellBox.width, 2 * (cellBox.height + labelHeight));
    final bytes = await capturePng(
      tester,
      Column(mainAxisSize: MainAxisSize.min, children: [row('walking', held: false), row('carrying', held: true)]),
      window: box,
      box: box,
      look: look,
    );
    final file = File('../../docs/design/m13-worker-run.png')..writeAsBytesSync(bytes);
    expect(file.lengthSync(), greaterThan(5000));
  });
}
