import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;

import '../ui/controller_screen.dart';
import 'host_games.dart';
import 'host_start_sheet.dart';
import 'hosting.dart';
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
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The route goes when the host does: "Stop hosting" and the back press
    // both stop it, and nothing is shown of a stopped host (m12 §3).
    unawaited(
      widget.host.disposed.then((_) {
        if (mounted) Navigator.of(context).pop();
      }),
    );
    // iOS stops the app's sound while the app is hidden, when the phone locks
    // or another app takes it, and the engine doesn't come back by itself:
    // start it again the moment the app is shown (s5c). The route owns this
    // listener rather than the presence, which only exists once the server has
    // started and so could not be listened to from here.
    _lifecycle = AppLifecycleListener(onShow: () => unawaited(ref.read(party.soundPlayerProvider).restart()));
    // The route's first frame ends the start's log (m12 bug 1108b): the time
    // it took to get here is the freeze the player sees after picking a mode.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(party.hostStartLogProvider).step(party.HostStartStep.firstFrame);
      // The adult is asked about sharing this phone's host stats on its first
      // host (B-023). Here and not on the Connect panel: starting the host
      // points this phone's client at its own player, and the panel is rebuilt
      // away before an answer could come (B-023 review finding 1). The route's
      // first frame has no round, so the prompt never interrupts one.
      unawaited(_askConsent());
    });
  }

  /// Asks the adult about sharing host stats once (PRD v2 T19): the Stats
  /// screen's own prompt, so the wording and the saved answer are its. A
  /// prompt closed without an answer still leaves the host running, and the
  /// next host asks again (B-023). It is touch only: the host already accepts
  /// the players' phones, so their A and B must not answer for the adult
  /// whose phone this is (B-023 follow-up).
  Future<void> _askConsent() async {
    if (ref.read(party.statsStateProvider).consent != null) return;
    await party.askConsent(context, ref, touchOnly: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The games' sounds, the phone-joined cue (M13 section 8) and the screen
    // on: the TV's home screen does the same for a host, and the phone has no
    // home screen (m12 §2.7).
    ref.watch(party.gameSoundsProvider);
    ref.watch(party.playerJoinedProvider);
    ref.watch(party.keepAwakeProvider);
    return PopScope(
      // A back press goes up inside the games first (m12 bug 1107e): the
      // picker is their root, and only there does it stop the host, rather
      // than leaving the game behind a server nobody sees (m12 §3).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final games = widget.host.gamesKey.currentState;
        if (games != null && games.canPop()) {
          unawaited(games.maybePop());
        } else {
          unawaited(ref.read(hostingProvider.notifier).stop());
        }
      },
      child: party.ControllerMenus(
        child: ControllerScreen(
          background: HostGames(navigatorKey: widget.host.gamesKey),
          controls: widget.choice == HostChoice.onPhone,
        ),
      ),
    );
  }
}
