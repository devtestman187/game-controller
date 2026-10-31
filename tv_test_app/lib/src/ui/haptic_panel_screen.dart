import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';
import 'tv_button.dart';

/// The haptic test panel (PRD T6): fires each haptic event on every connected
/// controller, with its sound on the TV. Works with the remote (arrows and
/// OK) and with a mouse or keyboard.
class HapticPanelScreen extends ConsumerStatefulWidget {
  const HapticPanelScreen({super.key});

  @override
  ConsumerState<HapticPanelScreen> createState() => _HapticPanelScreenState();
}

/// Duration choices. Null is each event's natural length.
const _durations = <int?>[null, 100, 200, 300, 500, 800, 1200, 2000];

const _feel = {
  HapticEvent.hit: ('Hit', Icons.sports_mma, 'One heavy thump'),
  HapticEvent.success: ('Success', Icons.emoji_events_outlined, 'Three rising taps'),
  HapticEvent.error: ('Error', Icons.block, 'Two sharp buzzes'),
  HapticEvent.rumble: ('Rumble', Icons.graphic_eq, 'A low, wobbling buzz'),
};

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
    final players = ref.watch(gamePlayersProvider).where((p) => !p.local).toList();
    final sounds = ref.watch(soundStatusProvider);
    final last = ref.watch(tvEventsProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ms = _durations[_duration];

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Haptic test'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Center(
                child: Text(
                  players.isEmpty
                      ? 'No controller connected (sounds still play)'
                      : 'Sends to ${players.map((p) => p.label).join(', ')}',
                  key: const Key('panelTargets'),
                  style: text.titleMedium?.copyWith(color: players.isEmpty ? Colors.amberAccent : null),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final (i, event) in HapticEvent.values.indexed)
                    SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 72,
                            child: TvButton(
                              key: Key('fire-${event.name}'),
                              label: _feel[event]!.$1,
                              icon: _feel[event]!.$2,
                              autofocus: i == 0,
                              onPressed: () => _fire(event),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_feel[event]!.$3, style: text.bodyMedium),
                          Text(
                            'Sound: ${sounds.files[event] ?? (sounds.error == null ? 'loading…' : 'off')}',
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 32,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Stepper(
                    label: 'Intensity',
                    value: '${(_intensity * 100).round()}%',
                    valueKey: const Key('intensityValue'),
                    onLess: () => setState(() => _intensity = _step(_intensity, -0.1)),
                    onMore: () => setState(() => _intensity = _step(_intensity, 0.1)),
                  ),
                  _Stepper(
                    label: 'Duration',
                    value: ms == null ? 'Natural' : '$ms ms',
                    valueKey: const Key('durationValue'),
                    onLess: () => setState(() => _duration = (_duration - 1).clamp(0, _durations.length - 1)),
                    onMore: () => setState(() => _duration = (_duration + 1).clamp(0, _durations.length - 1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Natural lengths: hit ${HapticEvent.hit.defaultDurationMs} ms, success '
                '${HapticEvent.success.defaultDurationMs} ms, error ${HapticEvent.error.defaultDurationMs} ms, '
                'rumble ${HapticEvent.rumble.defaultDurationMs} ms. A longer duration stretches the pattern; '
                'for rumble it is simply how long it lasts.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Text(
                last == null
                    ? 'Nothing sent yet.'
                    : 'Last: ${last.message.event.name}, ${(last.message.intensity * 100).round()}%, '
                          '${last.message.durationMs} ms (${last.source}) → '
                          '${last.reached == 0 ? 'no controller' : '${last.reached} controller${last.reached == 1 ? '' : 's'}'}',
                key: const Key('lastSent'),
                style: text.titleMedium,
              ),
              if (sounds.error != null)
                Text('Sounds are off: ${sounds.error}', style: text.bodyMedium?.copyWith(color: scheme.error)),
            ],
          ),
        ),
      ),
    );
  }
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
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: text.titleMedium),
        const SizedBox(width: 12),
        _SmallTvButton(label: '−', tooltip: 'Less $label', onPressed: onLess),
        SizedBox(
          width: 110,
          child: Text(value, key: valueKey, style: text.titleLarge, textAlign: TextAlign.center),
        ),
        _SmallTvButton(label: '+', tooltip: 'More $label', onPressed: onMore),
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
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(56, 48)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          side: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? BorderSide(color: scheme.primary, width: 4) : BorderSide.none,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
