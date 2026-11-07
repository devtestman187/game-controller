import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controls_settings.dart';
import '../gyro.dart';
import 'pad_mode_view.dart';
import 'stick_widgets.dart';

/// The controls of the current mode drawn over [child] (m12 §2.7): a game
/// behind, or nothing in controller mode. Only the controls take touches;
/// a touch anywhere else reaches [child]. Opacity never moves or resizes a
/// control or its touch area (C14 to C16).
class ControlsLayer extends ConsumerWidget {
  const ControlsLayer({required this.opacity, this.child = const SizedBox.shrink(), super.key});

  /// [ControlsSettings.minOpacity] to [ControlsSettings.maxOpacity] over a
  /// game, or exactly 1.0 in controller mode.
  final double opacity;

  /// Drawn behind the controls: the game, when this phone shows one.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(
      opacity >= ControlsSettings.minOpacity && opacity <= ControlsSettings.maxOpacity,
      'opacity $opacity is outside ${ControlsSettings.minOpacity} to ${ControlsSettings.maxOpacity}',
    );
    final mode = ref.watch(gyroProvider.select((g) => g.mode));
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: RepaintBoundary(
              child: mode == PadMode.sticks ? const StickModeView() : PadModeView(gyro: mode == PadMode.gyro),
            ),
          ),
        ),
      ],
    );
  }
}
