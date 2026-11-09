part of 'controller_screen.dart';

/// The pad on top of whatever this phone shows behind it (m12 §2.7).
///
/// While this phone hosts, the pad is not built outside a round
/// (m12-host-touch rules 1, 2): the host's menus are touch screens then, and a
/// pad built but hidden would keep the held finger's pointer route, for a
/// release that comes after the round.
class _Controls extends ConsumerWidget {
  const _Controls({required this.mode, required this.body, required this.hosting, this.controls = true});

  final PadMode mode;

  /// Everything below the top bar: the box the touch metrics and the
  /// layouts are measured in. The game behind the controls is bigger than
  /// this: it fills the safe area, under the bar too (m12 §5).
  final Size body;

  /// This phone hosts: what it shows behind the pad is its own game.
  final bool hosting;

  /// False for "Show on this device" (C34): nothing to play with here, so
  /// the game alone is drawn and no touch is watched.
  final bool controls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!controls) return const SizedBox.shrink();
    if (!hosting) return _Pad(mode: mode, body: body);
    return ValueListenableBuilder<party.RoundPhase>(
      valueListenable: ref.watch(party.roundPhaseProvider),
      builder: (context, phase, _) =>
          phase == party.RoundPhase.none ? const SizedBox.shrink() : _Pad(mode: mode, body: body),
    );
  }
}

/// The touch metrics, the mode's controls over whatever this phone shows
/// behind them (m12 §2.7), and the demo readout, in a body of [body].
class _Pad extends ConsumerWidget {
  const _Pad({required this.mode, required this.body});

  final PadMode mode;
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
    final showsGame = ref.watch(showsGameProvider);
    final opacity = showsGame ? ref.watch(controlsSettingsProvider).opacity : ControlsSettings.maxOpacity;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => metrics.touchDown(e.localPosition.dx / mm, e.localPosition.dy / mm),
      child: Stack(
        children: [
          Positioned.fill(child: ControlsLayer(opacity: opacity)),
          if (!showsGame) const Positioned(top: 4, left: 0, right: 0, child: Center(child: DemoReadout())),
        ],
      ),
    );
  }
}

/// The waiting card (m12-joined-view §0.3) while this phone waits for the host
/// it plays with, and nothing otherwise.
///
/// It is drawn here rather than inside the game behind the controls, because
/// its Leave game button must be reachable: the pad covers the game, and a
/// button under the pad's Start and Select could never be tapped.
class _WaitingOverlay extends ConsumerWidget {
  const _WaitingOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wait = ref.watch(hostWaitProvider);
    if (wait == null) return const SizedBox.shrink();
    return WaitingCard(wait: wait);
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
    // The look's paper and ink, so the readout sits on the pad like the rest
    // (M13 step 8, rule 8).
    final look = party.ToyLookScope.of(context);
    return IgnorePointer(
      child: Container(
        key: const Key('demoReadout'),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: look.colors.paper.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Demo: a TV would get ${input.isNeutral ? 'nothing pressed' : input.toString()}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: look.colors.ink, fontSize: 13),
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
