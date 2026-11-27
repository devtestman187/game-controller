import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyButton, ToyCard, ToyLookScope, ToySizes;
import 'package:protocol/protocol.dart';

import '../providers.dart';
import 'choices_result.dart';

/// The smallest a tappable control is, in dp, so a thumb hits it (design touch rule).
const _minTouchDp = 48.0;

/// How often the countdown reads the clock again, in milliseconds: once a second is as fine as "12 s" reads.
const _countdownTickMs = 1000;

/// Milliseconds in a second, to show the countdown in whole seconds.
const _msPerS = 1000;

/// The widest the round's column grows, in logical pixels: on a tablet or a wide window the cards stay a
/// readable column instead of stretching across it. The round's padding takes 16 dp on each side, so the cap
/// bites from 512 dp of screen width (480 + 2 x 16; M17 phone1b).
const choicesColumnMaxWidthPx = 480.0;

/// How much of a disabled card's look is left, as an opacity share: greyed, but still readable.
const _disabledOpacity = 0.5;

/// The choice round over the pad (M17 phone1b): nothing while the host has sent none. It is not a game: it
/// shows whatever round the host asks this phone to choose in.
class ChoicesOverlay extends ConsumerWidget {
  const ChoicesOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(choicesProvider);
    if (state == null) return const SizedBox.shrink();
    return ChoicesScreen(state: state);
  }
}

/// The round's cards, countdown and lock-in, or its result once the host ended it.
class ChoicesScreen extends ConsumerWidget {
  const ChoicesScreen({super.key, required this.state});

  final ChoicesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final end = state.end;
    final title = Text(
      state.message.title,
      key: const Key('choicesTitle'),
      textAlign: TextAlign.center,
      style: look.type.title.copyWith(color: look.colors.onBackground),
    );
    return Material(
      color: look.colors.background,
      child: Padding(
        padding: const EdgeInsets.all(ToySizes.space16),
        child: Center(
          child: ConstrainedBox(
            key: const Key('choicesColumn'),
            constraints: const BoxConstraints(maxWidth: choicesColumnMaxWidthPx),
            // The title and the countdown scroll with the cards, so a short window (the menu under the top
            // bar) never overflows; only the lock button stays put.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (end == null) ...[
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          title,
                          const SizedBox(height: ToySizes.space8),
                          _Countdown(state: state),
                          const SizedBox(height: ToySizes.space8),
                          _Cards(state: state),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ToySizes.space8),
                  _LockButton(locked: state.locked),
                ] else ...[
                  title,
                  const SizedBox(height: ToySizes.space8),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: ChoicesResult(state: state, end: end),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The time left, counted on the phone's own clock, and the "Paused" chip while the host holds the round.
class _Countdown extends ConsumerStatefulWidget {
  const _Countdown({required this.state});

  final ChoicesState state;

  @override
  ConsumerState<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<_Countdown> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: _countdownTickMs), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final leftMs = widget.state.remainingMs(ref.read(clientProvider).nowMs);
    final seconds = (leftMs / _msPerS).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          PhoneText.choicesSeconds(seconds),
          key: const Key('choicesCountdown'),
          style: look.type.clock.copyWith(color: look.colors.onBackground),
        ),
        if (widget.state.isPaused) ...[
          const SizedBox(width: ToySizes.space12),
          DecoratedBox(
            key: const Key('choicesPaused'),
            decoration: BoxDecoration(
              color: look.colors.caution,
              borderRadius: BorderRadius.circular(ToySizes.cardCorner),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ToySizes.space12, vertical: ToySizes.space4),
              child: Text(PhoneText.choicesPaused, style: look.type.button.copyWith(color: look.colors.ink)),
            ),
          ),
        ],
      ],
    );
  }
}

/// The cards, one column; the screen scrolls it when it does not fit.
class _Cards extends StatelessWidget {
  const _Cards({required this.state});

  final ChoicesState state;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final card in state.message.cards)
        Padding(
          padding: const EdgeInsets.only(bottom: ToySizes.space8),
          child: _CardTile(card: card, state: state),
        ),
    ],
  );
}

class _CardTile extends ConsumerWidget {
  const _CardTile({required this.card, required this.state});

  final ChoiceCard card;
  final ChoicesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    final notifier = ref.read(choicesProvider.notifier);
    final isPicked = state.picked == card.id;
    final detail = card.detail;
    final cost = card.cost;
    final lines = [
      ?detail,
      if (cost != null) PhoneText.choicesCostEach(cost, state.message.currency),
      if (card.id == state.message.defaultId) PhoneText.choicesDefault,
    ];
    return Opacity(
      opacity: card.enabled ? 1 : _disabledOpacity,
      child: GestureDetector(
        key: Key('choiceCard_${card.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => notifier.pick(card.id),
        child: ToyCard(
          popIn: false,
          header: choiceCardLabel(card, isPicked ? state.count : 1),
          headerColor: isPicked ? look.colors.good : null,
          padding: const EdgeInsets.all(ToySizes.space12),
          child: Row(
            children: [
              Expanded(
                child: Text(lines.join('\n'), style: look.type.body.copyWith(color: look.colors.ink)),
              ),
              if (card.maxCount > 1) ...[
                _StepButton(
                  key: Key('choiceMinus_${card.id}'),
                  label: '-',
                  onTap: isPicked && state.count > 1 ? () => notifier.step(card.id, -1) : null,
                ),
                _StepButton(
                  key: Key('choicePlus_${card.id}'),
                  label: '+',
                  onTap: card.enabled && (!isPicked || state.count < card.maxCount)
                      ? () => notifier.step(card.id, 1)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A minus or plus on a counted card: at least 48 x 48 dp, greyed when it cannot move the count.
class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Opacity(
      opacity: onTap == null ? _disabledOpacity : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A greyed button still takes the tap, so it does not fall through to the card under it and clear it.
        onTap: onTap ?? () {},
        child: SizedBox(
          width: _minTouchDp,
          height: _minTouchDp,
          child: Center(
            child: Text(label, style: look.type.title.copyWith(color: look.colors.ink)),
          ),
        ),
      ),
    );
  }
}

/// "Lock in", which reads "Locked" once pressed and takes the lock back when pressed again.
class _LockButton extends ConsumerWidget {
  const _LockButton({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(choicesProvider.notifier);
    return ToyButton(
      key: const Key('choiceLock'),
      label: locked ? PhoneText.choicesLocked : PhoneText.choicesLockIn,
      onPressed: locked ? notifier.undo : notifier.lock,
    );
  }
}
