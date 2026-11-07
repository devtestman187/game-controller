import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// What the phone says when the host was away too long (m12 §0.5): the round
/// ended without a winner, and the screen goes back to its controls.
const abandonedNoticeText = 'The host was away too long, so the round ended.';

/// [abandonedNoticeText] over the game while [abandonedNoticeProvider] says
/// so. It takes no touches, so the controls work under it.
class AbandonedNotice extends ConsumerWidget {
  const AbandonedNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(abandonedNoticeProvider)) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return IgnorePointer(
      child: Center(
        child: Card(
          key: const Key('abandonedNotice'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(abandonedNoticeText, style: text.titleMedium, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
