import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';

import '../latency_screen.dart';
import 'panel.dart';

/// The newest log lines, with a button that saves them all to a file.
class LogPanel extends ConsumerWidget {
  const LogPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(logLinesProvider);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.3);
    return Panel(
      title: 'Log',
      trailing: HostButton(
        label: 'Save log',
        icon: Icons.save_alt,
        compact: true,
        onPressed: () => saveLog(context, ref),
      ),
      child: ExcludeFocus(
        child: ListView.builder(
          reverse: true, // Newest at the bottom, and it stays scrolled there.
          itemCount: lines.length,
          itemBuilder: (context, i) => Text(lines[lines.length - 1 - i].toString(), style: style),
        ),
      ),
    );
  }
}
