import 'dart:async';

import 'package:connection/connection.dart' show ClientStatus;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../host/host_launch.dart';
import '../host/host_start_sheet.dart';
import '../host/hosting.dart';
import '../providers.dart';
import '../ui/connect_screen.dart';
import '../ui/settings_screen.dart';
import 'coach_marks.dart';
import 'home_contract.dart';
import 'home_prefs.dart';
import 'home_text.dart';
import 'home_view.dart';
import 'launch_consent.dart';

/// How long Home searches with no host in sight before it calls the find "none"
/// and leads with Play here, in seconds: long enough for one discovery pass to
/// answer on a home network, short enough that a lone phone is not left waiting.
const homeSearchWait = Duration(seconds: 3);

/// Quits the app, when Back is pressed on a launch's first Home. The platform's
/// exit sits behind this provider so the screen never calls the platform itself,
/// and tests put a fake in its place.
final appExitProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => SystemNavigator.pop(),
);

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

  /// True from the first build until this screen's launch prompts are answered: a
  /// connection that lands then waits for the answer, so closing never takes the
  /// dialog instead, and the coach marks wait too.
  bool _promptUp = true;

  /// A connection landed under the prompts: the close is made up after them.
  bool _closeWaits = false;

  /// True once the three role buttons were laid out with a size after the first
  /// frame. The marks wait for it: a step with no box is skipped, and the skip's
  /// finish would save the tips as seen with nothing shown.
  bool _anchorsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startSearchWait();
      if (_allAnchorsLaidOut()) setState(() => _anchorsReady = true);
      unawaited(askLaunchConsent(context, ref).whenComplete(_afterConsent));
    });
  }

  /// Starts the wait before "No screen found", again on every new search: Search
  /// again and the app's resume both restart discovery, and the chip says
  /// Looking for a screen until the wait ends.
  void _startSearchWait() {
    _searchTimer?.cancel();
    setState(() => _searchWaited = false);
    _searchTimer = Timer(homeSearchWait, () {
      if (mounted) setState(() => _searchWaited = true);
    });
  }

  /// Whether all three role buttons have a size on screen.
  bool _allAnchorsLaidOut() => [_anchors.join, _anchors.play, _anchors.display].every(_isLaidOut);

  /// A button with no box, or one never laid out, counts as not laid out.
  static bool _isLaidOut(GlobalKey anchor) {
    final box = anchor.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize;
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _afterConsent() {
    if (mounted) setState(() => _promptUp = false);
    if (!_closeWaits) return;
    _closeWaits = false;
    if (mounted && (ref.read(clientStateProvider).isConnected || ref.read(demoProvider))) _close();
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
    // A new search (Search again, or the app's resume) starts the wait over.
    // A search that starts with no earlier start time (the first one, or one after a
    // failed start) counts as new too.
    ref.listen(discoveryStateProvider, (previous, next) {
      final after = next.startedAt;
      if (after == null || after == previous?.startedAt || !mounted) return;
      _startSearchWait();
    });
    // "Try without a TV" on the Connect screen above Home shows the pad with the demo link.
    ref.listen(demoProvider, (previous, next) {
      if (!next || previous == true) return;
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
        if (!didPop) unawaited(ref.read(appExitProvider)());
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
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
            if (_marksShow(context)) Positioned.fill(child: _marks()),
          ],
        ),
      ),
    );
  }

  /// Whether the coach marks are on: the buttons are laid out, the saved flag allows
  /// them, and Home is idle.
  bool _marksShow(BuildContext context) =>
      _anchorsReady &&
      ref.watch(showTipsProvider) &&
      phoneHomeMarksIdle(
        isPromptUp: _promptUp,
        clientStatus: ref.watch(clientStateProvider).status,
        isHostingLive: ref.watch(hostingProvider)?.live ?? false,
        isCurrent: ModalRoute.of(context)?.isCurrent ?? false,
      );

  /// The three tips; finishing or skipping them saves that they were seen.
  Widget _marks() {
    void seen() => unawaited(ref.read(showTipsProvider.notifier).set(false));
    return CoachMarks(
      steps: [
        CoachStep(anchor: _anchors.join, text: HomeText.tipJoin),
        CoachStep(anchor: _anchors.play, text: HomeText.tipPlay),
        CoachStep(anchor: _anchors.display, text: HomeText.tipDisplay),
      ],
      onDone: seen,
      onSkip: seen,
    );
  }
}

/// Whether Home is idle, so the coach marks may run: the launch questions are
/// answered ([isPromptUp] false), the client is neither connecting nor connected,
/// this phone hosts no live game, and Home is the route on top ([isCurrent]), not
/// Connect, Settings or a dialog above it.
bool phoneHomeMarksIdle({
  required bool isPromptUp,
  required ClientStatus clientStatus,
  required bool isHostingLive,
  required bool isCurrent,
}) =>
    !isPromptUp &&
    clientStatus != ClientStatus.connecting &&
    clientStatus != ClientStatus.connected &&
    !isHostingLive &&
    isCurrent;
