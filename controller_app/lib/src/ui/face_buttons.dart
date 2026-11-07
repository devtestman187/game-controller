part of 'pad_widgets.dart';

/// A, B, X, Y in a diamond. A thumb can slide from one to the next.
class FaceButtonsView extends ConsumerWidget {
  const FaceButtonsView({super.key, this.geometry = FaceGeometry.classic});

  /// [FaceGeometry.classic] in D-pad and gyro modes, compact in stick mode.
  final FaceGeometry geometry;

  static const colors = {
    ControllerButton.a: Color(0xFF4CAF50),
    ControllerButton.b: Color(0xFFE53935),
    ControllerButton.x: Color(0xFF1E88E5),
    ControllerButton.y: Color(0xFFFDD835),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pressed = ref.watch(padProvider.select((p) => p.buttons));
    final pad = ref.read(padProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    // The game's labels and unused buttons (P5).
    final game = ref.watch(gameLayoutProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        return Semantics(
          key: const Key('faceButtonLabels'),
          container: true,
          label: [
            for (final b in colors.keys)
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
                pressed: pressed.intersection(colors.keys.toSet()),
                shapeOf: (button, size) => Path()
                  ..addOval(
                    Rect.fromCircle(
                      center: geometry.centers[button]! * size.width,
                      radius: geometry.radius * size.width,
                    ),
                  ),
                child: CustomPaint(
                  size: Size.square(side),
                  painter: _FacePainter(
                    side: side,
                    pressed: pressed,
                    geometry: geometry,
                    base: scheme.surfaceContainerHighest,
                    text: scheme.onSurface,
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

class _FacePainter extends CustomPainter {
  _FacePainter({
    required this.side,
    required this.pressed,
    required this.geometry,
    required this.base,
    required this.text,
    this.labels = const {},
    this.hidden = const {},
  });

  final double side;

  final Set<ControllerButton> pressed;
  final FaceGeometry geometry;
  final Color base;
  final Color text;

  /// The game's labels (P5), drawn inside the button under its letter.
  final Map<ControllerButton, String> labels;

  /// Buttons the game doesn't use: only a faint outline, so the others keep
  /// their places.
  final Set<ControllerButton> hidden;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    for (final MapEntry(key: button, value: center) in geometry.centers.entries) {
      final on = pressed.contains(button);
      final color = FaceButtonsView.colors[button]!;
      final c = center * s;
      final r = geometry.radius * s * (on ? 0.94 : 1);
      if (hidden.contains(button)) {
        canvas.drawCircle(
          c,
          geometry.radius * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = text.withValues(alpha: 0.12),
        );
        continue;
      }
      canvas.drawCircle(c, r, Paint()..color = on ? color : base);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, r * 0.075)
          ..color = color,
      );
      final name = labels[button];
      final ink = on ? Colors.black : color;
      final letter = TextPainter(
        text: TextSpan(
          text: button.name.toUpperCase(),
          style: TextStyle(fontSize: r * (name == null ? 0.69 : 0.5), fontWeight: FontWeight.bold, color: ink),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (name == null) {
        letter.paint(canvas, c - Offset(letter.width / 2, letter.height / 2));
        continue;
      }
      // The letter above the middle, the label below it, shrunk to fit the
      // circle's width there.
      letter.paint(canvas, c - Offset(letter.width / 2, letter.height * 0.95));
      var fontSize = r * 0.3;
      late TextPainter label;
      for (;;) {
        label = TextPainter(
          text: TextSpan(
            text: name,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: on ? Colors.black : text),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        if (label.width <= r * 1.7 || fontSize <= 8) break;
        fontSize *= 0.9;
      }
      label.paint(canvas, c + Offset(-label.width / 2, letter.height * 0.05));
    }
  }

  /// Used for hit testing in stick mode (see [FaceButtonsView]).
  @override
  bool hitTest(Offset position) => geometry.takes(position, side);

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.geometry != geometry ||
      !mapEquals(old.labels, labels) ||
      !setEquals(old.hidden, hidden) ||
      old.pressed.length != pressed.length ||
      !old.pressed.containsAll(pressed) ||
      old.base != base;
}
