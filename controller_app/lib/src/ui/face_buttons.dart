part of 'pad_widgets.dart';

/// The face buttons in the design's order (A, B, X, Y), each with the look
/// colour it always fills with (M13 design section 3): `faceA` to `faceY`, the
/// same in both palettes, so the pad's only colour literals are the look's.
Map<ControllerButton, Color> faceFills(ToyColors colors) => {
  ControllerButton.a: colors.faceA,
  ControllerButton.b: colors.faceB,
  ControllerButton.x: colors.faceX,
  ControllerButton.y: colors.faceY,
};

/// A, B, X, Y in a diamond. A thumb can slide from one to the next.
class FaceButtonsView extends ConsumerWidget {
  const FaceButtonsView({super.key, this.geometry = FaceGeometry.classic});

  /// [FaceGeometry.classic] in D-pad and gyro modes, compact in stick mode.
  final FaceGeometry geometry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pressed = ref.watch(padProvider.select((p) => p.buttons));
    final pad = ref.read(padProvider.notifier);
    final look = ref.watch(toyLookProvider);
    final fills = faceFills(look.colors);
    // The game's labels and unused buttons (P5).
    final game = ref.watch(gameLayoutProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        return Semantics(
          key: const Key('faceButtonLabels'),
          container: true,
          label: [
            for (final b in fills.keys)
              if (!game.hidden.contains(b)) [b.name.toUpperCase(), ?game.labels[b]].join(' '),
          ].join(', '),
          child: SizedBox.square(
            key: const Key('faceButtons'),
            dimension: side,
            child: _PointerArea(
              // In stick mode only the round area around the buttons takes
              // touches, so the square's corners leave them to the right stick.
              behavior: geometry.roundHitArea ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
              onDownOrMove: (pointer, local) {
                final b = geometry.buttonAt(local, side);
                // A hidden button does nothing.
                pad.button(pointer, game.hidden.contains(b) ? null : b);
              },
              onUp: pad.up,
              child: PressFlash<ControllerButton>(
                pressed: pressed.intersection(fills.keys.toSet()),
                shapeOf: (button, size) => Path()
                  ..addOval(
                    Rect.fromCircle(
                      center: geometry.centers[button]! * size.width,
                      radius: geometry.radius * size.width,
                    ),
                  ),
                child: CustomPaint(
                  size: Size.square(side),
                  painter: FaceButtonsPainter(
                    look: look,
                    side: side,
                    pressed: pressed,
                    geometry: geometry,
                    labels: game.labels,
                    hidden: game.hidden,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The letter's size alone on a button, as a share of its radius (today's
/// size, kept: design D11 moves no size).
const _letterShare = 0.69;

/// The letter's size above a game's label, as a share of the radius (today's).
const _letterAboveLabelShare = 0.5;

/// A game's label's first size, as a share of the radius (today's).
const _labelShare = 0.3;

/// The widest a game's label may be at its place, as a share of the radius.
const _labelMaxWidthShare = 1.7;

/// How much each try shrinks a game's label, and the smallest it gets, in
/// logical pixels (today's fit rule).
const _labelShrink = 0.9;
const _labelMinPx = 8.0;

/// How far above the middle the letter sits when a label shares the button,
/// and how far below the letter's top the label starts, as shares of the
/// letter's height (today's places).
const _letterRiseShare = 0.95;
const _labelDropShare = 0.05;

/// Draws A, B, X and Y the look's way (M13 step 8, rule 2): each in its face
/// colour with the ink edge and the hard shadow, pressed ones pushed in and
/// their shadow gone, and the game's label under the letter. A button the game
/// doesn't use (P5) is a dashed ink outline alone, in the same place.
///
/// Its fields are the painter's whole input, so a test paints it on its own.
class FaceButtonsPainter extends CustomPainter {
  const FaceButtonsPainter({
    required this.look,
    required this.side,
    required this.pressed,
    required this.geometry,
    this.labels = const {},
    this.hidden = const {},
  });

  /// The look the pad is drawn in, and the colours and edges it takes.
  final ToyLook look;

  /// The side of the square the buttons sit in, for [hitTest].
  final double side;

  /// The buttons held now, which are drawn pushed in.
  final Set<ControllerButton> pressed;

  /// Where the buttons sit and how they take touches.
  final FaceGeometry geometry;

  /// The game's labels (P5), drawn inside the button under its letter.
  final Map<ControllerButton, String> labels;

  /// Buttons the game doesn't use: only a faint dashed outline, so the others
  /// keep their places.
  final Set<ControllerButton> hidden;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final fills = faceFills(look.colors);
    for (final MapEntry(key: button, value: center) in geometry.centers.entries) {
      final c = center * s;
      final r = geometry.radius * s;
      if (hidden.contains(button)) {
        final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
        paintDashedEdge(canvas, circle, padInkEdge(look, colour: padHiddenOutline(look)));
        continue;
      }
      _paintButton(canvas, button, c, r, fills[button]!);
    }
  }

  /// One button: its body, then its letter, or its letter and the game's label.
  void _paintButton(Canvas canvas, ControllerButton button, Offset centre, double radius, Color fill) {
    final on = pressed.contains(button);
    final body = Path()..addOval(Rect.fromCircle(center: centre, radius: radius));
    paintPadPart(canvas, body, look: look, fill: fill, pressed: on);
    // Text sits on the button, so it goes where the body did.
    final moved = centre + padSquish(on);
    final name = labels[button];
    final letter = padLetter(
      button.name.toUpperCase(),
      look,
      radius * (name == null ? _letterShare : _letterAboveLabelShare),
    );
    if (name == null) {
      paintCentred(canvas, letter, moved);
      return;
    }
    // The letter above the middle, the label below it, shrunk to fit the
    // circle's width there.
    letter.paint(canvas, moved - Offset(letter.width / 2, letter.height * _letterRiseShare));
    final label = _label(name, radius);
    label.paint(canvas, moved + Offset(-label.width / 2, letter.height * _labelDropShare));
    label.dispose();
  }

  /// A game's label, laid out at the largest size that fits at its place.
  TextPainter _label(String name, double radius) {
    var size = radius * _labelShare;
    var label = padLabel(name, look, size);
    while (label.width > radius * _labelMaxWidthShare && size > _labelMinPx) {
      label.dispose();
      size *= _labelShrink;
      label = padLabel(name, look, size);
    }
    return label;
  }

  /// Used for hit testing in stick mode (see [FaceButtonsView]).
  @override
  bool hitTest(Offset position) => geometry.takes(position, side);

  @override
  bool shouldRepaint(FaceButtonsPainter old) =>
      old.look != look ||
      old.geometry != geometry ||
      !mapEquals(old.labels, labels) ||
      !setEquals(old.hidden, hidden) ||
      old.pressed.length != pressed.length ||
      !old.pressed.containsAll(pressed) ||
      old.side != side;
}
