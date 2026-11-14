part of 'puzzle_screen.dart';

/// A run of rounds the host started from one hand-picked puzzle (B-011): the
/// level it plays, the ids it has played since that pick, and whether Shuffle
/// is on. It lives only as long as the rounds it leads to — Back, Change teams
/// or a new pick on the picker starts another one — and nothing is saved.
///
/// It is a value: a round hands back the series that follows it, and the next
/// screen plays from that one.
@immutable
final class PuzzleSeries {
  const PuzzleSeries._({required this.level, required this.played, required this.isShuffled});

  /// A series on [level] that has played nothing yet, with Shuffle off.
  factory PuzzleSeries.start(Level level) => PuzzleSeries._(level: level, played: const {}, isShuffled: false);

  /// The level this series plays.
  final Level level;

  /// The ids of [level] this series has played, so Next never comes back to
  /// one of them. In memory only: it ends with the series.
  final Set<String> played;

  /// Whether Next draws a random unplayed puzzle of the level instead of the
  /// next one in the library's order. The switch that sets it is on the
  /// results, and it stays with the series.
  final bool isShuffled;

  /// The same series on [level], with nothing played and the same Shuffle: the
  /// prompt's Continue starts the next level as a series of its own.
  PuzzleSeries atLevel(Level level) => PuzzleSeries._(level: level, played: const {}, isShuffled: isShuffled);

  /// The same series with [id] played.
  PuzzleSeries withPlayed(String id) => played.contains(id)
      ? this
      : PuzzleSeries._(level: level, played: Set.unmodifiable({...played, id}), isShuffled: isShuffled);

  /// The same series with Shuffle [isShuffled].
  PuzzleSeries withShuffled(bool isShuffled) =>
      isShuffled == this.isShuffled ? this : PuzzleSeries._(level: level, played: played, isShuffled: isShuffled);

  /// The id of [level] to play next, among the [ids] this build ships in the
  /// library's order and after [current] (B-011, design item 2): the first
  /// unplayed id after it, wrapping past the end, or a random unplayed one
  /// while [isShuffled]. Null once every id of the level has played.
  String? nextId({required List<String> ids, String? current, required Random random}) {
    final left = [
      for (final id in ids)
        if (!played.contains(id)) id,
    ];
    if (left.isEmpty) return null;
    if (isShuffled) return left[random.nextInt(left.length)];
    // A current id the library no longer ships starts the walk at the front.
    final from = current == null ? 0 : ids.indexOf(current) + 1;
    final order = [for (var i = 0; i < ids.length; i++) ids[(from + i) % ids.length]];
    return order.firstWhere((id) => !played.contains(id), orElse: () => left.first);
  }

  /// The level after [level] that has puzzles, by the [Level] order (B-011,
  /// design item 3): null on the last one. Hard has no puzzles yet, so a Medium
  /// series ends at its prompt.
  static Level? levelAfter(PuzzleLibrary library, Level level) {
    for (final next in Level.values.skip(level.index + 1)) {
      if (library.ofLevel(next).isNotEmpty) return next;
    }
    return null;
  }
}

/// A series round's Shuffle switch (B-011, design item 2): whether it is on,
/// and what a press on it does.
typedef _Shuffle = ({bool isOn, ValueChanged<bool> onChanged});

/// What a series round's results offer beside their buttons (B-011): the
/// Shuffle switch, absent once no round can follow, and the prompt that every
/// puzzle of the level has played, absent while some are left.
typedef _SeriesOptions = ({_Shuffle? shuffle, String? prompt});

/// A results button that takes no focus of its own: the series' Play again,
/// which sits beside Next puzzle and is reached with the remote's right.
typedef _MenuButton = ({String label, IconData icon, String key, VoidCallback onPressed});

/// A round's results buttons (B-011): [again] is the first one and holds the
/// focus, [replay] plays the same puzzle again (a series round only, since an
/// `any <level>` round's first button is its own replay), and [series] is set
/// when the round was one of a series.
typedef _ResultMenu = ({_AgainButton again, _MenuButton? replay, _SeriesOptions? series});

/// A series round's results buttons (B-011, design item 2): Next puzzle — or,
/// once every puzzle of the level has played, the prompt and its Continue —
/// then the Shuffle switch, Play again, Change teams and Back. They go in a
/// [Wrap], so a phone host's narrow card takes them as more than one row rather
/// than overflowing.
class _SeriesButtons extends StatelessWidget {
  const _SeriesButtons({required this.again, required this.replay, required this.options, required this.onChangeTeams});

  /// The first button: Next puzzle, the prompt's Continue, or Play again on the
  /// last level.
  final _AgainButton again;

  /// Play again beside the first button, or null when nothing is left to play.
  final _MenuButton? replay;

  final _SeriesOptions options;
  final VoidCallback onChangeTeams;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final prompt = options.prompt;
    final shuffle = options.shuffle;
    final replayButton = replay;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prompt != null) ...[
          Text(
            prompt,
            key: const Key('seriesPrompt'),
            textAlign: TextAlign.center,
            style: look.type.button.copyWith(color: look.colors.ink),
          ),
          const SizedBox(height: ToySizes.space12),
        ],
        // Five buttons are more than one row of a host's card holds, so the pad
        // walks them by where they land: right along the first row, then down
        // to Back and left to Change teams (B-011).
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: ToySizes.space12,
          runSpacing: ToySizes.space12,
          children: [
            HostButton(
              key: Key(again.key),
              label: again.label,
              icon: again.icon,
              focusNode: again.focusNode,
              onPressed: again.onPressed,
            ),
            if (shuffle != null) _ShuffleSwitch(shuffle: shuffle),
            if (replayButton != null)
              HostButton(
                key: Key(replayButton.key),
                label: replayButton.label,
                icon: replayButton.icon,
                onPressed: replayButton.onPressed,
              ),
            HostButton(
              key: const Key('changeTeams'),
              label: HostText.changeTeams,
              icon: Icons.group,
              onPressed: onChangeTeams,
            ),
            HostButton(
              key: const Key('resultsBack'),
              label: HostText.back,
              icon: Icons.arrow_back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }
}

/// The series' Shuffle switch (B-011): the label with a switch's own icon,
/// filled with the focus yellow while it is on, so a thumb and the remote's A
/// both see the state and change it.
class _ShuffleSwitch extends StatelessWidget {
  const _ShuffleSwitch({required this.shuffle});

  final _Shuffle shuffle;

  @override
  Widget build(BuildContext context) => HostButton(
    key: const Key('shuffle'),
    label: HostText.shuffle,
    icon: shuffle.isOn ? Icons.toggle_on : Icons.toggle_off,
    fill: shuffle.isOn ? ToyLookScope.of(context).colors.focus : null,
    onPressed: () => shuffle.onChanged(!shuffle.isOn),
  );
}
