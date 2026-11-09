import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;
import 'dart:ui' show FragmentProgram, FragmentShader;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';

import 'toy_look.dart';
import 'toy_look_scope.dart';
import 'toy_sky.dart';
import 'toy_still_sky.dart';

/// The dots' white; the palette owns how strongly they show
/// ([ToyColors.dotAlpha]).
const _dotColor = Color(0xFFFFFFFF);

/// The screen behind everything in the look (design section 4): the palette's
/// background with a soft lighter centre and faint white polka dots that drift
/// slowly down and to the right (design section 6).
///
/// It drifts while the look's effects are on, the device doesn't ask for
/// reduced motion and nothing holds it still (a [ToyStillSky] below or above
/// it), whatever fills it: the backdrop shader when the device loaded it, the
/// Canvas dots at the same drift otherwise (design section 6, step 6). A round's
/// screens hold it still; a menu's sky drifts. Give it the box to fill, and its
/// [child] sits on top.
///
/// Only the sky repaints as it drifts: the painter repaints from the shift, and
/// nothing under it is rebuilt.
class ToyBackground extends StatefulWidget {
  const ToyBackground({super.key, this.child});

  /// What the background is behind, if anything.
  final Widget? child;

  @override
  State<ToyBackground> createState() => _ToyBackgroundState();
}

class _ToyBackgroundState extends State<ToyBackground> with SingleTickerProviderStateMixin {
  /// How far the dots have drifted, as the sky last painted it: the painter's
  /// repaint signal and its one input.
  final _shift = ValueNotifier<Offset>(Offset.zero);

  /// The holds a [ToyStillSky] under this sky puts on it.
  final _holds = ToySkyHolds();

  /// How far the dots have drifted in all, so stopping and starting again
  /// carries on from where they stood instead of jumping back to the start.
  Duration _drift = Duration.zero;

  /// [_drift] when the ticker last started: the ticker's own elapsed time is
  /// counted from its start, so the two together give the total.
  Duration _runStart = Duration.zero;

  late final Ticker _ticker = createTicker(_onTick);

  /// The look the sky draws and follows (its effects setting), whether the
  /// device asks for reduced motion and whether a [ToyStillSky] stands above
  /// it: all read where a scope may be read, so a hold's release during the
  /// tree's unmount never looks up an ancestor.
  ToyLook? _look;
  bool _reduceMotion = false;
  bool _stillAbove = false;

  /// The backdrop shader, one per sky: made once from the look's program and
  /// reused for every frame, because the sky has one draw per frame and its
  /// uniforms are set just before it (as [toyShape] does per shape, M13 9
  /// review).
  FragmentShader? _shader;
  FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _holds.addListener(_follow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _look = ToyLookScope.of(context);
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _stillAbove = toyStillSkyAbove(context);
    _follow();
  }

  @override
  void dispose() {
    _holds.removeListener(_follow);
    _holds.dispose();
    _ticker.dispose();
    // The shader is left to the engine, as ToyShaders' warm-up leaves its own:
    // the research lists Mali-Vulkan crashes around disposing shader resources,
    // and a retained layer may still hold this one for a frame.
    _shift.dispose();
    super.dispose();
  }

  /// Whether the dots move: effects on (design D8), no reduced motion asked
  /// for, and no [ToyStillSky] below or above holding the sky.
  bool get _drifts {
    final look = _look;
    if (look == null) return false;
    return look.effects && !_reduceMotion && !_holds.isHeld && !_stillAbove;
  }

  /// Starts or stops the ticker to match [_drifts], keeping the drift's place
  /// across a stop: [_drift] is where a tick left it, and the next run counts
  /// from there.
  void _follow() {
    if (_drifts) {
      if (_ticker.isActive) return;
      _runStart = _drift;
      _ticker.start();
      return;
    }
    if (_ticker.isActive) _ticker.stop();
  }

  void _onTick(Duration elapsed) => _shift.value = ToySky.shiftAt(_drift = _runStart + elapsed);

  /// The shader to paint with: the look's backdrop program, made into a
  /// [FragmentShader] once and kept while the program stays the same.
  FragmentShader? _shaderFor(ToyLook look) {
    final program = look.backdrop;
    if (identical(program, _program)) return _shader;
    _program = program;
    return _shader = program?.fragmentShader();
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return ToySkyHoldsScope(
      holds: _holds,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: ToyBackgroundPainter(look, shift: _shift, shader: _shaderFor(look)),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Paints [ToyBackground]'s sky: the background colour, the glow and the dots
/// at [shift]. It's a painter of its own so a test can check its pixels, the
/// drift and that only the sky repaints.
///
/// With [shader] the whole box is one draw of the backdrop shader, its uniforms
/// from [ToySky.uniforms]; without it the same dots are drawn on the Canvas at
/// the same shift, so the two fill the sky alike and effects on or off never
/// makes it jump.
class ToyBackgroundPainter extends CustomPainter {
  ToyBackgroundPainter(this.look, {required this.shift, this.shader}) : super(repaint: shift);

  /// The look whose colours and dot strength it paints.
  final ToyLook look;

  /// How far the dots have drifted: the painter reads it on every paint, and a
  /// change repaints the sky alone.
  final ValueListenable<Offset> shift;

  /// The backdrop shader, or null for the Canvas dots.
  final FragmentShader? shader;

  @override
  void paint(Canvas canvas, Size size) {
    final drifted = shift.value;
    final shader = this.shader;
    if (shader == null) {
      _paintCanvas(canvas, size, drifted);
    } else {
      _paintShader(canvas, size, drifted, shader);
    }
  }

  /// The Canvas sky: the background, the radial glow and the dots.
  void _paintCanvas(Canvas canvas, Size size, Offset drifted) {
    final colors = look.colors;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = colors.background);
    final radius = math.max(size.width, size.height) * ToySky.glowShare;
    final glow = ui.Gradient.radial(rect.center, radius, [colors.backgroundGlow, colors.background]);
    canvas.drawRect(rect, Paint()..shader = glow);
    _paintDots(canvas, size, colors.dotAlpha, drifted);
  }

  /// The dots on their staggered grid, over everything, moved by [drifted].
  void _paintDots(Canvas canvas, Size size, double alpha, Offset drifted) {
    final paint = Paint()..color = _dotColor.withValues(alpha: alpha);
    const spacing = ToySky.spacing;
    const reach = ToySky.dotRadius;
    // The rows and columns whose dots touch the box once moved: the grid repeats
    // every two rows, so only a few rows outside it can reach in.
    final firstRow = ((-reach - drifted.dy) / spacing).floor();
    final lastRow = ((size.height + reach - drifted.dy) / spacing).ceil();
    for (var row = firstRow; row <= lastRow; row++) {
      final y = row * spacing + drifted.dy;
      final stagger = row.isOdd ? ToySky.stagger : 0.0;
      final firstCol = ((-reach - stagger - drifted.dx) / spacing).floor();
      final lastCol = ((size.width + reach - stagger - drifted.dx) / spacing).ceil();
      for (var col = firstCol; col <= lastCol; col++) {
        canvas.drawCircle(Offset(col * spacing + stagger + drifted.dx, y), reach, paint);
      }
    }
  }

  /// The shader sky: one full-box rectangle, every uniform set by name so the
  /// shader's source can be reordered without silently swapping a size for a
  /// colour (as [toyShape] does).
  void _paintShader(Canvas canvas, Size size, Offset drifted, FragmentShader shader) {
    final uniforms = ToySky.uniforms(look, size, drifted);
    final background = uniforms.background;
    final glow = uniforms.glow;
    shader.getUniformVec2('uSize').set(uniforms.size.width, uniforms.size.height);
    shader.getUniformVec4('uBackground').set(background.r, background.g, background.b, background.a);
    shader.getUniformVec4('uGlow').set(glow.r, glow.g, glow.b, glow.a);
    shader.getUniformFloat('uGlowShare').set(uniforms.glowShare);
    shader.getUniformFloat('uDotAlpha').set(uniforms.dotAlpha);
    shader.getUniformFloat('uSpacing').set(uniforms.spacing);
    shader.getUniformFloat('uDotRadius').set(uniforms.dotRadius);
    shader.getUniformVec2('uShift').set(uniforms.shift.dx, uniforms.shift.dy);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(ToyBackgroundPainter oldDelegate) =>
      oldDelegate.look != look || oldDelegate.shader != shader || oldDelegate.shift != shift;
}
