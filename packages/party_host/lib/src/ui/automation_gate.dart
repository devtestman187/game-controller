import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../automation/automation_game_start.dart';
import '../automation/automation_providers.dart';
import 'automation_game_screen.dart';
import 'latency_test_card.dart';

/// The app's frame and the automation's overlay (M15 a2): the picture `GET
/// screenshot` takes, and the latency card `POST probe/flash` shows. Put it in
/// the app's `MaterialApp.builder`, so it covers every route.
class AutomationShell extends ConsumerWidget {
  /// [child] is the app's navigator and its screens.
  const AutomationShell({super.key, required this.child});

  /// Everything the app shows.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, not read: the interface listens while the app shows anything,
    // and does nothing at all when the launch didn't switch it on. A launch
    // that answered the stats question answers it before the first screen.
    ref.watch(automationConsentProvider);
    ref.watch(automationServerProvider);
    final probe = ref.watch(automationProbeProvider);
    return ref
        .watch(screenFramesProvider)
        .boundary(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (probe)
                  GestureDetector(
                    onTap: () => ref.read(automationProbeProvider.notifier).show(on: false),
                    child: const LatencyTestCard(),
                  ),
              ],
            ),
          ),
        );
  }
}

/// The host's home under automation (M15 a2): `POST game/start` pushes the
/// round on the app's own navigator, as the menus would, and `POST game/stop`
/// — or the round's own way out — brings the home back. Wrap the app's home
/// in it.
class AutomationGate extends ConsumerStatefulWidget {
  /// [child] is the screen the host starts on.
  const AutomationGate({super.key, required this.child});

  /// The home the automation returns to.
  final Widget child;

  @override
  ConsumerState<AutomationGate> createState() => _AutomationGateState();
}

class _AutomationGateState extends ConsumerState<AutomationGate> {
  /// Whether this gate pushed the round that is up.
  bool _pushed = false;

  @override
  void initState() {
    super.initState();
    // A launch a build starts with (a debug start flag) opens as the app draws.
    if (ref.read(automationLaunchProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(ref.read(automationLaunchProvider));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(automationLaunchProvider, (_, start) => _open(start));
    return widget.child;
  }

  /// Opens [start]'s round, or comes home for null: one route, so a second
  /// start replaces the round that is up rather than stacking on it.
  void _open(AutomationGameStart? start) {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (_pushed) {
      _pushed = false;
      navigator.popUntil((route) => route.isFirst);
    }
    if (start == null) return;
    _pushed = true;
    unawaited(
      navigator.push(MaterialPageRoute<void>(builder: (_) => AutomationGameScreen(start: start))).then((_) {
        if (!mounted) return;
        _pushed = false;
        // The round's own way out (Escape, the remote's Back) clears the
        // launch, so `GET state` says the host is home again.
        ref.read(automationLaunchProvider.notifier).stop();
      }),
    );
  }
}
