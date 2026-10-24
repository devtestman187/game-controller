import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'host_controller.dart';

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

final logProvider = Provider<LogBuffer>((ref) {
  final log = LogBuffer();
  if (kDebugMode) {
    final sub = log.changes.listen((_) => debugPrint(log.lines.last.toString()));
    ref.onDispose(sub.cancel);
  }
  ref.onDispose(log.close);
  return log;
});

final hostControllerProvider = Provider<HostController>((ref) {
  final controller = LiveHostController(prefs: ref.watch(prefsProvider), log: ref.watch(logProvider));
  unawaited(controller.start());
  ref.onDispose(controller.dispose);
  return controller;
});

final hostStateProvider = NotifierProvider<HostStateNotifier, HostViewState>(HostStateNotifier.new);

class HostStateNotifier extends Notifier<HostViewState> {
  @override
  HostViewState build() {
    final controller = ref.watch(hostControllerProvider);
    final sub = controller.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return controller.state;
  }
}

/// The newest log lines, updated as they arrive.
final logLinesProvider = NotifierProvider<LogLinesNotifier, List<LogLine>>(LogLinesNotifier.new);

class LogLinesNotifier extends Notifier<List<LogLine>> {
  @override
  List<LogLine> build() {
    final log = ref.watch(logProvider);
    final sub = log.changes.listen((_) => state = log.lines);
    ref.onDispose(sub.cancel);
    return log.lines;
  }
}
