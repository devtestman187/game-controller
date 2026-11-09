part of 'lobby_music.dart';

/// Holds a lobby open while it is mounted (M13 design section 8): the game
/// picker's body. Anything pushed over the picker still counts, so the music
/// carries on unbroken to the join screen.
class LobbyHold extends ConsumerStatefulWidget {
  const LobbyHold({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LobbyHold> createState() => _LobbyHoldState();
}

class _LobbyHoldState extends ConsumerState<LobbyHold> {
  late final LobbyMusic _music;

  @override
  void initState() {
    super.initState();
    _music = ref.read(lobbyMusicProvider)..openLobby();
  }

  @override
  void dispose() {
    _music.closeLobby();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Holds a round open while it is mounted (M13 design section 8):
/// `PuzzleScreen` and `GameScreen`, their results and pause included. The music
/// stops while a round is on and comes back when it closes, and the palette
/// stands still with it ([RoundPaletteHold], design D1).
class RoundHold extends ConsumerStatefulWidget {
  const RoundHold({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RoundHold> createState() => _RoundHoldState();
}

class _RoundHoldState extends ConsumerState<RoundHold> {
  late final LobbyMusic _music;

  @override
  void initState() {
    super.initState();
    _music = ref.read(lobbyMusicProvider)..openRound();
  }

  @override
  void dispose() {
    _music.closeRound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RoundPaletteHold(child: widget.child);
}
