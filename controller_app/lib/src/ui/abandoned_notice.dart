import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyCard, ToyLookScope, ToySizes;

import '../providers.dart';

/// What the phone says when the host was away too long (m12 §0.5): the round
/// ended without a winner, and the screen goes back to its controls.
///
/// It sits in a toy card whose header band is bad, so the round's end reads as
/// the bad news it is (M13 3c).
class AbandonedNotice extends ConsumerWidget {
  const AbandonedNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(abandonedNoticeProvider)) return const SizedBox.shrink();
    final look = ToyLookScope.of(context);
    return IgnorePointer(
      child: Center(
        child: ToyCard(
          key: const Key('abandonedNotice'),
          header: PhoneText.roundOver,
          headerColor: look.colors.bad,
          padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space16),
          child: Text(PhoneText.abandoned, style: look.type.body, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
