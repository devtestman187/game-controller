import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

import 'support/pixels.dart';

/// The box the pixel tests paint: its centre, its far corner and a dot on the
/// grid are all clear of each other.
const _size = Size(300, 300);

final _sunny = ToyLook.build(palette: ToyPalette.sunny, tv: true);
final _night = ToyLook.build(palette: ToyPalette.night, tv: true);
final _noEffects = ToyLook.build(palette: ToyPalette.sunny, tv: true, effects: false);

/// A sky over [look] on a still device, or one that drifts under the given
/// conditions. The [child] sits on top of the sky.
Widget _sky(ToyLook look, {bool still = false, bool reduceMotion = false, Widget child = const SizedBox.expand()}) {
  Widget sky = ToyBackground(child: child);
  if (still) sky = ToyStillSky(child: sky);
  return ToyLookScope(
    look: look,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(textDirection: TextDirection.ltr, child: sky),
    ),
  );
}

/// The background's painter, as the widget last built it.
ToyBackgroundPainter _painterOf(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(of: find.byType(ToyBackground), matching: find.byType(CustomPaint)).first,
            )
            .painter!
        as ToyBackgroundPainter;

/// How far the sky has drifted, as the painter last read it.
Offset _shiftOf(WidgetTester tester) => _painterOf(tester).shift.value;

/// How long the sky's stars have twinkled, as the painter last read it.
Duration _timeOf(WidgetTester tester) => _painterOf(tester).time.value;

/// Counts how often the sky's child builds.
int _childBuilds = 0;

final class _Counted extends StatelessWidget {
  const _Counted();

  @override
  Widget build(BuildContext context) {
    _childBuilds++;
    return const SizedBox.expand();
  }
}

/// The sky's Canvas fill at [shift], [time] after the drift started.
Future<Pixels> _painted(ToyLook look, [Offset shift = Offset.zero, Duration time = Duration.zero]) => paintedPixels(
  _size,
  (canvas) => ToyBackgroundPainter(
    look,
    shift: ValueNotifier<Offset>(shift),
    time: ValueNotifier<Duration>(time),
  ).paint(canvas, _size),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the sky\'s numbers are the design\'s, and a second is (6, 6)', () {
    expect(ToySky.spacing, 32);
    expect(ToySky.dotRadius, 3);
    expect(ToySky.glowShare, 0.6);
    expect(ToySky.driftSpeed, 6);
    expect(ToySky.shiftAt(const Duration(seconds: 1)), const Offset(6, 6));
  });

  test('the shift wraps after a star tile, 1024 px: 170.667 s is back at the start', () {
    expect(ToySky.wrapPx, 1024);
    // 170.666 s × 6 = 1023.996, a hair short of 1024; a millisecond later it wraps.
    expect(ToySky.shiftAt(const Duration(milliseconds: 170666)).dx, closeTo(1023.996, 1e-6));
    expect(ToySky.shiftAt(const Duration(milliseconds: 170667)).dx, closeTo(0.002, 1e-6));
  });

  test('the uniforms are the look\'s colours and the sky\'s numbers', () {
    const size = Size(300, 200);
    final sunny = ToySky.uniforms(_sunny, size, const Offset(6, 6));
    expect(sunny.size, size);
    expect(sunny.background, ToyColors.sunny.background);
    expect(sunny.glow, ToyColors.sunny.backgroundGlow);
    expect(sunny.dotAlpha, 0.22);
    expect(sunny.spacing, 32);
    expect(sunny.dotRadius, 3);
    expect(sunny.glowShare, 0.6);
    expect(sunny.shift, const Offset(6, 6));

    final night = ToySky.uniforms(_night, size, Offset.zero);
    expect(night.background, ToyColors.night.background);
    expect(night.glow, ToyColors.night.backgroundGlow);
    // Night's sky is stars, so it paints no polka dots (design section 4, M13
    // 12); the palette keeps its dot strength for the Arena's mat.
    expect(night.dotAlpha, 0);
    expect(night.shift, Offset.zero);
  });

  test('the centre is the glow and the corner is the sky', () async {
    final pixels = await _painted(_sunny);
    // The glow's centre is backgroundGlow (196, 234, 255), give or take the
    // gradient's rounding; (150, 150) is clear of every dot (the nearest is
    // 11.7 away, the dots are 3 across).
    final centre = pixels.at(150, 150);
    expect(centre.$1, closeTo(196, 1));
    expect(centre.$2, closeTo(234, 1));
    expect(centre.$3, closeTo(255, 1));
    // The glow's radius is 0.6 of the longer side (Claude's review: a soft,
    // wide glow), so it stops 180 from the centre: the far corner (208.6
    // away) is the background (124, 200, 248).
    expect(pixels.at(299, 299), (124, 200, 248));
    // (214, 214) is 90.5 from the centre, half-way out: its red is half-way
    // from the glow's 196 to the background's 124, about 160 (a 112.5 radius
    // would have it 80% of the way, about 138).
    expect(pixels.at(214, 214).$1, closeTo(160, 3));
  });

  test('a grid point is a dot: white at the palette\'s dotAlpha', () async {
    final pixels = await _painted(_sunny);
    // (272, 288) is on a dot: the odd rows sit half a step along. It is 184.2
    // from the centre, past the glow's 180, so the sky under it is the plain
    // background. White (255, 255, 255) at 22 % over it:
    // 0.22 * 255 + 0.78 * (124, 200, 248) = (152.8, 212.1, 249.5).
    final dot = pixels.at(272, 288);
    expect(dot.$1, closeTo(153, 2));
    expect(dot.$2, closeTo(212, 2));
    expect(dot.$3, closeTo(250, 2));
  });

  test('the dots move with the shift: (272, 288) is a dot, and (278, 294) is it after (6, 6)', () async {
    final still = await _painted(_sunny);
    final drifted = await _painted(_sunny, const Offset(6, 6));
    expect(drifted.at(278, 294), still.at(272, 288));
    // The old centre is 8.5 away from the moved dot (the dots are 3 across),
    // so it is the plain background now.
    expect(drifted.at(272, 288), (124, 200, 248));
  });

  testWidgets('with effects on the sky ticks: after 1 s its shift is (6, 6), and its stars\' clock 1 s', (
    tester,
  ) async {
    await tester.pumpWidget(_sky(_night));
    expect(_shiftOf(tester), Offset.zero);
    expect(_timeOf(tester), Duration.zero);
    await tester.pump(const Duration(seconds: 1));
    expect(_shiftOf(tester), const Offset(6, 6));
    expect(_timeOf(tester), const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(_shiftOf(tester), const Offset(12, 12));
    expect(_timeOf(tester), const Duration(seconds: 2));
  });

  testWidgets('with the effects off the sky stays still', (tester) async {
    await tester.pumpWidget(_sky(_noEffects));
    await tester.pump(const Duration(seconds: 1));
    expect(_shiftOf(tester), Offset.zero);
    expect(_timeOf(tester), Duration.zero);
  });

  testWidgets('with reduced motion asked for the sky stays still', (tester) async {
    await tester.pumpWidget(_sky(_night, reduceMotion: true));
    await tester.pump(const Duration(seconds: 1));
    expect(_shiftOf(tester), Offset.zero);
    expect(_timeOf(tester), Duration.zero);
  });

  testWidgets('under a ToyStillSky above it the sky stays still', (tester) async {
    await tester.pumpWidget(_sky(_night, still: true));
    await tester.pump(const Duration(seconds: 1));
    expect(_shiftOf(tester), Offset.zero);
    expect(_timeOf(tester), Duration.zero);
  });

  testWidgets('a ToyStillSky under the sky holds it; removing the last hold starts the drift', (tester) async {
    Widget tree(int holds) => _sky(
      _sunny,
      child: Column(
        children: [
          const SizedBox(width: 8, height: 8),
          for (var i = 0; i < holds; i++) const ToyStillSky(child: SizedBox(width: 8, height: 8)),
        ],
      ),
    );

    await tester.pumpWidget(tree(1));
    await tester.pump(const Duration(seconds: 1));
    expect(_shiftOf(tester), Offset.zero, reason: 'one holder keeps it still');

    // A second holder arrives; taking either away still leaves one.
    await tester.pumpWidget(tree(2));
    await tester.pump(const Duration(seconds: 1));
    expect(_shiftOf(tester), Offset.zero);
    await tester.pumpWidget(tree(1));
    await tester.pump(const Duration(seconds: 1));
    expect(_shiftOf(tester), Offset.zero, reason: 'the last holder was not the one removed');

    // The last holder goes: the sky drifts from where it stood.
    await tester.pumpWidget(tree(0));
    await tester.pump(const Duration(seconds: 1));
    expect(_shiftOf(tester), const Offset(6, 6));
  });

  testWidgets('a page pushed over a drifting page stops the one below ticking', (tester) async {
    final app = ToyLookScope(
      look: _sunny,
      child: MaterialApp(
        theme: toyTheme(_sunny),
        home: Scaffold(
          body: Column(
            children: [
              const Text('first page'),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('second page')))),
                  child: const Text('push'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(app);
    await tester.pump(const Duration(seconds: 1));

    final below = _painterOf(tester).shift;
    expect(below.value, const Offset(6, 6));

    await tester.tap(find.text('push'));
    await tester.pump();
    // The slide lasts 300 ms; until it ends the page below still ticks.
    await tester.pump(const Duration(milliseconds: 400));
    final stoppedAt = below.value;
    await tester.pump(const Duration(seconds: 1));
    expect(below.value, stoppedAt, reason: 'the opaque page above mutes the sky below it');
  });

  testWidgets('only the sky repaints as it drifts', (tester) async {
    _childBuilds = 0;
    await tester.pumpWidget(_sky(_sunny, child: const _Counted()));
    expect(_childBuilds, 1);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_shiftOf(tester), isNot(Offset.zero));
    expect(_childBuilds, 1, reason: 'the painter repaints from the shift; nothing below is rebuilt');
  });

  test('the painter repaints for a new look, shift or time, not for an equal one', () {
    final shift = ValueNotifier<Offset>(Offset.zero);
    addTearDown(shift.dispose);
    final time = ValueNotifier<Duration>(Duration.zero);
    addTearDown(time.dispose);
    expect(
      ToyBackgroundPainter(
        _sunny,
        shift: shift,
        time: time,
      ).shouldRepaint(ToyBackgroundPainter(_sunny, shift: shift, time: time)),
      isFalse,
      reason: 'an equal look paints the same picture',
    );
    expect(
      ToyBackgroundPainter(
        _night,
        shift: shift,
        time: time,
      ).shouldRepaint(ToyBackgroundPainter(_sunny, shift: shift, time: time)),
      isTrue,
    );
    final other = ValueNotifier<Offset>(Offset.zero);
    addTearDown(other.dispose);
    expect(
      ToyBackgroundPainter(
        _sunny,
        shift: other,
        time: time,
      ).shouldRepaint(ToyBackgroundPainter(_sunny, shift: shift, time: time)),
      isTrue,
    );
    final later = ValueNotifier<Duration>(const Duration(seconds: 1));
    addTearDown(later.dispose);
    expect(
      ToyBackgroundPainter(
        _sunny,
        shift: shift,
        time: later,
      ).shouldRepaint(ToyBackgroundPainter(_sunny, shift: shift, time: time)),
      isTrue,
      reason: 'the twinkle repaints the sky too',
    );
  });
}
