import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show PhoneText, ToyCard, ToyLook, ToyLookScope, ToySizes;
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
        content: Text(PhoneText.thanks, textAlign: TextAlign.center),
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

  /// The three faces, in the order they are shown: the face, its icon and the
  /// word under it. The fill comes from [faceColor], so Sunny and Night each
  /// get their own.
  static const faces = [
    (face: RatingFace.good, icon: Icons.sentiment_satisfied_alt_rounded, label: PhoneText.good),
    (face: RatingFace.okay, icon: Icons.sentiment_neutral_rounded, label: PhoneText.okay),
    (face: RatingFace.bad, icon: Icons.sentiment_dissatisfied_rounded, label: PhoneText.bad),
  ];

  /// A face's fill: the look's good, caution and bad, so the ink edge and the
  /// ink label stay legible (M13 3c).
  static Color faceColor(ToyLook look, RatingFace face) => switch (face) {
    RatingFace.good => look.colors.good,
    RatingFace.okay => look.colors.caution,
    RatingFace.bad => look.colors.bad,
  };

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

  /// The room between the card and the screen's edge, so the card keeps its
  /// shadow on the smallest phone held in landscape.
  static const _inset = EdgeInsets.symmetric(horizontal: ToySizes.space32, vertical: ToySizes.space12);

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final followUp = _face != null;
    return Dialog(
      key: const Key('ratingPrompt'),
      // Compact, so it fits the smallest phone held in landscape. The paper,
      // the band and the ink edge are the card's and the theme's.
      insetPadding: _inset,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 520),
        child: ToyCard(
          header: followUp ? PhoneText.whatGotInTheWay : PhoneText.howDidItFeel,
          headerColor: look.colors.focus,
          padding: const EdgeInsets.fromLTRB(ToySizes.space16, ToySizes.space12, ToySizes.space16, ToySizes.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _faces(look, followUp),
              if (followUp) ...[
                const SizedBox(height: ToySizes.space12),
                Text(
                  PhoneText.pickAnyThatFit,
                  textAlign: TextAlign.center,
                  style: look.type.body.copyWith(color: look.colors.inkSoft),
                ),
                const SizedBox(height: ToySizes.space8),
                _tagGrid(),
              ],
              const SizedBox(height: ToySizes.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    key: const Key('rate-skip'),
                    onPressed: () => _send(null),
                    child: const Text(PhoneText.skip),
                  ),
                  if (followUp)
                    FilledButton(
                      key: const Key('rate-send'),
                      onPressed: () => _send(_face),
                      child: const Text(PhoneText.send),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Three faces of exactly the same size, evenly spaced; once one is picked,
  /// the others fade back.
  Widget _faces(ToyLook look, bool picked) => Row(
    children: [
      for (final (i, f) in RatingPrompt.faces.indexed) ...[
        if (i > 0) const SizedBox(width: ToySizes.space12),
        Expanded(
          child: _FaceCard(
            key: Key('rate-${f.face.name}'),
            icon: f.icon,
            label: f.label,
            color: RatingPrompt.faceColor(look, f.face),
            selected: _face == f.face,
            dimmed: picked && _face != f.face,
            onTap: () => _pick(f.face),
          ),
        ),
      ],
    ],
  );

  /// The tags as a 2 by 2 grid of equal buttons, each toggled on its own.
  Widget _tagGrid() => Column(
    children: [
      for (final row in [RatingTag.all.take(2), RatingTag.all.skip(2)]) ...[
        Row(
          children: [
            for (final (i, tag) in row.indexed) ...[
              if (i > 0) const SizedBox(width: ToySizes.space8),
              Expanded(
                child: _TagButton(
                  key: Key('tag-$tag'),
                  label: PhoneText.ratingTag(tag),
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
        const SizedBox(height: ToySizes.space8),
      ],
    ],
  );
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

  /// The face's height: four of the look's space24, the 96 px the prompt has
  /// always given it.
  static const _heightShare = 4.0;

  /// The face icon against the look's title size: the 44 px it has always had.
  static const _iconShare = 1.375;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dimmed ? 0.45 : 1,
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ToySizes.cardCorner),
            side: BorderSide(color: look.colors.ink, width: look.sizes.outlineWidth * (selected ? 2 : 1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: ToySizes.space24 * _heightShare,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: look.type.title.fontSize! * _iconShare, color: look.colors.ink),
                  const SizedBox(height: ToySizes.space4),
                  Text(label, style: look.type.button.copyWith(color: look.colors.ink)),
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

  /// A tag's height against the look's button: the 40 px it has always had.
  static const _heightShare = 5 / 6;

  /// The check against the look's body size: 18 px of it.
  static const _checkShare = 1.2;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        // Paper when off, the focus yellow when on: the look's own toggle.
        color: selected ? look.colors.focus : look.colors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ToySizes.space8),
          side: BorderSide(color: look.colors.ink, width: look.sizes.outlineWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: look.sizes.buttonHeight * _heightShare,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: look.type.body.fontSize! * _checkShare, color: look.colors.ink),
                  const SizedBox(width: ToySizes.space4),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: look.type.body.copyWith(color: look.colors.ink),
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
