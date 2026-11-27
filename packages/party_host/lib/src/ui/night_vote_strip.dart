import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../night/night_vote.dart';
import '../text/variant_text.dart';

/// The night's vote on the TV: while it is open the call to vote, the seconds left and the offered games; once it has
/// settled, the game that won. Nothing while no vote has run.
///
/// It sizes itself from the look's own body type and wraps its words, so it grows with the TV look and never has a
/// fixed height: the frame it sits in is drawn at the device's scale.
class NightVoteStrip extends ConsumerWidget {
  const NightVoteStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vote = ref.watch(nightVoteProvider);
    if (vote == null) return const SizedBox.shrink();
    final look = ToyLookScope.of(context);
    final style = look.type.body.copyWith(color: look.colors.onBackground);
    final result = vote.result;
    final lines = result == null
        ? [VoteText.voteNow, VoteText.secondsLeft(vote.secondsLeft), vote.offered.map(variantLabel).join(' · ')]
        : [
            result.byChance
                ? VoteText.byChance(variantLabel(result.variant))
                : VoteText.wins(variantLabel(result.variant)),
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ToySizes.space8),
      child: Column(
        key: const Key('nightVoteStrip'),
        mainAxisSize: MainAxisSize.min,
        children: [for (final line in lines) Text(line, style: style, textAlign: TextAlign.center)],
      ),
    );
  }
}
