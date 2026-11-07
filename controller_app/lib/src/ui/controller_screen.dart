import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../controls_settings.dart';
import '../gyro.dart';
import '../layout.dart';
import '../phone_metrics.dart';
import '../providers.dart';
import 'connect_screen.dart';
import 'controls_layer.dart';
import 'diagnostics_screen.dart';
import 'gyro_dialog.dart';
import 'labels.dart';
import 'rating_prompt.dart';
import 'settings_screen.dart';
import 'status_panel.dart';
import 'stick_dialog.dart';

part 'controller_parts.dart';
part 'controller_top_bar.dart';

/// The controller itself: D-pad (or, in gyro mode, the tilt view) on the
/// left, Start/Select in the middle, face buttons on the right, and a slim bar
/// on top for the connection, mode, settings and Diagnostics.
class ControllerScreen extends ConsumerStatefulWidget {
  const ControllerScreen({super.key});

  @override
  ConsumerState<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends ConsumerState<ControllerScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Back to the last TV if still paired, otherwise straight to choosing one.
      if (!ref.read(connectionActionsProvider).reconnectToLastHost()) openConnect(context);
      // The mode used last (saved), and the battery and CPU readout.
      unawaited(ref.read(gyroProvider.notifier).restoreMode());
      ref.read(sessionMonitorProvider).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A fresh search after returning to the app. This also picks up TVs
      // once the user allows local network access in the iOS prompt.
      ref.read(discoveryProvider).restart();
      // After the phone slept or the app was in the background, the TV has
      // usually dropped the connection: reconnect now, not after the
      // heartbeat times out.
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
    // "How did the controls feel?" after a game, when the TV asks.
    ref.listen(ratingPromptProvider, (prev, next) {
      if (next != null && prev == null) showRatingPrompt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Play haptic events from the TV in every mode (listening keeps it alive
    // without rebuilding the screen on each event).
    ref.listen(tvHapticsProvider, (_, _) {});
    ref.listen(outagesProvider, (_, _) {});
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
    final mode = ref.watch(gyroProvider.select((g) => g.mode));
    // Re-laid out when the button size or fixed/floating changes, so the
    // metrics' touch areas follow.
    ref.watch(stickSettingsProvider);
    // The metrics record while a TV is connected (M9).
    ref.watch(phoneMetricsProvider);
    _followTheGame(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, window) {
            // Too narrow for even the top bar (a phone in split screen, a
            // small window on a tablet): only the message (v2 C32).
            if (window.maxWidth < minWindowWidth) return const TooSmallView();
            return Column(
              children: [
                const _TopBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, body) {
                      if (body.maxHeight < minBodyHeight) return const TooSmallView();
                      return _Controls(mode: mode, body: body.biggest);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
