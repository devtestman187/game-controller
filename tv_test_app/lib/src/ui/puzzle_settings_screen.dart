import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../providers.dart';
import 'tv_button.dart';

/// The puzzle's playtest settings (PRD v2 T16): every tuning value, saved on
/// the TV, with Reset to defaults. A change counts in the next frame, also in
/// a puzzle that's already running. Works with the remote.
class PuzzleSettingsScreen extends ConsumerWidget {
  const PuzzleSettingsScreen({super.key});

  static const _rows = [
    ('angleToleranceDeg', 'Angle tolerance', '±'),
    ('positionTolerance', 'Position tolerance', ''),
    ('rotationSpeedDegPerS', 'Rotation speed (X and Y)', ''),
    ('stickDeadZone', 'Right-stick dead zone (rotation)', ''),
    ('pickupRange', 'Pickup range', ''),
    ('hintDelayS', 'Hint glow delay', ''),
    ('timeLimitS', 'Time limit', ''),
    ('warningS', 'Warning period', ''),
    ('soloBigSpeed', 'Solo big-piece speed (teams, M11)', ''),
    ('helpIntervalS', 'Help haptic interval (teams, M11)', ''),
  ];

  static String format(String key, num v) => switch (key) {
    'angleToleranceDeg' => '±${v.round()}°',
    'positionTolerance' => '${(v * 100).round()}% of the piece',
    'rotationSpeedDegPerS' => '${v.round()}° a second',
    'stickDeadZone' => '${(v * 100).round()}% push',
    'pickupRange' => '${v.toStringAsFixed(2)} piece radius',
    'soloBigSpeed' => '${(v * 100).round()}% of normal',
    'timeLimitS' => '${v ~/ 60}:${(v.round() % 60).toString().padLeft(2, '0')}',
    _ => '${v % 1 == 0 ? v.round() : v.toStringAsFixed(1)} s',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(puzzleSettingsProvider);
    final notifier = ref.read(puzzleSettingsProvider.notifier);
    final json = s.toJson();
    final text = Theme.of(context).textTheme;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Puzzle settings'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TvButton(
                key: const Key('resetPuzzleSettings'),
                label: 'Reset to defaults',
                icon: Icons.restart_alt,
                onPressed: notifier.reset,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              for (final (i, (key, label, _)) in _rows.indexed)
                _Row(
                  key: Key('setting-$key'),
                  label: label,
                  value: format(key, json[key]! as num),
                  autofocus: i == 0,
                  onLess: () => notifier.set(_step(s, key, -1)),
                  onMore: () => notifier.set(_step(s, key, 1)),
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('setting-dropReadyHighlight'),
                title: Text('Drop-ready highlight', style: text.titleMedium),
                subtitle: const Text('The outline brightens and the phone ticks when a piece is close enough'),
                value: s.dropReadyHighlight,
                onChanged: (v) => notifier.set(s.withValue('dropReadyHighlight', v)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static PuzzleSettings _step(PuzzleSettings s, String key, int direction) {
    final r = PuzzleSettings.ranges[key]!;
    final now = (s.toJson()[key]! as num).toDouble();
    final next = ((now + direction * r.step) / r.step).round() * r.step;
    return s.withValue(key, next.clamp(r.min, r.max));
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.label,
    required this.value,
    required this.onLess,
    required this.onMore,
    this.autofocus = false,
  });

  final String label;
  final String value;
  final VoidCallback onLess;
  final VoidCallback onMore;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.titleMedium)),
          _Step(label: '−', tooltip: 'Less $label', autofocus: autofocus, onPressed: onLess),
          SizedBox(
            width: 200,
            child: Text(value, style: text.titleLarge, textAlign: TextAlign.center),
          ),
          _Step(label: '+', tooltip: 'More $label', onPressed: onMore),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.tooltip, required this.onPressed, this.autofocus = false});

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonal(
        autofocus: autofocus,
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(56, 44)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          side: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? BorderSide(color: scheme.primary, width: 4) : BorderSide.none,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
