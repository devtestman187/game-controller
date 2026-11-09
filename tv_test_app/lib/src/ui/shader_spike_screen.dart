import 'dart:math' show max;
import 'dart:ui' show FragmentProgram;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:party_host/party_host.dart';

import '../tv_text.dart';
import 'shader_spike_rows.dart';
import 'toy_gallery.dart';

/// A row of shapes is this tall, in logical pixels.
const _rowHeight = 180.0;

/// The screen's two sections: the shader rows and the widgets' gallery.
const _tabCount = 2;

/// The shader spike (M13 step 1): proves the Toy Box shader loads and draws on
/// this device, shows the Canvas fallback beside it, and says what a frame
/// costs. Its Widgets tab shows the look's widgets as a TV draws them (step
/// 2b).
///
/// Its words are the look's (M13 3d): the screen is on the palette's
/// background, so its labels and figures are text on the background. The
/// shapes the rows draw are the spike's own test colours, and are kept. Back
/// leaves, like the other test tools.
class ShaderSpikeScreen extends StatefulWidget {
  const ShaderSpikeScreen({super.key});

  @override
  State<ShaderSpikeScreen> createState() => _ShaderSpikeScreenState();
}

class _ShaderSpikeScreenState extends State<ShaderSpikeScreen> with TickerProviderStateMixin {
  /// One whole turn of the shapes, so frames keep coming.
  static const _turnPeriod = Duration(seconds: 8);

  /// The frames the time is averaged and its worst taken over.
  static const _frameWindow = 120;

  /// How many more shapes a row draws with Stress on.
  static const _stressCount = 60;

  /// Which section is shown: the shader rows or the gallery.
  late final TabController _tabs = TabController(length: _tabCount, vsync: this);

  /// The last [_frameWindow] frames' build plus raster time, in milliseconds.
  final _frameMs = <double>[];

  late final AnimationController _turn = AnimationController(vsync: this, duration: _turnPeriod)..repeat();

  /// Null until [ToyShaders.load] answers.
  ToyShaders? _shaders;

  bool _stress = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _load();
  }

  Future<void> _load() async {
    final shaders = await ToyShaders.load();
    if (!mounted) return;
    setState(() => _shaders = shaders);
  }

  /// Adds each frame's build and raster time to the window. The two can
  /// overlap on the GPU, so their sum is a frame's upper bound rather than its
  /// exact cost; it still shows a slow device at once.
  void _onTimings(List<FrameTiming> timings) {
    if (!mounted) return;
    setState(() {
      for (final timing in timings) {
        final ms = (timing.buildDuration + timing.rasterDuration).inMicroseconds;
        _frameMs.add(ms / Duration.microsecondsPerMillisecond);
      }
      if (_frameMs.length > _frameWindow) _frameMs.removeRange(0, _frameMs.length - _frameWindow);
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _tabs.dispose();
    _turn.dispose();
    super.dispose();
  }

  /// What the body shader did, in the brief's wording: on with its load and
  /// warm-up time, or off with the reason.
  String get _shadeLine {
    final shaders = _shaders;
    if (shaders == null) return TvText.shadersLoading;
    return TvText.shaderState(TvText.shadeLabel, shaders.shadeMs, shaders.shadeError);
  }

  /// What the backdrop shader did, in the same wording.
  String get _backdropLine {
    final shaders = _shaders;
    if (shaders == null) return TvText.shadersLoading;
    return TvText.shaderState(TvText.backdropLabel, shaders.backdropMs, shaders.backdropError);
  }

  /// The average and the worst frame time in the window.
  String get _frameText {
    if (_frameMs.isEmpty) return TvText.noFrames;
    final sum = _frameMs.fold<double>(0, (total, ms) => total + ms);
    final worst = _frameMs.reduce(max);
    return TvText.frameTime(_frameMs.length, (sum / _frameMs.length).toStringAsFixed(1), worst.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final onBackground = look.type.body.copyWith(color: look.colors.onBackground);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        backgroundColor: look.colors.background,
        appBar: AppBar(
          title: const Text(TvText.lookTest),
          actions: [_StressButton(stress: _stress, onChanged: (on) => setState(() => _stress = on))],
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: TvText.shapes),
              Tab(text: TvText.widgets),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(controller: _tabs, children: [_shapesTab(look, onBackground), const ToyGallery()]),
        ),
      ),
    );
  }

  /// The shapes tab: what the shaders did, what a frame costs, and the shapes
  /// and skies drawn with and without them.
  Widget _shapesTab(ToyLook look, TextStyle onBackground) {
    return ListView(
      padding: const EdgeInsets.all(ToySizes.space16),
      children: [
        Text(
          _shadeLine,
          key: const Key('shadeStatus'),
          style: look.type.button.copyWith(color: look.colors.onBackground),
        ),
        Text(_backdropLine, key: const Key('backdropStatus'), style: onBackground),
        Text(_frameText, key: const Key('frameStats'), style: onBackground),
        const SizedBox(height: ToySizes.space8),
        Text(TvText.rows(_stressCount), style: onBackground),
        const SizedBox(height: ToySizes.space8),
        _SpikeRow(
          rowKey: const Key('lookRowShader'),
          label: TvText.withShader,
          shade: _shaders?.shade,
          animation: _turn,
          stress: _stress,
        ),
        const SizedBox(height: ToySizes.space12),
        _SpikeRow(
          rowKey: const Key('lookRowFallback'),
          label: TvText.withoutShader,
          shade: null,
          animation: _turn,
          stress: _stress,
        ),
        const SizedBox(height: ToySizes.space12),
        Text(TvText.sky, style: onBackground),
        const SizedBox(height: ToySizes.space4),
        SizedBox(
          height: _rowHeight,
          child: Row(
            children: [
              _SkyBox(palette: ToyPalette.sunny, shaders: _shaders),
              const SizedBox(width: ToySizes.space8),
              const _SkyBox(palette: ToyPalette.sunny, shaders: ToyShaders.none),
              const SizedBox(width: ToySizes.space12),
              _SkyBox(palette: ToyPalette.night, shaders: _shaders),
              const SizedBox(width: ToySizes.space8),
              const _SkyBox(palette: ToyPalette.night, shaders: ToyShaders.none),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Stress button: its label says whether the extra shapes are drawn.
class _StressButton extends StatelessWidget {
  const _StressButton({required this.stress, required this.onChanged});

  final bool stress;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return Padding(
      padding: const EdgeInsets.only(right: ToySizes.space16),
      child: FilledButton.tonal(
        key: const Key('stressToggle'),
        autofocus: true,
        onPressed: () => onChanged(!stress),
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colors.ink),
          backgroundColor: WidgetStatePropertyAll(colors.paper),
          // Lit shows as the look's focus colour round the button.
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused) ? colors.focus : colors.ink,
              width: look.sizes.outlineWidth,
            ),
          ),
        ),
        child: Text(stress ? TvText.stressOn : TvText.stressOff),
      ),
    );
  }
}

/// One of the spike's four skies (design section 6): a `ToyBackground` in one
/// palette, drifting as the menus draw it, with the backdrop shader when it
/// loaded and the Canvas dots otherwise. Each palette is shown with the shader
/// and then with [ToyShaders.none], side by side, so a device shows whether
/// the two fills draw the same sky.
class _SkyBox extends StatelessWidget {
  const _SkyBox({required this.palette, required this.shaders});

  /// The palette this sky is drawn in.
  final ToyPalette palette;

  /// The shaders the spike loaded, or null while they load.
  final ToyShaders? shaders;

  @override
  Widget build(BuildContext context) {
    final look = ToyLook.build(palette: palette, tv: true, shaders: shaders ?? ToyShaders.none);
    // The label stands on the screen's own sky, so it takes the screen's text
    // colour, not the box's: a Night label is white, unreadable on Sunny.
    final screen = ToyLookScope.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            [
              palette == ToyPalette.sunny ? TvText.skySunny : TvText.skyNight,
              if (identical(shaders, ToyShaders.none)) TvText.skyFallback,
            ].join(', '),
            style: screen.type.body.copyWith(color: screen.colors.onBackground),
          ),
          const SizedBox(height: ToySizes.space4),
          Expanded(
            child: ToyLookScope(
              look: look,
              child: const ClipRect(child: ToyBackground()),
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled row of shapes, redrawn while its [animation] runs.
class _SpikeRow extends StatelessWidget {
  const _SpikeRow({
    required this.rowKey,
    required this.label,
    required this.shade,
    required this.animation,
    required this.stress,
  });

  final Key rowKey;
  final String label;
  final FragmentProgram? shade;
  final Animation<double> animation;
  final bool stress;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: look.type.body.copyWith(color: look.colors.onBackground)),
        const SizedBox(height: ToySizes.space4),
        SizedBox(
          height: _rowHeight,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) => CustomPaint(
              key: rowKey,
              size: Size.infinite,
              painter: ShaderSpikePainter(shade: shade, turn: animation.value, stress: stress),
            ),
          ),
        ),
      ],
    );
  }
}
