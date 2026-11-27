import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../night/night_vote.dart';
import '../text/host_text.dart';
import '../text/variant_text.dart';
import 'host_button.dart';
import 'host_frame_screen.dart';
import 'night_footer_buttons.dart';
import 'night_vote_strip.dart';

/// How long the winner stays on the screen before the night starts, in seconds: long enough to read "X wins!".
const nightVoteShowResultS = 2;

/// The vote for the night's first game, on the start card's way in (owner Nov 27): the phones vote while this screen
/// shows the offer and the countdown, then the winner for [nightVoteShowResultS] s, and it pops with true so the night
/// starts. Back cancels the vote and pops false, so no night starts.
class NightVoteScreen extends ConsumerStatefulWidget {
  const NightVoteScreen({super.key});

  @override
  ConsumerState<NightVoteScreen> createState() => _NightVoteScreenState();
}

class _NightVoteScreenState extends ConsumerState<NightVoteScreen> {
  /// The round the vote picks the game for: the night has not started, so it is the first.
  static const _firstRound = 1;

  Timer? _shown;

  @override
  void initState() {
    super.initState();
    // A vote left from an earlier night must not stand in for this one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vote = ref.read(nightVoteProvider.notifier);
      vote.cancel();
      unawaited(vote.run(_firstRound));
    });
  }

  @override
  void dispose() {
    _shown?.cancel();
    super.dispose();
  }

  void _onVote(NightVoteState? vote) {
    if (vote == null || vote.isOpen || _shown != null) return;
    _shown = Timer(const Duration(seconds: nightVoteShowResultS), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nightVoteProvider, (_, next) => _onVote(next));
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: PopScope(
        // Leaving any way but the winner's pop takes the vote with it.
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && result != true) ref.read(nightVoteProvider.notifier).cancel();
        },
        child: HostFrameScreen(
          title: VoteText.firstGame,
          body: const Center(child: NightVoteStrip()),
          footer: [
            SizedBox(
              width: nightFooterButtonWidthFor(context, HostText.back),
              child: HostButton(
                key: const Key('voteBack'),
                label: HostText.back,
                icon: Icons.arrow_back,
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
