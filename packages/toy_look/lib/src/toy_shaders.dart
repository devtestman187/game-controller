import 'dart:ui' show Canvas, FragmentProgram, Paint, PictureRecorder, Rect;

/// How big a warm-up draw is, in logical pixels: a few pixels are enough to
/// make the driver compile the program, and the picture is thrown away.
const _warmUpPx = 4.0;

/// The box a warm-up draws into.
const _warmUpRect = Rect.fromLTWH(0, 0, _warmUpPx, _warmUpPx);

/// The look's fragment programs (M13, docs/design/look-and-sound.md section
/// 6), loaded once at start and kept.
///
/// A device whose driver can't load or run a shader keeps the Canvas
/// fallback, so no screen has to check anything: [shade] or [backdrop] is
/// simply null and [error] says what went wrong, for the TV's spike screen to
/// show. Each program is tried on its own, so one that fails never takes the
/// other with it.
final class ToyShaders {
  const ToyShaders._({
    this.shade,
    this.backdrop,
    this.shadeError,
    this.backdropError,
    this.loadMs = 0,
    this.shadeMs = 0,
    this.backdropMs = 0,
  });

  /// The asset key of [shade]: the shader as the build ships it, under the
  /// package's own name.
  static const shadeAsset = 'packages/toy_look/shaders/toy_shade.frag';

  /// The asset key of [backdrop]: the sky behind every page.
  static const backdropAsset = 'packages/toy_look/shaders/toy_backdrop.frag';

  /// No shaders at all: what "effects off" and a device without shaders use.
  static const none = ToyShaders._();

  /// The shader that paints a game object's body, or null when it couldn't
  /// be loaded ([shadeError] says why).
  final FragmentProgram? shade;

  /// The shader that fills the sky, or null when it couldn't be loaded
  /// ([backdropError] says why).
  final FragmentProgram? backdrop;

  /// Why [shade] is null, in words for a test screen; null when it loaded.
  final String? shadeError;

  /// Why [backdrop] is null, in words for a test screen; null when it loaded.
  final String? backdropError;

  /// Every failure, joined, or null when both programs loaded.
  String? get error => switch ((shadeError, backdropError)) {
    (final String shade, final String backdrop) => '$shade; $backdrop',
    (final String shade, null) => shade,
    (null, final String backdrop) => backdrop,
    (null, null) => null,
  };

  /// How long [load] took for both programs, in milliseconds, as the spike
  /// reports it.
  final int loadMs;

  /// [shade]'s load and warm-up, in milliseconds.
  final int shadeMs;

  /// [backdrop]'s load and warm-up, in milliseconds.
  final int backdropMs;

  /// Loads both programs and times them. Never throws: a shader that is
  /// missing, or that the driver refuses, comes back as its own error with no
  /// program, which is the same state as [none].
  ///
  /// Each program is drawn once into a small offscreen picture after it loads
  /// (a warm-up), so the driver compiles it behind the splash rather than on
  /// the first menu, where a first use has stalled for about 1.5 s on Windows
  /// (design section 6). A warm-up that throws counts as that shader failing.
  ///
  /// The asset keys are parameters for a test that asks for keys that aren't
  /// there.
  static Future<ToyShaders> load({
    String shadeAsset = ToyShaders.shadeAsset,
    String backdropAsset = ToyShaders.backdropAsset,
  }) async {
    final watch = Stopwatch()..start();
    final shade = await _loadOne(shadeAsset);
    final backdrop = await _loadOne(backdropAsset);
    return ToyShaders._(
      shade: shade.program,
      backdrop: backdrop.program,
      shadeError: shade.error,
      backdropError: backdrop.error,
      loadMs: watch.elapsedMilliseconds,
      shadeMs: shade.ms,
      backdropMs: backdrop.ms,
    );
  }

  /// One program, loaded and warmed up, or the reason it isn't.
  static Future<({FragmentProgram? program, String? error, int ms})> _loadOne(String asset) async {
    final watch = Stopwatch()..start();
    try {
      final program = await FragmentProgram.fromAsset(asset);
      await _warmUp(program);
      return (program: program, error: null, ms: watch.elapsedMilliseconds);
    } catch (e) {
      // The documented boundary: the engine's shader loader and its driver,
      // which can refuse a shader on any device for reasons Dart can't
      // inspect. The caller gets a state it handles, not an exception.
      return (program: null, error: '$asset: $e', ms: watch.elapsedMilliseconds);
    }
  }

  /// Draws [program] once into a few offscreen pixels and throws the picture
  /// away, so the driver compiles it now rather than on the sky's first frame.
  ///
  /// Its uniforms are left at zero: what this needs is the draw, not a
  /// picture. The [FragmentShader] itself is not disposed — the research
  /// (docs/briefs/m13/research-flutter-shaders-report.md) lists Mali-Vulkan
  /// crashes around disposing shader resources, so it is left to the driver.
  static Future<void> _warmUp(FragmentProgram program) async {
    final recorder = PictureRecorder();
    Canvas(recorder).drawRect(_warmUpRect, Paint()..shader = program.fragmentShader());
    final image = await recorder.endRecording().toImage(_warmUpPx.round(), _warmUpPx.round());
    image.dispose();
  }
}
