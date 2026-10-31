import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';

/// Shows "How did the controls feel?" (PRD v2 C19) over the controller. One
/// tap on a face answers; tags are optional. Tapping outside, Skip, or
/// waiting [RatingPrompt.timeout] skips it.
Future<void> showRatingPrompt(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  // Fingers on the controls lose their buttons under the dialog.
  container.read(padProvider.notifier).releaseAll();
  await showDialog<void>(context: context, builder: (_) => const RatingPrompt());
  // Closed without an answer (outside tap, back): skipped.
  if (container.read(ratingPromptProvider) != null) container.read(ratingPromptProvider.notifier).answer(null);
}

class RatingPrompt extends ConsumerStatefulWidget {
  const RatingPrompt({super.key});

  /// Unanswered for this long: skipped.
  static const timeout = Duration(seconds: 20);

  static const tagLabels = {
    RatingTag.buttonsTooSmall: 'Buttons too small',
    RatingTag.laggy: 'Laggy',
    RatingTag.hardToSteer: 'Hard to steer',
    RatingTag.rotationHard: 'Rotation hard',
  };

  @override
  ConsumerState<RatingPrompt> createState() => _RatingPromptState();
}

class _RatingPromptState extends ConsumerState<RatingPrompt> {
  final _tags = <String>{};
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(RatingPrompt.timeout, () => _answer(null));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _answer(RatingFace? face) {
    if (!mounted) return;
    ref.read(ratingPromptProvider.notifier).answer(face, tags: face == null ? const [] : _tags.toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      key: const Key('ratingPrompt'),
      title: const Text('How did the controls feel?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Face(
                  key: const Key('rate-good'),
                  icon: Icons.sentiment_very_satisfied,
                  label: 'Good',
                  color: Colors.greenAccent,
                  onTap: () => _answer(RatingFace.good),
                ),
                _Face(
                  key: const Key('rate-okay'),
                  icon: Icons.sentiment_neutral,
                  label: 'Okay',
                  color: Colors.amberAccent,
                  onTap: () => _answer(RatingFace.okay),
                ),
                _Face(
                  key: const Key('rate-bad'),
                  icon: Icons.sentiment_very_dissatisfied,
                  label: 'Bad',
                  color: Colors.redAccent,
                  onTap: () => _answer(RatingFace.bad),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Anything in particular? (optional, pick before a face)', style: text.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final MapEntry(key: tag, value: label) in RatingPrompt.tagLabels.entries)
                  FilterChip(
                    key: Key('tag-$tag'),
                    label: Text(label),
                    selected: _tags.contains(tag),
                    onSelected: (on) => setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [TextButton(key: const Key('rate-skip'), onPressed: () => _answer(null), child: const Text('Skip'))],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: color),
          Text(label),
        ],
      ),
    ),
  );
}
