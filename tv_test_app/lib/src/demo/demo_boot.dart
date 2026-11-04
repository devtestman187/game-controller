import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'demo_flags.dart';
import 'demo_live.dart';
import 'director.dart';
import 'events.dart';

/// Starts the demo director once the TV is listening (docs/demo-video-runbook.md
/// 2.3), and does nothing at all in a normal build.
///
/// The director needs the TV's game port and pairing code, which only exist
/// after the server starts, so this waits for the first host state that has
/// them and then opens the control server on 47900.
class DemoBoot extends ConsumerStatefulWidget {
  const DemoBoot({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DemoBoot> createState() => _DemoBootState();
}

class _DemoBootState extends ConsumerState<DemoBoot> {
  DemoDirector? _director;

  @override
  Widget build(BuildContext context) {
    if (demoDirector && _director == null) {
      final host = ref.watch(hostStateProvider).host;
      final port = host.port;
      if (port != null && host.pairingCode.isNotEmpty) {
        final director = DemoDirector(
          hostPort: port,
          code: host.pairingCode,
          live: DemoLive.instance,
          log: EventLog(take: 'director', dir: const String.fromEnvironment('DEMO_LOG_DIR')),
        );
        _director = director;
        unawaited(
          director.start().catchError((Object e) {
            debugPrint('demo director: could not start: $e');
          }),
        );
      }
    }
    final host = ref.watch(hostStateProvider).host;
    _director?.notePlayers([for (final controller in host.controllers) controller.name]);
    return widget.child;
  }

  @override
  void dispose() {
    unawaited(_director?.stop());
    super.dispose();
  }
}
