import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'host_screen.dart';
import 'host_start_sheet.dart';
import 'hosting.dart';

/// Starts this phone's host with the choice the sheet returned, then opens the host screen on it.
///
/// The caller checks that [context] is still mounted after the sheet; this reads [ref] only after that check.
Future<void> launchHosting(BuildContext context, WidgetRef ref, HostChoice choice) async {
  final hosting = ref.read(hostingProvider.notifier);
  // Phones that join see it only when this phone plays it itself:
  // the host is told which before it starts (m12 bug 1108a rule D).
  final host = hosting.start(playsHere: choice == HostChoice.onPhone);
  // The route opens at once, and asks its own consent prompt on its
  // first frame (B-023, host_screen.dart). Nothing here may wait on
  // an answer: the start points this phone's client at its own
  // player, and the panel is rebuilt away under the prompt.
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => HostScreen(host: host, choice: choice),
    ),
  );
}
