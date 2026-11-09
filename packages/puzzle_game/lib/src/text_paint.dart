part of 'view.dart';

/// A `bad` pill behind [painter]'s text, which is ink: `bad` text on the sky
/// would fail 4.5:1 (design section 5, rule 7).
void _pill(
  Canvas canvas,
  TextPainter painter,
  Offset at,
  double pad,
  ToyShapeStyle style,
  ToyColors colours,
  FragmentProgram? shade,
) {
  final box = (_textTopLeft(painter, at, TextAlign.center) & painter.size).inflate(pad);
  toyShape(
    canvas,
    Path()..addRRect(RRect.fromRectAndRadius(box, Radius.circular(box.height / 2))),
    colours.bad,
    style,
    shade: shade,
  );
}

/// The ink edge a mark's text is drawn with, as a ring of [width] wide
/// shadows: one `TextPainter` for the mark, as M12 laid it out.
List<Shadow> _rim(Color ink, double width) => [
  for (final d in const [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
    Offset(0.7, 0.7),
    Offset(-0.7, 0.7),
    Offset(0.7, -0.7),
    Offset(-0.7, -0.7),
  ])
    Shadow(color: ink, offset: d * width),
];

/// [text] laid out in the look's [style] at [size] and [colour], with an ink
/// edge when [edgeWidth] is given.
TextPainter _layout(
  String text,
  double size,
  Color colour, {
  TextStyle? style,
  double edgeWidth = 0,
  Color? edge,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: size,
        color: colour,
        height: 1,
        shadows: edgeWidth > 0 ? _rim(edge ?? colour, edgeWidth) : null,
      ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();
  return painter;
}

/// Where [painter]'s top left goes so that its centre, or its left or right
/// edge, sits at [at].
Offset _textTopLeft(TextPainter painter, Offset at, TextAlign align) {
  final dx = switch (align) {
    TextAlign.left => 0.0,
    TextAlign.right => -painter.width,
    _ => -painter.width / 2,
  };
  return at + Offset(dx, -painter.height / 2);
}

void _text(
  Canvas canvas,
  String text,
  Offset at,
  double size,
  Color colour, {
  TextStyle? style,
  TextAlign align = TextAlign.center,
  double edgeWidth = 0,
  Color? edge,
}) {
  final painter = _layout(text, size, colour, style: style, edgeWidth: edgeWidth, edge: edge);
  painter.paint(canvas, _textTopLeft(painter, at, align));
}

/// How many pixels one world unit is on [canvas] as it stands: its whole
/// transform's scale, whatever scaled it before this painter did.
double _pxPerUnit(Canvas canvas) {
  final m = canvas.getTransform();
  return sqrt(m[0] * m[0] + m[1] * m[1]);
}
