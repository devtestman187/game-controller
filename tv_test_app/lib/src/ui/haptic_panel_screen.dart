import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';
import 'package:protocol/protocol.dart';

import '../tv_text.dart';
import 'status_line.dart';

/// The haptic test panel (PRD T6): fires each haptic event on every connected
/// controller, with its sound on the TV. Works with the remote (arrows and
/// OK) and with a mouse or keyboard.
///
/// Its rows are in the look (M13 3d): a sheet of paper with the ink edge holds
/// the events and the steppers, so everything a tester reads is ink on paper.
class HapticPanelScreen extends ConsumerStatefulWidget {
  const HapticPanelScreen({super.key});

  @override
  ConsumerState<HapticPanelScreen> createState() => _HapticPanelScreenState();
}

/// Duration choices. Null is each event's natural length.
const _durations = <int?>[null, 100, 200, 300, 500, 800, 1200, 2000];

const _feel = {
  HapticEvent.hit: (TvText.hit, Icons.sports_mma, TvText.hitLine),
  HapticEvent.success: (TvText.success, Icons.emoji_events_outlined, TvText.successLine),
  HapticEvent.error: (TvText.error, Icons.block, TvText.errorLine),
  HapticEvent.rumble: (TvText.rumble, Icons.graphic_eq, TvText.rumbleLine),
  HapticEvent.snap: (TvText.snap, Icons.lock_outline, TvText.snapLine),
  HapticEvent.wrong: (TvText.wrong, Icons.close, TvText.wrongLine),
  HapticEvent.dropReady: (TvText.dropReady, Icons.adjust, TvText.dropReadyLine),
  HapticEvent.help: (TvText.help, Icons.front_hand_outlined, TvText.helpLine),
  HapticEvent.tick: (TvText.tick, Icons.timer_outlined, TvText.tickLine),
};

/// The event's sound file, "none" for events without a sound.
String _soundOf(SoundStatus sounds, HapticEvent event) {
  final key = SoundKey.byEventName(event.name);
  if (key == null) return 'none';
  return sounds.files[key] ?? (sounds.error == null ? 'loading…' : 'off');
}

class _HapticPanelScreenState extends ConsumerState<HapticPanelScreen> {
  double _intensity = 1;
  int _duration = 0; // Index into _durations.

  void _fire(HapticEvent event) => ref
      .read(tvEventsProvider.notifier)
      .fire(
        HapticEventMessage(event: event, intensity: _intensity, durationMs: _durations[_duration]),
        source: 'panel',
      );

  @override
  Widget build(BuildContext context) {
    final sounds = ref.watch(soundStatusProvider);
    final last = ref.watch(tvEventsProvider);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        appBar: AppBar(title: const Text(TvText.hapticTest), actions: [_Targets()]),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(ToySizes.space8),
            children: [
              _Sheet(
                sounds: sounds,
                last: last,
                intensity: _intensity,
                durationMs: _durations[_duration],
                onFire: _fire,
                onIntensity: (by) => setState(() => _intensity = _step(_intensity, by)),
                onDuration: (by) => setState(() => _duration = (_duration + by).clamp(0, _durations.length - 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The panel's sheet of paper: the events, the steppers, and what the last
/// press did.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.sounds,
    required this.last,
    required this.intensity,
    required this.durationMs,
    required this.onFire,
    required this.onIntensity,
    required this.onDuration,
  });

  final SoundStatus sounds;
  final FiredEvent? last;
  final double intensity;

  /// The chosen duration, or null for each event's natural length.
  final int? durationMs;

  final void Function(HapticEvent event) onFire;
  final void Function(double by) onIntensity;
  final void Function(int by) onDuration;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final last = this.last;
    return ToyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventButtons(sounds: sounds, onFire: onFire),
          const SizedBox(height: ToySizes.space24),
          _Steppers(intensity: intensity, durationMs: durationMs, onIntensity: onIntensity, onDuration: onDuration),
          const SizedBox(height: ToySizes.space8),
          Text(
            TvText.naturalLengths(
              HapticEvent.hit.defaultDurationMs,
              HapticEvent.success.defaultDurationMs,
              HapticEvent.error.defaultDurationMs,
              HapticEvent.rumble.defaultDurationMs,
            ),
            style: _soft(context),
          ),
          const SizedBox(height: ToySizes.space24),
          Text(
            last == null
                ? TvText.nothingSent
                : TvText.lastSent(
                    last.message.event.name,
                    (last.message.intensity * 100).round(),
                    last.message.durationMs,
                    last.source,
                    last.reached == 0 ? TvText.nothingReached : TvText.reachedControllers(last.reached),
                  ),
            key: const Key('lastSent'),
            style: _ink(context, look: look.type.button),
          ),
          if (sounds.error != null) ...[
            const SizedBox(height: ToySizes.space8),
            StatusLine(label: TvText.soundsOff(sounds.error!), color: look.colors.bad),
          ],
        ],
      ),
    );
  }
}

/// A secondary line: the ink, softened, on the card's paper.
TextStyle _soft(BuildContext context) {
  final look = ToyLookScope.of(context);
  return look.type.body.copyWith(color: look.colors.inkSoft);
}

/// A line in the card's ink, at [look]'s style.
TextStyle _ink(BuildContext context, {required TextStyle look}) =>
    look.copyWith(color: ToyLookScope.of(context).colors.ink);

/// Which controllers the presses go to. It sits in the app bar, on the
/// background, so it is text on the background and not a paper status.
class _Targets extends ConsumerWidget {
  const _Targets();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A phone that is away wouldn't feel it (m12 bug 1107d).
    final players = ref.watch(gamePlayersProvider).where((p) => !p.local && !p.away).toList();
    return Padding(
      padding: const EdgeInsets.only(right: ToySizes.space24),
      child: Center(
        child: Text(
          players.isEmpty ? TvText.noTargets : TvText.sendsTo(players.map((p) => p.label).join(', ')),
          key: const Key('panelTargets'),
        ),
      ),
    );
  }
}

/// A button for each haptic event, with what it feels like and its sound.
class _EventButtons extends StatelessWidget {
  const _EventButtons({required this.sounds, required this.onFire});

  /// A cell's width: wide enough for an event's words at the TV's type.
  static const cellWidth = 200.0;

  /// The button's height: the look's TV button, with room for the icon.
  static const _buttonHeight = 72.0;

  final SoundStatus sounds;
  final void Function(HapticEvent event) onFire;

  @override
  Widget build(BuildContext context) {
    final ink = _ink(context, look: ToyLookScope.of(context).type.body);
    final soft = _soft(context);
    return Wrap(
      spacing: ToySizes.space16,
      runSpacing: ToySizes.space16,
      children: [
        for (final (i, event) in HapticEvent.values.indexed)
          SizedBox(
            width: cellWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _buttonHeight,
                  child: HostButton(
                    key: Key('fire-${event.name}'),
                    label: _feel[event]!.$1,
                    icon: _feel[event]!.$2,
                    autofocus: i == 0,
                    onPressed: () => onFire(event),
                  ),
                ),
                const SizedBox(height: ToySizes.space4),
                Text(_feel[event]!.$3, style: ink),
                Text(TvText.sound(_soundOf(sounds, event)), style: soft, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
      ],
    );
  }
}

/// The intensity and duration steps.
class _Steppers extends StatelessWidget {
  const _Steppers({
    required this.intensity,
    required this.durationMs,
    required this.onIntensity,
    required this.onDuration,
  });

  final double intensity;

  /// The chosen duration, or null for each event's natural length.
  final int? durationMs;

  /// Moves the intensity by a step of 0.1.
  final void Function(double by) onIntensity;

  /// Moves the duration up or down the list by one.
  final void Function(int by) onDuration;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: ToySizes.space32,
    runSpacing: ToySizes.space16,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _Stepper(
        label: TvText.intensity,
        value: TvText.percent((intensity * 100).round()),
        valueKey: const Key('intensityValue'),
        onLess: () => onIntensity(-0.1),
        onMore: () => onIntensity(0.1),
      ),
      _Stepper(
        label: TvText.duration,
        value: durationMs == null ? TvText.natural : TvText.durationMs(durationMs!),
        valueKey: const Key('durationValue'),
        onLess: () => onDuration(-1),
        onMore: () => onDuration(1),
      ),
    ],
  );
}

double _step(double v, double by) => ((v + by).clamp(0.1, 1.0) * 10).round() / 10;

/// Less and more buttons stay enabled at the limits (they just don't change
/// the value), so the remote's focus never lands on a disabled button.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.onLess,
    required this.onMore,
  });

  final String label;
  final String value;
  final Key valueKey;
  final VoidCallback onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: look.type.button.copyWith(color: look.colors.ink)),
        const SizedBox(width: ToySizes.space12),
        _SmallTvButton(label: HostText.less, tooltip: HostText.lessOf(label), onPressed: onLess),
        SizedBox(
          width: 110,
          child: Text(
            value,
            key: valueKey,
            style: look.type.button.copyWith(color: look.colors.ink),
            textAlign: TextAlign.center,
          ),
        ),
        _SmallTvButton(label: HostText.more, tooltip: HostText.moreOf(label), onPressed: onMore),
      ],
    );
  }
}

class _SmallTvButton extends StatelessWidget {
  const _SmallTvButton({required this.label, required this.tooltip, this.onPressed});

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(56, 48)),
          textStyle: WidgetStatePropertyAll(look.type.button.copyWith(fontSize: 24)),
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
        child: Text(label),
      ),
    );
  }
}
