import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';

import '../../tv_text.dart';
import '../latency_screen.dart';
import 'panel.dart';

/// The newest log lines, with a button that saves them all to a file.
class LogPanel extends ConsumerWidget {
  const LogPanel({super.key});

  /// How much taller than its type a log line is, so dense lines stay apart.
  static const _lineHeight = 1.3;

  /// A line's style (M13 3d): the platform's monospace, so the columns of a
  /// line up, in ink on the panel's paper. The look carries no monospace of
  /// its own, so this is the one style it doesn't name.
  static TextStyle lineStyle(ToyLook look) => TextStyle(
    fontFamily: 'monospace',
    fontSize: look.type.body.fontSize,
    height: _lineHeight,
    color: look.colors.ink,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(logLinesProvider);
    final style = lineStyle(ToyLookScope.of(context));
    return Panel(
      title: TvText.log,
      trailing: HostButton(
        label: TvText.saveLog,
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
