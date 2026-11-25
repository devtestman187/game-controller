import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../host/host_launch.dart';
import '../host/host_start_sheet.dart';
import '../host/hosting.dart';
import '../providers.dart';
import '../ui/connect_screen.dart';
import '../ui/settings_screen.dart';
import 'home_contract.dart';
import 'home_view.dart';
import 'launch_consent.dart';

/// How long Home searches with no host in sight before it calls the find "none"
/// and leads with Play here, in seconds: long enough for one discovery pass to
/// answer on a home network, short enough that a lone phone is not left waiting.
const homeSearchWait = Duration(seconds: 3);

/// The Home hub wired to the app (APP-START.md, item 8 of JOBS.md): the roles
/// open the Connect screen or start this phone's host, Settings and the name row
/// open Settings, and the launch's consent questions are put on its first frame.
///
/// [fromLaunch] says an unpaired launch pushed this Home: Back then exits the
/// app. Opened from the pad's menu, Back returns to the pad. When the client
/// connects, Home removes itself, unless this phone hosts a live game.
class PhoneHomeScreen extends ConsumerStatefulWidget {
  const PhoneHomeScreen({super.key, required this.fromLaunch});

  /// True when this Home is a launch's first screen.
  final bool fromLaunch;

  @override
  ConsumerState<PhoneHomeScreen> createState() => _PhoneHomeScreenState();
}

class _PhoneHomeScreenState extends ConsumerState<PhoneHomeScreen> {
  final _anchors = HomeAnchors();
  Timer? _searchTimer;

  /// True once [homeSearchWait] passed since the first frame.
  bool _searchWaited = false;

  /// True while this screen's launch prompts are up: a connection that lands
  /// then waits for the answer, so closing never takes the dialog instead.
  bool _promptUp = false;

  /// A connection landed under the prompts: the close is made up after them.
  bool _closeWaits = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchTimer = Timer(homeSearchWait, () {
        if (mounted) setState(() => _searchWaited = true);
      });
      _promptUp = true;
      unawaited(askLaunchConsent(context, ref).whenComplete(_afterConsent));
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _afterConsent() {
    _promptUp = false;
    if (!_closeWaits) return;
    _closeWaits = false;
    if (mounted && ref.read(clientStateProvider).isConnected) _close();
  }

  /// Removes this route itself, not whichever route is on top: the Connect
  /// screen above it closes on the same connection.
  void _close() {
    if (ref.read(hostingProvider)?.live ?? false) return;
    final route = ModalRoute.of(context);
    if (route != null) Navigator.of(context).removeRoute(route);
  }

  HomeFind _find() {
    final discovery = ref.watch(discoveryStateProvider);
    if (discovery.hosts.isNotEmpty) return HomeFind.found;
    if (discovery.error != null || _searchWaited) return HomeFind.none;
    return HomeFind.searching;
  }

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  void _host(HostChoice choice) {
    if (!mounted) return;
    unawaited(launchHosting(context, ref, choice));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clientStateProvider, (previous, next) {
      if (!next.isConnected || (previous?.isConnected ?? false)) return;
      if (_promptUp) {
        _closeWaits = true;
        return;
      }
      _close();
    });
    final profile = ref.watch(profileProvider);
    return PopScope(
      canPop: !widget.fromLaunch,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(SystemNavigator.pop());
      },
      child: Scaffold(
        body: SafeArea(
          child: HomeView(
            find: _find(),
            nickname: profile.nickname,
            character: profile.character,
            anchors: _anchors,
            onJoin: () => openConnect(context),
            onPlay: () => _host(HostChoice.onPhone),
            onDisplay: () => _host(HostChoice.onDevice),
            onSettings: _openSettings,
            onEditName: _openSettings,
            onSearchAgain: () => unawaited(ref.read(discoveryProvider).restart()),
          ),
        ),
      ),
    );
  }
}
