import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';

/// Shows "How did the controls feel?" (PRD v2 C19) over the controller.
///
/// Designed like the quick ratings in call and chat apps: three labelled
/// faces of equal size. Good is one tap. Okay or Bad then asks "What got in
/// the way?" with optional tags and Send, because people say more right
/// after a poor rating. Skip, tapping outside, or waiting
/// [RatingPrompt.timeout] closes it (with the face, if one was picked).
Future<void> showRatingPrompt(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  // Fingers on the controls lose their buttons under the dialog.
  container.read(padProvider.notifier).releaseAll();
  final rated = await showDialog<bool>(context: context, builder: (_) => const RatingPrompt());
  // Closed without an answer (outside tap, back): skipped.
  if (container.read(ratingPromptProvider) != null) container.read(ratingPromptProvider.notifier).answer(null);
  if (rated == true) {
    messenger?.showSnackBar(
      // Small and in the middle, so it never covers a button as the next
      // round starts.
      const SnackBar(
        content: Text('Thanks! That helps make the controls better.', textAlign: TextAlign.center),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 380,
      ),
    );
  }
}

class RatingPrompt extends ConsumerStatefulWidget {
  const RatingPrompt({super.key});

  /// No tap for this long: closed (skipped, or sent if a face is picked).
  static const timeout = Duration(seconds: 20);

  static const tagLabels = {
    RatingTag.buttonsTooSmall: 'Buttons too small',
    RatingTag.laggy: 'Laggy',
    RatingTag.hardToSteer: 'Hard to steer',
    RatingTag.rotationHard: 'Rotation hard',
  };

  static const faces = [
    (face: RatingFace.good, icon: Icons.sentiment_satisfied_alt_rounded, label: 'Good', color: Color(0xFF4ADE80)),
    (face: RatingFace.okay, icon: Icons.sentiment_neutral_rounded, label: 'Okay', color: Color(0xFFFACC15)),
    (face: RatingFace.bad, icon: Icons.sentiment_dissatisfied_rounded, label: 'Bad', color: Color(0xFFF87171)),
  ];

  @override
  ConsumerState<RatingPrompt> createState() => _RatingPromptState();
}

class _RatingPromptState extends ConsumerState<RatingPrompt> {
  final _tags = <String>{};
  RatingFace? _face;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  /// The time limit starts again with every tap, so choosing tags never
  /// runs out of time.
  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(RatingPrompt.timeout, () => _send(_face));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _send(RatingFace? face) {
    if (!mounted) return;
    ref.read(ratingPromptProvider.notifier).answer(face, tags: face == null ? const [] : _tags.toList());
    Navigator.of(context).pop(face != null);
  }

  void _pick(RatingFace face) {
    // Good needs nothing more: one tap.
    if (face == RatingFace.good) return _send(face);
    _restartTimer();
    setState(() => _face = face);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final followUp = _face != null;
    return AlertDialog(
      key: const Key('ratingPrompt'),
      scrollable: true,
      // Compact, so it fits the smallest phone held in landscape.
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      titlePadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      actionsPadding: const EdgeInsets.fromLTRB(24, 4, 16, 10),
      title: Text(
        followUp ? 'What got in the way?' : 'How did the controls feel?',
        textAlign: TextAlign.center,
        style: text.titleLarge,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Three faces of exactly the same size, evenly spaced.
            Row(
              children: [
                for (final (i, f) in RatingPrompt.faces.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _FaceCard(
                      key: Key('rate-${f.face.name}'),
                      icon: f.icon,
                      label: f.label,
                      color: f.color,
                      selected: _face == f.face,
                      dimmed: followUp && _face != f.face,
                      onTap: () => _pick(f.face),
                    ),
                  ),
                ],
              ],
            ),
            if (followUp) ...[
              const SizedBox(height: 14),
              Text(
                'Pick any that fit (optional)',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              // A 2 by 2 grid of equal buttons.
              for (final row in [RatingPrompt.tagLabels.entries.take(2), RatingPrompt.tagLabels.entries.skip(2)]) ...[
                Row(
                  children: [
                    for (final (i, MapEntry(key: tag, value: label)) in row.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _TagButton(
                          key: Key('tag-$tag'),
                          label: label,
                          selected: _tags.contains(tag),
                          onTap: () {
                            _restartTimer();
                            setState(() => _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag));
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(key: const Key('rate-skip'), onPressed: () => _send(null), child: const Text('Skip')),
        if (followUp)
          FilledButton(key: const Key('rate-send'), onPressed: () => _send(_face), child: const Text('Send')),
      ],
    );
  }
}

/// One face: a tinted card with the face and its label, the same size as
/// the others. Picked: a bright border; the others fade back.
class _FaceCard extends StatelessWidget {
  const _FaceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dimmed ? 0.45 : 1,
        child: Material(
          color: color.withValues(alpha: selected ? 0.22 : 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? color : color.withValues(alpha: 0.35), width: selected ? 2.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 96,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 44, color: color),
                  const SizedBox(height: 4),
                  Text(label, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tag the player can turn on or off; all four are the same size.
class _TagButton extends StatelessWidget {
  const _TagButton({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? scheme.secondary : scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 18, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: selected ? scheme.onSecondaryContainer : scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
