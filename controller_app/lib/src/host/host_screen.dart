import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;

import '../providers.dart';
import '../ui/controller_screen.dart';
import 'host_games.dart';
import 'host_start_sheet.dart';
import 'phone_host.dart';

/// The route of a hosting phone (m12 §2.7): the game behind this phone's own
/// controls, which work it like a remote.
class HostScreen extends ConsumerStatefulWidget {
  const HostScreen({super.key, required this.host, required this.choice});

  final PhoneHost host;

  /// What "Host a game" asked for: the game alone, or the controls too (C34).
  final HostChoice choice;

  @override
  ConsumerState<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends ConsumerState<HostScreen> {
  late final GameShownNotifier _gameShown;
  late final Widget _body;

  @override
  void initState() {
    super.initState();
    // Read here, not in a field initializer: dispose() needs it, and there is
    // no `ref` any more then (project notes).
    _gameShown = ref.read(gameShownProvider.notifier);
    // One scope, built once: the own player's client replaces the app's, and
    // everything else is inherited from the root scope.
    _body = ProviderScope(
      overrides: [clientProvider.overrideWithValue(widget.host.client)],
      child: party.ControllerMenus(
        child: ControllerScreen(
          background: HostGames(navigatorKey: widget.host.gamesKey),
          controls: widget.choice == HostChoice.onPhone,
        ),
      ),
    );
    // Over a game the controls take the saved opacity and the bar shows the
    // ping instead of the status panel (m12 §2.7).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _gameShown.set(true);
    });
  }

  @override
  void dispose() {
    _gameShown.set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The games' sounds and the screen on: the TV's home screen does the same
    // for a host, and the phone has no home screen (m12 §2.7).
    ref.watch(party.gameSoundsProvider);
    ref.watch(party.keepAwakeProvider);
    return _body;
  }
}
