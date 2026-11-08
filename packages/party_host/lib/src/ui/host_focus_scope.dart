import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// The phone app's touch-first wrapper (m12 bug 1107f rules A and B): every
/// screen, menu and dialog a phone that hosts draws is inside it.
///
/// A finger on the phone hides the focus look ([hostFocusLookProvider]), which
/// shows again only when a pad moves the focus; while it is hidden, Material's
/// own focus overlay goes too, so no list row, switch or dialog button keeps a
/// highlight a thumb can't take away. A host that isn't touch first gets its
/// child untouched, so the TV and the Windows app look and work as they did.
class HostFocusScope extends ConsumerWidget {
  const HostFocusScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hostTouchFirstProvider)) return child;
    final showFocus = ref.watch(hostFocusLookProvider);
    return Listener(
      // Any finger, on a button or not, counts; a translucent listener sees
      // those on empty space too and blocks nothing.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(hostFocusLookProvider.notifier).touched(),
      child: showFocus
          ? child
          : Theme(
              data: Theme.of(context).copyWith(focusColor: Colors.transparent),
              child: child,
            ),
    );
  }
}
