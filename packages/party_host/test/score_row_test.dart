import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// The frame's width at its narrowest, in frame px (DESIGN section 2): the
/// smallest frame a score card is drawn in is 960 wide.
const _frameWidthPx = 960.0;

/// The width a score row fills: the frame's stage inside the design's 24 px
/// gutter either side (DESIGN sections 1 and 4), which is 960 - 48 = 912.
double get _rowWidthPx => _frameWidthPx - 2 * hostFrameGutterPx;

/// Mounts [row] as one line of a score card at the width the frame gives it,
/// drawn against [maxPoints] the way a card draws its rows, in the TV look the
/// frame's screens draw with.
Future<void> _pumpRow(WidgetTester tester, {required ScoreRowData row, required int maxPoints}) async {
  final look = ToyLook.build(palette: ToyPalette.sunny, tv: true);
  await tester.pumpWidget(
    ToyLookScope(
      look: look,
      child: MaterialApp(
        theme: toyTheme(look),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _rowWidthPx,
              child: ScoreRow(row: row, maxPoints: maxPoints),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The bar's fill: the box that shows the row's share of the card's leader.
Finder get _barFill =>
    find.descendant(of: find.byKey(const Key('scoreRowBar')), matching: find.byType(FractionallySizedBox));

void main() {
  testWidgets('a row with nothing to add shows no "+0"', (tester) async {
    await _pumpRow(tester, row: const ScoreRowData(rank: 1, number: 1, name: 'Nightshade', points: 30), maxPoints: 30);

    expect(find.text('+0'), findsNothing, reason: 'a final-scores row has nothing to add');
    expect(find.text('30'), findsOneWidget, reason: 'the star and the score always show');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row with a round\'s points shows "+3"', (tester) async {
    await _pumpRow(
      tester,
      row: const ScoreRowData(rank: 2, number: 3, name: 'Milo', points: 25, delta: 3),
      maxPoints: 30,
    );

    expect(find.text('+3'), findsOneWidget, reason: 'the round added three points');
    expect(find.text('25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a card with no points yet draws an empty bar and never divides by zero', (tester) async {
    await _pumpRow(tester, row: const ScoreRowData(rank: 1, number: 1, name: 'Nightshade', points: 0), maxPoints: 0);

    expect(
      tester.widget<FractionallySizedBox>(_barFill).widthFactor,
      0.0,
      reason: 'a card with no leader fills nothing',
    );
    expect(tester.getSize(_barFill).width, 0.0, reason: 'the fill is empty');
    expect(tester.takeException(), isNull);
  });
}
