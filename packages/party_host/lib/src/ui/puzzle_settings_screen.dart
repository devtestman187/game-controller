import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';
import '../providers.dart';
import 'host_button.dart';
import 'host_screen.dart';

/// The puzzle's playtest settings (PRD v2 T16): every tuning value, saved on
/// the host, with Reset to defaults. A change counts in the next frame, also
/// in a puzzle that's already running. Works with the remote.
class PuzzleSettingsScreen extends ConsumerWidget {
  const PuzzleSettingsScreen({super.key});

  static const _rows = [
    ('angleToleranceDeg', HostText.angleTolerance),
    ('positionTolerance', HostText.positionTolerance),
    ('rotationSpeedDegPerS', HostText.rotationSpeed),
    ('stickDeadZone', HostText.stickDeadZone),
    ('pickupRange', HostText.pickupRange),
    ('hintDelayS', HostText.hintDelay),
    ('timeLimitS', HostText.timeLimit),
    ('warningS', HostText.warningPeriod),
    ('soloBigSpeed', HostText.soloBigSpeed),
    ('helpIntervalS', HostText.helpInterval),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(puzzleSettingsProvider);
    final notifier = ref.read(puzzleSettingsProvider.notifier);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostScreen(
        title: HostText.puzzleSettings,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: hostTitleBarPaddingPx),
            child: HostButton(
              key: const Key('resetPuzzleSettings'),
              label: HostText.resetToDefaults,
              icon: Icons.restart_alt,
              onPressed: notifier.reset,
            ),
          ),
        ],
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(ToySizes.space24, ToySizes.space8, ToySizes.space24, ToySizes.space24),
            children: [
              _settingsCard(s, notifier),
              const SizedBox(height: ToySizes.space24),
              _highlightCard(context, s, notifier),
            ],
          ),
        ),
      ),
    );
  }

  /// Every setting on one card: its name, its value and its two step buttons.
  Widget _settingsCard(PuzzleSettings s, PuzzleSettingsNotifier notifier) {
    final json = s.toJson();
    return ToyCard(
      padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, (key, label)) in _rows.indexed)
            _Row(
              key: Key('setting-$key'),
              label: label,
              value: HostText.settingValue(key, json[key]! as num),
              autofocus: i == 0,
              onLess: () => notifier.set(_step(s, key, -1)),
              onMore: () => notifier.set(_step(s, key, 1)),
            ),
        ],
      ),
    );
  }

  /// The drop-ready highlight's switch, on a card of its own.
  Widget _highlightCard(BuildContext context, PuzzleSettings s, PuzzleSettingsNotifier notifier) {
    final look = ToyLookScope.of(context);
    return ToyCard(
      // A tile paints its ink on the nearest Material, and a toy card's paper
      // is a ColoredBox: a Material of its own gives the tile somewhere to
      // paint (as the Look and sound section does).
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          key: const Key('setting-dropReadyHighlight'),
          title: Text(HostText.dropReadyHighlight, style: look.type.button),
          subtitle: Text(HostText.dropReadyLine, style: look.type.body),
          value: s.dropReadyHighlight,
          onChanged: (v) => notifier.set(s.withValue('dropReadyHighlight', v)),
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

/// How wide the value column is, in button heights: room for "1:30" and
/// "55% of the piece" without the two step buttons moving a row apart.
const _valueWidthShare = 3.0;

/// One setting on the paper: its name, its two step buttons and its value.
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
    final look = ToyLookScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ToySizes.space8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: look.type.button)),
          _Step(label: HostText.less, tooltip: HostText.lessOf(label), autofocus: autofocus, onPressed: onLess),
          SizedBox(
            width: look.sizes.buttonHeight * _valueWidthShare,
            child: Text(value, style: look.type.button, textAlign: TextAlign.center),
          ),
          _Step(label: HostText.more, tooltip: HostText.moreOf(label), onPressed: onMore),
        ],
      ),
    );
  }
}

/// One step button, with the tooltip the remote's focus reads.
class _Step extends StatelessWidget {
  const _Step({required this.label, required this.tooltip, required this.onPressed, this.autofocus = false});

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: HostButton(label: label, onPressed: onPressed, autofocus: autofocus),
  );
}
