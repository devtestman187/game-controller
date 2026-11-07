part of 'controller_screen.dart';

/// The touch metrics, the mode's controls over whatever this phone shows
/// behind them (m12 §2.7), and the demo readout, in a body of [body].
class _Controls extends ConsumerWidget {
  const _Controls({required this.mode, required this.body});

  final PadMode mode;

  /// Everything below the top bar: the box the touch metrics and the
  /// layouts are measured in.
  final Size body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The touch metrics (M9) see every touch on the controls, and know where
    // each control's touch area is.
    final mm = ref.read(pxPerMmProvider);
    final metrics = ref.read(phoneMetricsProvider)
      ..map = touchMapFor(mode: mode, body: body, mm: mm, sticks: ref.read(stickSettingsProvider));
    // Over a game the controls take the saved opacity (C28); in controller
    // mode there is nothing behind them and they stay opaque.
    final opacity = ref.watch(gameShownProvider)
        ? ref.watch(controlsSettingsProvider).opacity
        : ControlsSettings.maxOpacity;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => metrics.touchDown(e.localPosition.dx / mm, e.localPosition.dy / mm),
      child: Stack(
        children: [
          Positioned.fill(child: ControlsLayer(opacity: opacity)),
          const Positioned(top: 4, left: 0, right: 0, child: Center(child: DemoReadout())),
        ],
      ),
    );
  }
}

/// "Try without a TV" (v2 C23): while no TV is connected, shows what a TV
/// would receive, in every mode.
class DemoReadout extends ConsumerWidget {
  const DemoReadout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(demoProvider);
    final connected = ref.watch(clientStateProvider.select((c) => c.isConnected));
    if (!demo || connected) return const SizedBox.shrink();
    final input = ref.watch(padProvider);
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        key: const Key('demoReadout'),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Demo: a TV would get ${input.isNeutral ? 'nothing pressed' : input.toString()}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13),
        ),
      ),
    );
  }
}

/// Shown instead of the controls when the window is too small for them
/// (v2 C32). Nothing stays held: fingers on the controls are let go.
class TooSmallView extends ConsumerStatefulWidget {
  const TooSmallView({super.key});

  @override
  ConsumerState<TooSmallView> createState() => _TooSmallViewState();
}

class _TooSmallViewState extends ConsumerState<TooSmallView> {
  @override
  void initState() {
    super.initState();
    // The controls under the fingers are gone, so their releases never come.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(padProvider.notifier).releaseAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_full, size: 32),
            const SizedBox(height: 8),
            Text('Make the window bigger', key: const Key('tooSmall'), style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'The controller needs a wider landscape window. Leave split screen, or drag the window larger.',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

void openConnect(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectScreen()));
