import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../layout.dart';
import '../providers.dart';
import 'pad_widgets.dart';
import 'tilt_view.dart';

/// D-pad and gyro modes, laid out by [padLayout]: the D-pad (or the tilt
/// view) on the left, Select and Start in the middle, A/B/X/Y on the right.
class PadModeView extends ConsumerWidget {
  const PadModeView({super.key, required this.gyro});

  final bool gyro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(padProvider);
    final mm = ref.watch(pxPerMmProvider);
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = padLayout(constraints.biggest, mm: mm);
        return Stack(
          children: [
            if (gyro)
              Positioned.fromRect(
                rect: layout.leftArea,
                child: const Center(child: TiltView()),
              )
            else
              Positioned.fromRect(rect: layout.dpad, child: const DpadView()),
            Positioned.fromRect(
              rect: layout.select,
              child: SmallButton(button: ControllerButton.select, label: 'Select', size: layout.select.size),
            ),
            Positioned.fromRect(
              rect: layout.start,
              child: SmallButton(button: ControllerButton.start, label: 'Start', size: layout.start.size),
            ),
            Positioned(
              left: layout.summary.left,
              top: layout.summary.top,
              width: layout.summary.width,
              child: Text(
                input.isNeutral ? 'Nothing pressed' : input.toString(),
                key: const Key('inputSummary'),
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            Positioned.fromRect(rect: layout.faceButtons, child: const FaceButtonsView()),
          ],
        );
      },
    );
  }
}
