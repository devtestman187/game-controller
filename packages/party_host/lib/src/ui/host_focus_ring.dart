import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../providers.dart';

/// The toy's focus ring round a Material control on a host screen (M13, the
/// owner's Nov 9, 2026 note): a switch, a slider, a segment or the title bar's
/// back arrow shows the host's focus look as the ring a [ToyButton] and a card
/// show, rather than as the faint wash Material paints.
///
/// It follows the host's focus look, so a touch-first host shows it only once a
/// pad moves the focus, and a touch takes it away again (M12 bug 1107f).
class HostFocusRing extends ConsumerWidget {
  const HostFocusRing({super.key, required this.child});

  /// The control, which takes and keeps the focus itself.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ToyFocusRing(showFocus: ref.watch(hostFocusLookProvider), child: child);
}
