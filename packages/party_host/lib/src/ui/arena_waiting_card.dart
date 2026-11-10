import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import '../providers.dart';
import '../text/arena_text.dart';
import '../text/host_text.dart';
import 'controller_menus.dart';
import 'host_button.dart';
import 'host_card_button.dart';
import 'host_screen.dart';
import 'player_badge.dart';

part 'arena_waiting_widgets.dart';

/// The Arena's waiting card (M14 b2, design section 8): shown over the Arena
/// when it opens, on a TV and a phone host alike. It shows the pairing code,
/// each joined phone's badge and nickname with a ✓ once they are ready, and
/// "Press A when you're ready"; under them the mode buttons, Robo's level
/// while one player is in the Bumper Round, and the map picker.
///
/// It owns the card alone: the round begins on [onStart] and [Pausable] owns
/// everything from there (design section 8: one owner each). A phone's D-pad
/// and A go to the card, which reads them itself — A readies its player, and
/// the phone shows no menu — and its B leaves the Arena, as the join screen's
/// B does for a player who hasn't joined. The remote works the card's buttons
/// with the arrows and OK, and Escape leaves.
///
/// The round starts when at least one player has joined and every joined
/// player is ready. A simulated controller is ready from the start: nobody can
/// press for it. The host's own player is not: a keyboard draws its marble and
/// a thumb on the host presses A, so it readies like any other.
class ArenaWaitingCard extends ConsumerStatefulWidget {
  const ArenaWaitingCard({super.key, required this.onStart, this.bumperOnly = false, this.surpriseFirst = false});

  /// Every joined player is ready: the round may start.
  final VoidCallback onStart;

  /// Whether the card offers the Bumper Round alone, as a night's does (design
  /// section 8: in a night the mode button is Bumper's only).
  final bool bumperOnly;

  /// Whether the card opens on Surprise me rather than on the map saved last
  /// time: a night's Bumper Round starts on Surprise me, so it plays a map the
  /// night hasn't used yet (design section 7b).
  final bool surpriseFirst;

  @override
  ConsumerState<ArenaWaitingCard> createState() => _ArenaWaitingCardState();
}

/// The two buttons a phone works the card with: A readies its player, B leaves.
enum _Key { a, b }

class _ArenaWaitingCardState extends ConsumerState<ArenaWaitingCard> {
  late final Timer _timer = Timer.periodic(ControllerMenus.step, (_) => _tick());

  /// The focus the card opens on: its chosen mode button, so a TV remote's
  /// arrows start on the card's first button (frame 8 shows it lit). The game
  /// screen's own focus takes the autofocus first, so the card asks for this
  /// one once its first frame is drawn, as the results card does.
  final _modeFocus = FocusNode(debugLabel: 'arena waiting mode');

  /// What each phone held last time. A phone seen for the first time counts as
  /// holding what it holds now: the A that joined the phone to the host was
  /// pressed for the join screen, not for this card, so a player readies with a
  /// press of its own — nobody is started into a round by a finger that was
  /// already down.
  final _before = <String, Set<_Key>>{};

  /// The players who have pressed A since the card opened.
  final _ready = <String>{};

  /// Whether the host has picked a map on this card: a night's card opens on
  /// Surprise me, and its pick wins from there.
  bool _picked = false;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _timer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _modeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _modeFocus.dispose();
    super.dispose();
  }

  static Set<_Key> _keysOf(GamepadState g) => {
    if (g.pressed(GamepadButton.a)) _Key.a,
    if (g.pressed(GamepadButton.b)) _Key.b,
  };

  void _tick() {
    if (!mounted || _started) return;
    final host = ref.read(gameHostProvider);
    final players = [
      for (final p in host.players)
        if (!p.away) p,
    ];
    final ids = {for (final p in players) p.id};
    _before.removeWhere((id, _) => !ids.contains(id));
    _ready.removeWhere((id) => !ids.contains(id));
    var changed = false;
    for (final p in players) {
      if (p.simulated) {
        // Nobody can press for a simulated controller: it is ready at once.
        changed = _ready.add(p.id) || changed;
        continue;
      }
      final now = _keysOf(host.gamepad(p.id));
      final before = _before[p.id];
      _before[p.id] = now;
      if (before == null) continue;
      for (final key in now.difference(before)) {
        // B leaves the Arena, as the join screen's B leaves a player who
        // hasn't joined; nothing more this tick.
        if (key == _Key.b) {
          Navigator.of(context).maybePop();
          return;
        }
        if (!_ready.remove(p.id)) _ready.add(p.id);
        changed = true;
      }
    }
    if (players.isNotEmpty && players.every((p) => _ready.contains(p.id))) {
      _started = true;
      widget.onStart();
    } else if (changed && mounted) {
      setState(() {});
    }
  }

  /// Readies or un-readies [id] from a tap on its row: a phone host's thumb,
  /// or a screen a player touches.
  void _toggle(String id) => setState(() {
    if (!_ready.remove(id)) _ready.add(id);
  });

  ArenaSettings get _settings => ref.watch(arenaSettingsProvider);

  /// The maps the picker offers for the chosen mode (design section 7b: a map
  /// may leave out a mode, and the picker then only offers the other), in the
  /// kit's index's order.
  List<ArenaMap> get _maps {
    final all = ref.watch(arenaMapLibraryProvider).whenOrNull(data: (library) => library.maps) ?? const <ArenaMap>[];
    return [
      for (final map in all)
        if (_plays(map, _mode)) map,
    ];
  }

  /// Whether [map] can be played in [mode].
  static bool _plays(ArenaMap map, ArenaMode mode) => mode == ArenaMode.race ? map.race != null : map.bumper != null;

  /// The mode the card shows chosen: a night plays the Bumper Round alone.
  ArenaMode get _mode => widget.bumperOnly ? ArenaMode.bumper : _settings.mode;

  /// The map that plays, or null for Surprise me: a map saved for the other
  /// mode isn't one this card can start on, and a night's card starts on
  /// Surprise me until the host picks one ([_picked]).
  String? get _chosenId {
    if (widget.surpriseFirst && !_picked) return null;
    final id = _settings.mapId;
    return id == null || !_maps.any((map) => map.id == id) ? null : id;
  }

  /// Whether Robo is in (design section 7a): the Bumper Round with exactly one
  /// player joined.
  bool get _roboIn => _mode == ArenaMode.bumper && _joined.length == 1;

  List<GamePlayer> get _joined => [
    for (final p in ref.watch(gamePlayersProvider))
      if (!p.away) p,
  ];

  void _pickMode(ArenaMode mode) => ref.read(arenaSettingsProvider.notifier).setMode(mode);

  void _pickMap(String? mapId) {
    _picked = true;
    ref.read(arenaSettingsProvider.notifier).setMap(mapId);
  }

  void _pickRoboLevel(RoboLevel level) => ref.read(arenaSettingsProvider.notifier).setRoboLevel(level);

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final players = _joined;
    final maps = _maps;
    final code = ref.watch(hostStateProvider.select((s) => s.host.pairingCode));
    return ListView(
      key: const Key('arenaWaitingCard'),
      padding: hostMenuPadding(ref.watch(hostBarHeightProvider)),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: arenaCardWidthPx),
            child: ToyCard(
              header: HostText.arena,
              headerKey: const Key('arenaWaitingHeader'),
              headerColor: look.colors.player(2),
              padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _modeRow(context, code),
                  const SizedBox(height: ToySizes.space16),
                  Center(child: Text(ArenaText.ready, style: look.type.button)),
                  const SizedBox(height: ToySizes.space8),
                  if (players.isEmpty)
                    Center(
                      child: Text(HostText.noController, style: look.type.body, textAlign: TextAlign.center),
                    ),
                  for (final p in players)
                    _PlayerRow(player: p, ready: _ready.contains(p.id), onTap: () => _toggle(p.id)),
                  if (_roboIn) ...[
                    _RoboRow(level: _settings.roboLevel, onPick: _pickRoboLevel),
                    const SizedBox(height: ToySizes.space8),
                  ],
                  const SizedBox(height: ToySizes.space8),
                  Text(ArenaText.map, style: look.type.button),
                  const SizedBox(height: ToySizes.space8),
                  Wrap(
                    spacing: ToySizes.space12,
                    runSpacing: ToySizes.space12,
                    children: [
                      for (final (i, map) in maps.indexed)
                        _MapCard(
                          map: map,
                          colour: look.colors.player(i % _colourSlots + 1),
                          chosen: _chosenId == map.id,
                          onPressed: () => _pickMap(map.id),
                        ),
                      _SurpriseCard(chosen: _chosenId == null, onPressed: () => _pickMap(null)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The mode buttons and the pairing code (frame 8): the chosen mode keeps
  /// the focus fill, so it reads as chosen while the focus is elsewhere; a
  /// night's card has the Bumper Round alone (design section 8).
  Widget _modeRow(BuildContext context, String code) {
    final mode = _mode;
    return Row(
      children: [
        _ModeButton(
          key: const Key('arenaMode-bumper'),
          label: ArenaText.bumper,
          chosen: mode == ArenaMode.bumper,
          focusNode: mode == ArenaMode.bumper ? _modeFocus : null,
          onPressed: () => _pickMode(ArenaMode.bumper),
        ),
        if (!widget.bumperOnly) ...[
          const SizedBox(width: ToySizes.space12),
          _ModeButton(
            key: const Key('arenaMode-race'),
            label: ArenaText.race,
            chosen: mode == ArenaMode.race,
            focusNode: mode == ArenaMode.race ? _modeFocus : null,
            onPressed: () => _pickMode(ArenaMode.race),
          ),
        ],
        const Spacer(),
        _CodeChip(code: code),
      ],
    );
  }
}
