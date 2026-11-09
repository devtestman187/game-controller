import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'support/pixels.dart';

/// The look the badge is drawn in.
final _sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);

/// The badge the pixel tests paint: [diameter] across, centred here.
const _centre = Offset(100, 100);
const _diameter = 80.0;

/// Whether the pixel ([r], [g], [b]) is the look's ink, #1E1646, or close to it.
bool _isInk((int, int, int) pixel) {
  final (r, g, b) = pixel;
  return r < 100 && g < 100 && b < 120;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a badge is the player\'s colour, inked round the edge, with its shadow down and to the right', () async {
    final pixels = await paintedPixels(
      const Size(200, 200),
      (canvas) => paintToyBadge(canvas, _centre, _diameter, 2, _sunny),
    );
    // Inside the disc and above the number, player 2's orange (255, 138, 31).
    expect(pixels.at(100, 75), (255, 138, 31));
    // The edge is ink (30, 22, 70), 80 / 14 = 5.71 wide, centred on the rim.
    expect(pixels.at(140, 100), (30, 22, 70));
    // The shadow is the disc moved (6, 8) and filled with ink at 35 %: over
    // the white, (176, 173, 190). (136, 126) is inside it and outside the disc.
    expect(pixels.at(136, 126), (176, 173, 190));
  });

  test('each character\'s accessory draws its ink above the disc, so a bar can show whose it is', () async {
    for (var player = 1; player <= 6; player++) {
      final character = ToyCharacter.forPlayer(player);
      final pixels = await paintedPixels(
        const Size(200, 200),
        (canvas) => paintToyBadge(canvas, _centre, _diameter, player, _sunny, character: character),
      );
      final inkAbove = [
        for (var y = _centre.dy.round() - toyAccessoryHeadroom(_diameter).round(); y < _centre.dy; y++)
          for (var x = 60; x <= 140; x++)
            if (_isInk(pixels.at(x, y))) (x, y),
      ];
      expect(
        inkAbove,
        isNotEmpty,
        reason: 'player $player wears ${character.accessory.name}: its ink shows above the disc',
      );
    }
  });

  testWidgets('a badge says whose it is', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ToyLookScope(
        look: _sunny,
        child: const Directionality(textDirection: TextDirection.ltr, child: ToyBadge(number: 3)),
      ),
    );
    expect(find.bySemanticsLabel('Player 3'), findsOneWidget);
    semantics.dispose();
  });
}
