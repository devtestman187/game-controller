import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

/// A small picture of a controller (PRD T5), lit while held. It follows the
/// phone's mode: D-pad mode shows the D-pad, Select/Start and A/B/X/Y; gyro
/// mode replaces the D-pad with a stick showing the tilt; stick mode shows
/// the Xbox-style layout with both sticks, the D-pad, A/B/X/Y, LB/RB and
/// Select/Start. It reads the standard gamepad (PRD v2 P4), so it shows any
/// player the same way. A null [gamepad] (not connected) shows everything
/// released.
///
/// It is drawn in the look (M13 3d): every control is a piece of paper with
/// the ink edge, a held one takes the focus yellow, and the A, B, X and Y
/// buttons take their own face tokens (design section 3), so the picture says
/// which button is which without a legend.
class InputVisualizer extends StatelessWidget {
  const InputVisualizer({super.key, required this.gamepad, this.width = 210});

  final GamepadState? gamepad;
  final double width;

  @override
  Widget build(BuildContext context) {
    final sticks = gamepad?.mode == InputMode.sticks;
    return SizedBox(
      width: width,
      // The stick layout needs more height for two rows of controls.
      height: sticks ? width / 2.2 : width / 3.2,
      child: CustomPaint(
        painter: InputVisualizerPainter(look: ToyLookScope.of(context), input: gamepad),
      ),
    );
  }
}

/// Draws an [InputVisualizer] in a [ToyLook]: paper controls with the ink
/// edge, the held ones filled (a face button in its token, anything else in
/// the focus yellow), and every label in ink.
class InputVisualizerPainter extends CustomPainter {
  InputVisualizerPainter({required this.look, required this.input});

  /// The look the picture is drawn in.
  final ToyLook look;

  /// The player's controls, or null for a phone that isn't connected.
  final GamepadState? input;

  /// The fill of [button]'s face: its face token while it is held, paper
  /// while it isn't. Only A, B, X and Y have one.
  Color faceColor(GamepadButton button) => _buttons.contains(button) ? _faceToken(button) : _base;

  Color get _base => look.colors.paper;

  Color get _lit => look.colors.focus;

  /// The ink edge's width in the picture: half the look's, because the
  /// picture's controls are a third of a button's size.
  double get _edge => look.sizes.outlineWidth / 2;

  Color _faceToken(GamepadButton button) => switch (button) {
    GamepadButton.a => look.colors.faceA,
    GamepadButton.b => look.colors.faceB,
    GamepadButton.x => look.colors.faceX,
    GamepadButton.y => look.colors.faceY,
    _ => _base,
  };

  Set<GamepadButton> get _buttons => input?.buttons ?? const {};

  @override
  void paint(Canvas canvas, Size size) {
    final i = input;
    if (i != null && i.mode == InputMode.sticks) {
      _paintSticksLayout(canvas, size, i);
    } else {
      _paintClassicLayout(canvas, size);
    }
  }

  /// D-pad (or the gyro stick) on the left, Select/Start, A/B/X/Y on the right.
  void _paintClassicLayout(Canvas canvas, Size size) {
    final h = size.height;
    final unit = h / 3;
    final i = input;
    if (i != null && i.mode == InputMode.gyro) {
      _stick(canvas, Offset(h / 2, h / 2), h / 2 - 1, i.tiltX ?? i.leftX, i.tiltY ?? i.leftY);
    } else {
      _dpad(canvas, Offset(h / 2, h / 2), unit);
    }
    final mid = size.width / 2;
    _pill(
      canvas,
      Rect.fromCenter(center: Offset(mid - unit * 0.75, h / 2), width: unit * 1.2, height: unit * 0.55),
      GamepadButton.select,
    );
    _pill(
      canvas,
      Rect.fromCenter(center: Offset(mid + unit * 0.75, h / 2), width: unit * 1.2, height: unit * 0.55),
      GamepadButton.start,
    );
    _face(canvas, Offset(size.width - h / 2, h / 2), unit);
  }

  /// Xbox-style: LB/RB on top, left stick upper left with the D-pad below
  /// it, A/B/X/Y upper right with the right stick below it, Select/Start in
  /// the middle.
  void _paintSticksLayout(Canvas canvas, Size size, GamepadState i) {
    final w = size.width;
    final h = size.height;
    final u = h / 7; // Layout unit.
    final shoulder = Size(w * 0.2, u * 0.75);
    _pill(canvas, Offset(0, 0) & shoulder, GamepadButton.lb, text: 'LB');
    _pill(canvas, Offset(w - shoulder.width, 0) & shoulder, GamepadButton.rb, text: 'RB');

    final top = u * 1.1;
    final stickRadius = u * 1.6;
    _stick(canvas, Offset(stickRadius + 1, top + stickRadius), stickRadius, i.leftX, i.leftY);
    _face(canvas, Offset(w - u * 1.6, top + u * 1.6), u * 1.05);
    _dpad(canvas, Offset(w * 0.34, h - u * 1.5), u * 0.95);
    _stick(canvas, Offset(w * 0.66, h - stickRadius - 1), stickRadius, i.rightX, i.rightY);

    final mid = w / 2;
    final pill = Size(u * 1.3, u * 0.6);
    _pill(
      canvas,
      Rect.fromCenter(center: Offset(mid - pill.width * 0.65, top + u), width: pill.width, height: pill.height),
      GamepadButton.select,
    );
    _pill(
      canvas,
      Rect.fromCenter(center: Offset(mid + pill.width * 0.65, top + u), width: pill.width, height: pill.height),
      GamepadButton.start,
    );
  }

  /// A 3x3 grid centered on [c], lit on the arms of the current direction.
  void _dpad(Canvas canvas, Offset c, double unit) {
    final dx = input?.dpadX ?? 0;
    final dy = input?.dpadY ?? 0;
    final origin = c - Offset(unit * 1.5, unit * 1.5);
    for (final (ax, ay) in const [(0, 0), (0, -1), (0, 1), (-1, 0), (1, 0)]) {
      final on = (ax != 0 && ax == dx) || (ay != 0 && ay == dy);
      final rect = Rect.fromLTWH(origin.dx + (ax + 1) * unit, origin.dy + (ay + 1) * unit, unit, unit);
      _piece(
        canvas,
        Path()..addRRect(RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(unit * 0.15))),
        on ? _lit : _base,
      );
    }
  }

  /// A stick: a circle with a cross and a dot at (x, y).
  void _stick(Canvas canvas, Offset c, double r, double x, double y) {
    _piece(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: r)), _base);
    final cross = Paint()
      ..color = look.colors.ink.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), cross);
    canvas.drawLine(c - Offset(0, r), c + Offset(0, r), cross);
    final dot = r * 0.24;
    canvas.drawCircle(c + Offset(x, y) * (r - dot), dot, Paint()..color = _lit);
  }

  /// A/B/X/Y in a diamond around [c], [unit] apart.
  void _face(Canvas canvas, Offset c, double unit) {
    final centers = {
      GamepadButton.y: c + Offset(0, -unit),
      GamepadButton.x: c + Offset(-unit, 0),
      GamepadButton.b: c + Offset(unit, 0),
      GamepadButton.a: c + Offset(0, unit),
    };
    for (final MapEntry(key: button, value: p) in centers.entries) {
      _piece(canvas, Path()..addOval(Rect.fromCircle(center: p, radius: unit * 0.45)), faceColor(button));
      // Text on a coloured fill is always ink (design D12), and on paper too.
      _text(canvas, p, button.name.toUpperCase(), unit * 0.5, look.colors.ink);
    }
  }

  void _pill(Canvas canvas, Rect rect, GamepadButton button, {String? text}) {
    final on = _buttons.contains(button);
    _piece(
      canvas,
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2))),
      on ? _lit : _base,
    );
    if (text != null) _text(canvas, rect.center, text, rect.height * 0.6, look.colors.ink);
  }

  /// [path] as one piece of the picture: its fill, then the ink edge.
  void _piece(Canvas canvas, Path path, Color fill) {
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _edge
        ..color = look.colors.ink,
    );
  }

  void _text(Canvas canvas, Offset center, String text, double fontSize, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(InputVisualizerPainter oldDelegate) => oldDelegate.input != input || oldDelegate.look != look;
}
