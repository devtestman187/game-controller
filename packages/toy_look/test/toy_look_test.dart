import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// Records the look a widget below the scope reads on every build.
final class _Reader extends StatelessWidget {
  const _Reader(this.onBuild);

  final void Function(ToyLook look) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(ToyLookScope.of(context));
    return const SizedBox.shrink();
  }
}

void main() {
  test('a TV look takes the TV type and TV sizes, and stays on its palette', () {
    final look = ToyLook.build(palette: ToyPalette.night, tv: true);
    expect(look.palette, ToyPalette.night);
    expect(look.colors, same(ToyColors.night));
    expect(look.type, same(ToyType.tv));
    expect(look.sizes, same(ToySizes.tv));
    expect(look.effects, isTrue);
  });

  test('a phone look takes the phone type and menu sizes', () {
    final look = ToyLook.build(palette: ToyPalette.sunny, tv: false);
    expect(look.type, same(ToyType.phone));
    expect(look.sizes, same(ToySizes.menu));
  });

  test('effects off drops both the body shader and the backdrop', () {
    final look = ToyLook.build(palette: ToyPalette.sunny, tv: true, effects: false);
    expect(look.effects, isFalse);
    expect(look.shade, isNull);
    expect(look.backdrop, isNull);
  });

  test('no shaders loaded is no shader, even with effects on', () {
    final look = ToyLook.build(palette: ToyPalette.sunny, tv: true);
    expect(look.shade, isNull);
    expect(look.backdrop, isNull);
  });

  test('two looks built the same are equal, and differ by any field', () {
    final a = ToyLook.build(palette: ToyPalette.sunny, tv: true);
    final b = ToyLook.build(palette: ToyPalette.sunny, tv: true);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(ToyLook.build(palette: ToyPalette.night, tv: true)));
    expect(a, isNot(ToyLook.build(palette: ToyPalette.sunny, tv: false)));
    expect(a, isNot(ToyLook.build(palette: ToyPalette.sunny, tv: true, effects: false)));
  });

  test('the sizes are the design\'s', () {
    expect(ToySizes.menu.outlineWidth, 3);
    expect(ToySizes.tv.outlineWidth, 4);
    // A menu button is the 48 px touch target; a TV's is 64 (design section 4).
    expect(ToySizes.menu.buttonHeight, 48);
    expect(ToySizes.tv.buttonHeight, 64);
    expect(ToySizes.shadowOffset, const Offset(3, 4));
    expect(ToySizes.cardCorner, 16);
    expect(ToySizes.focusRing, 4);
    expect(
      [ToySizes.space4, ToySizes.space8, ToySizes.space12, ToySizes.space16, ToySizes.space24, ToySizes.space32],
      [4, 8, 12, 16, 24, 32],
    );
  });

  testWidgets('a widget finds the scope\'s look above it', (tester) async {
    final sunny = ToyLook.build(palette: ToyPalette.sunny, tv: true);
    final seen = <ToyLook>[];
    await tester.pumpWidget(ToyLookScope(look: sunny, child: _Reader(seen.add)));
    expect(seen, [sunny]);
  });

  testWidgets('the widgets below a scope rebuild only when the look changes', (tester) async {
    final seen = <ToyLook>[];
    final reader = _Reader(seen.add);
    final sunny = ToyLook.build(palette: ToyPalette.sunny, tv: true);
    await tester.pumpWidget(ToyLookScope(look: sunny, child: reader));
    expect(seen, hasLength(1));

    // The same look built again: the value is equal, so nothing below rebuilds.
    await tester.pumpWidget(
      ToyLookScope(
        look: ToyLook.build(palette: ToyPalette.sunny, tv: true),
        child: reader,
      ),
    );
    expect(seen, hasLength(1), reason: 'an equal look does not notify');

    final night = ToyLook.build(palette: ToyPalette.night, tv: true);
    await tester.pumpWidget(ToyLookScope(look: night, child: reader));
    expect(seen, hasLength(2), reason: 'a changed look notifies once');
    expect(seen.last, night);
  });
}
