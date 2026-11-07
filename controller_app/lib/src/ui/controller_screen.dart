import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controls_settings.dart';
import '../gyro.dart';
import '../host/hosting.dart';
import '../layout.dart';
import '../phone_metrics.dart';
import '../providers.dart';
import 'abandoned_notice.dart';
import 'bar_connection.dart';
import 'bar_modes.dart';
import 'connect_screen.dart';
import 'controls_layer.dart';
import 'diagnostics_screen.dart';
import 'host_chip.dart';
import 'joined_view.dart';
import 'rating_prompt.dart';
import 'settings_screen.dart';
import 'waiting_card.dart';

part 'controller_parts.dart';
part 'controller_top_bar.dart';

/// The controller itself: D-pad (or, in gyro mode, the tilt view) on the
/// left, Start/Select in the middle, face buttons on the right, and a slim bar
/// on top for the connection, mode, settings and Diagnostics.
///
/// With a [background] it is the game behind the controls instead (m12 §2.7):
/// the app is hosting, and the same pad plays that game. Without one the
/// background is the game a host shows this phone ([JoinedView]).
class ControllerScreen extends ConsumerStatefulWidget {
  const ControllerScreen({super.key, this.background, this.controls = true});

  /// Drawn behind the controls: the game, when this phone is hosting.
  final Widget? background;

  /// False for "Show on this device" (C34): the game alone, no pad.
  final bool controls;

  @override
  ConsumerState<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends ConsumerState<ControllerScreen> with WidgetsBindingObserver {
  /// A background means this app is hosting (m12 §2.7).
  bool get _hosting => widget.background != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final hosting = _hosting;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Back to the last TV if still paired, otherwise straight to choosing
      // one. A hosting phone has no TV to find: its own player is already
      // connecting.
      if (!hosting && !ref.read(connectionActionsProvider).reconnectToLastHost()) openConnect(context);
      // The mode used last (saved).
      unawaited(ref.read(gyroProvider.notifier).restoreMode());
      // The battery and CPU readout is the controller's; a host has its own.
      if (!hosting) ref.read(sessionMonitorProvider).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Both screens hear this: the host route's and the controller's still
    // below it, which must not search for a TV either (m12 §2.7).
    final hosting = _hosting || (ref.read(hostingProvider)?.live ?? false);
    if (state == AppLifecycleState.resumed) {
      // A fresh search after returning to the app. This also picks up TVs
      // once the user allows local network access in the iOS prompt.
      if (!hosting) ref.read(discoveryProvider).restart();
      // After the phone slept or the app was in the background, the TV has
      // usually dropped the connection: reconnect now, not after the
      // heartbeat times out. In host mode this resumes the own player.
      ref.read(clientProvider).resume();
      ref.read(gyroProvider.notifier).resume();
      ref.read(hapticsPlayerProvider).paused = false;
    } else {
      // Leaving the app (or a system sheet on top) must not leave input held.
      ref.read(gyroProvider.notifier).pause();
      ref.read(hapticsPlayerProvider).paused = true;
      ref.read(padProvider.notifier).releaseAll();
    }
  }

  /// The TV's side while this phone is not hosting (m12 §5): a fresh search
  /// after a long reconnect, the TV's new address, and its rating prompt.
  void _followTheTv(BuildContext context) {
    // While reconnecting for a while, look for the TV again now and then: it
    // may have restarted on another port, or the network may have changed.
    ref.listen(clientStateProvider, (_, next) {
      if (next.status == ClientStatus.reconnecting && next.attempt > 0 && next.attempt % 4 == 0) {
        ref.read(discoveryProvider).restart();
      }
    });
    // If the TV shows up at a new address (new DHCP lease), reconnect there.
    ref.listen(discoveryStateProvider, (_, next) {
      final client = ref.read(clientProvider);
      for (final host in next.hosts) {
        client.updateAddress(host.address);
      }
    });
    // "How did the controls feel?" after a game, when the TV asks. Not while
    // hosting: it would be a dialog over this phone's own game (m12 §2.7),
    // and the own player's prompt reaches this screen below the host route
    // through the same client (s5c).
    ref.listen(ratingPromptProvider, (prev, next) {
      final hosting = _hosting || (ref.read(hostingProvider)?.live ?? false);
      if (next != null && prev == null && !hosting) showRatingPrompt(context);
    });
  }

  /// The game's side of the screen (P5): the controls it allows and hides,
  /// the mode to go back to after it, and its rating ask.
  void _followTheGame(BuildContext context) {
    // The game's controls (P5): its allowed modes, and nothing left held on
    // a button it hides. After the game, back to the player's own mode.
    ref.listen(gameLayoutProvider, (prev, next) {
      final gyro = ref.read(gyroProvider.notifier);
      if (next.modes.isEmpty && (prev?.modes.isNotEmpty ?? false)) {
        unawaited(gyro.backToSavedMode());
      } else {
        unawaited(gyro.applyGameModes(next));
      }
      if (ref.read(padProvider).buttons.any(next.hidden.contains)) ref.read(padProvider.notifier).releaseAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Host mode: the app's host, for this screen and the one still below the
    // host route (m12 §2.7).
    final hosting = _hosting || (ref.watch(hostingProvider)?.live ?? false);
    // Play haptic events from the TV in every mode (listening keeps it alive
    // without rebuilding the screen on each event).
    ref.listen(tvHapticsProvider, (_, _) {});
    ref.listen(outagesProvider, (_, _) {});
    // A host has nothing to find, so no search and nothing to rate.
    if (!hosting) _followTheTv(context);
    final mode = ref.watch(gyroProvider.select((g) => g.mode));
    // Re-laid out when the button size or fixed/floating changes, so the
    // metrics' touch areas follow.
    ref.watch(stickSettingsProvider);
    // The metrics record while a TV is connected (M9), and over a game only
    // when this phone's pad plays it (C34).
    if (widget.controls) ref.watch(phoneMetricsProvider);
    _followTheGame(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, window) {
            // Too narrow for even the top bar (a phone in split screen, a
            // small window on a tablet): only the message (v2 C32).
            if (window.maxWidth < minWindowWidth) return const TooSmallView();
            return Stack(
              children: [
                // The game fills the whole safe area, behind the top bar (m12
                // §5, phone layout §0.7): the bar paints no background of its
                // own, so the game shows through it.
                Positioned.fill(child: widget.background ?? const JoinedView()),
                Positioned.fill(
                  child: Column(
                    children: [
                      _TopBar(hosting: _hosting, controls: widget.controls),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, body) {
                            if (body.maxHeight < minBodyHeight) return const TooSmallView();
                            return _Controls(mode: mode, body: body.biggest, controls: widget.controls);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // The host was away too long (m12 §0.5): said over the
                // controls for a moment, which stay usable under it.
                const Positioned.fill(child: AbandonedNotice()),
                // The host is away or the link dropped (m12-joined-view §0.3):
                // the card sits over the game and the controls.
                const Positioned.fill(child: _WaitingOverlay()),
              ],
            );
          },
        ),
      ),
    );
  }
}
