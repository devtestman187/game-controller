import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metrics/metrics.dart';

import '../analytics.dart';
import '../providers.dart';
import 'tv_button.dart';

/// The Stats screen (PRD v2 T18): each session's summary for each phone and
/// input mode, Export of the session files, and the stats sharing choice
/// (T19). Works with the remote.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  List<SessionFile> _sessions = const [];
  int _selected = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(statsServiceProvider).sessions();
    if (!mounted) return;
    setState(() {
      _sessions = list;
      _loading = false;
      _selected = _selected.clamp(0, list.isEmpty ? 0 : list.length);
    });
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ref.read(statsServiceProvider).exportAll();
      messenger.showSnackBar(
        SnackBar(content: Text('Session files saved to $path'), duration: const Duration(seconds: 8)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not export: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsStateProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // The live session first, then the saved ones (newest first).
    final current = stats.current;
    final entries = [
      if (current != null) (label: 'Now', summary: current),
      for (final f in _sessions)
        if (f.id != current?['id']) (label: _title(f.summary), summary: f.summary),
    ];
    final shown = entries.isEmpty ? null : entries[_selected.clamp(0, entries.length - 1)];

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stats'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TvButton(
                key: const Key('statsSharing'),
                label: stats.consent == true ? 'Sharing: on' : 'Sharing: off',
                icon: stats.consent == true ? Icons.cloud_upload_outlined : Icons.cloud_off_outlined,
                onPressed: () => askConsent(context, ref),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TvButton(
                key: const Key('statsExport'),
                label: 'Export',
                icon: Icons.save_alt,
                autofocus: true,
                onPressed: _export,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _statusLine(stats),
                  key: const Key('statsStatus'),
                  style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : entries.isEmpty
                      ? Center(
                          child: Text(
                            'No sessions yet. Stats are recorded while phones are connected.',
                            style: text.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 240,
                              child: ListView(
                                children: [
                                  for (final (i, e) in entries.indexed)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: _SessionButton(
                                        key: Key('session-$i'),
                                        label: e.label,
                                        detail: _detail(e.summary),
                                        selected: i == _selected,
                                        onPressed: () => setState(() => _selected = i),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SingleChildScrollView(child: SessionView(summary: shown!.summary)),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _statusLine(StatsState s) {
    final saved = '${s.saved} session${s.saved == 1 ? '' : 's'} saved on this device';
    if (s.consent != true) return '$saved. Sharing is off: nothing leaves this device.';
    if (!s.uploadConfigured) return '$saved. Sharing is on, but this build has no upload set up.';
    final waiting = s.waiting == 0 ? 'none waiting' : '${s.waiting} waiting to upload';
    final error = s.lastError == null ? '' : ' (last try failed, trying again later)';
    return '$saved. Sharing is on: ${s.uploaded} uploaded, $waiting$error.';
  }

  static String _title(Map<String, Object?> s) {
    final date = s['date'] as String? ?? '';
    final id = (s['id'] as String? ?? '').padRight(4).substring(0, 4);
    return '$date · $id';
  }

  static String _detail(Map<String, Object?> s) {
    final minutes = ((s['durationS'] as num? ?? 0) / 60).toStringAsFixed(1);
    final players = (s['players'] as List?)?.length ?? 0;
    final rounds = (s['rounds'] as List?)?.length ?? 0;
    return '$minutes min · $players player${players == 1 ? '' : 's'} · $rounds round${rounds == 1 ? '' : 's'}';
  }
}

class _SessionButton extends StatelessWidget {
  const _SessionButton({
    super.key,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return FilledButton.tonal(
      onPressed: onPressed,
      style: ButtonStyle(
        alignment: Alignment.centerLeft,
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
        backgroundColor: WidgetStatePropertyAll(selected ? scheme.primaryContainer : scheme.surfaceContainerHigh),
        side: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused) ? BorderSide(color: scheme.primary, width: 4) : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.titleMedium),
          Text(detail, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// One session: for each phone and input mode, time, presses, empty taps,
/// near misses and input delay (PRD v2 M9's first acceptance test).
class SessionView extends StatelessWidget {
  const SessionView({super.key, required this.summary});

  final Map<String, Object?> summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final rows = rowsOf(summary)..sort((a, b) => a.install.compareTo(b.install));
    final players = {
      for (final p in (summary['players'] as List?) ?? const [])
        if (p is Map) p['install'] as String?: p,
    };
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final rounds = (summary['rounds'] as List?)?.length ?? 0;
    final frames = summary['frames'] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${((summary['durationS'] as num? ?? 0) / 60).toStringAsFixed(1)} min · $rounds arena round${rounds == 1 ? '' : 's'}'
          '${frames == null || (frames['drawn'] as num? ?? 0) == 0 ? '' : ' · ${frames['dropped']} late frames of ${frames['drawn']}'}',
          style: text.titleMedium,
        ),
        const SizedBox(height: 8),
        Table(
          key: const Key('sessionTable'),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              children: [
                for (final h in const [
                  'Player',
                  'Mode',
                  'Time',
                  'Presses',
                  'Empty taps',
                  'Near misses',
                  'Slide-offs',
                  'Input delay',
                  'Rating',
                ])
                  _Cell(h, style: muted),
              ],
            ),
            for (final r in rows)
              TableRow(
                children: [
                  _Cell(_playerLabel(players[r.install], r)),
                  _Cell(_mode(r.mode)),
                  _Cell(_time(r.ms)),
                  _Cell('${r.presses}'),
                  _Cell('${r.empty}'),
                  _Cell('${r.near}'),
                  _Cell('${r.slide}'),
                  _Cell(r.inputMedianMs == null ? '–' : '${r.inputMedianMs} ms (p95 ${r.inputP95Ms ?? '–'})'),
                  _Cell(
                    r.good + r.okay + r.bad == 0
                        ? '–'
                        : [
                            if (r.good > 0) '${r.good} good',
                            if (r.okay > 0) '${r.okay} okay',
                            if (r.bad > 0) '${r.bad} bad',
                          ].join(', '),
                  ),
                ],
              ),
          ],
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('No players yet.', style: muted),
          ),
        const SizedBox(height: 12),
        Text(
          'Input delay is the median for the whole session. Near misses are taps within about 8 mm of a control '
          'that missed it; empty taps landed on no control.',
          style: muted,
        ),
      ],
    );
  }

  static String _playerLabel(Map? p, ModeRow r) {
    final n = p?['player'];
    final kind = r.deviceKind == 'unknown' ? r.platform : r.deviceKind;
    return 'P$n $kind';
  }

  static String _mode(String m) => switch (m) {
    'dpad' => 'D-pad',
    'gyro' => 'Gyro',
    'sticks' => 'Sticks',
    'keyboard' => 'Keyboard',
    _ => m,
  };

  static String _time(int ms) {
    final s = (ms / 1000).round();
    return s >= 60 ? '${s ~/ 60} min ${s % 60} s' : '$s s';
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 20, bottom: 6),
    child: Text(text, style: style ?? Theme.of(context).textTheme.bodyLarge),
  );
}

/// The consent prompt (PRD v2 T19): on first launch, and from the Stats
/// screen to change the answer. It is for the adult, so it says plainly what
/// is shared and that nothing is shared by default.
Future<void> askConsent(BuildContext context, WidgetRef ref) async {
  final share = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      key: const Key('consentDialog'),
      title: const Text('Share anonymous gameplay stats?'),
      content: const SizedBox(
        width: 560,
        child: Text(
          'For the adult in charge of this device.\n\n'
          'Thumb Party TV can send anonymous stats to its developer: how the phone controls are used (presses, '
          'missed taps, timing, which mode), how quick the connection is, and how the games go. They help make '
          'the controls better.\n\n'
          'No names, accounts, contacts, location, advertising IDs or Wi-Fi details are ever sent. The stats are '
          'kept on this device either way, and you can change this at any time on the Stats screen. The privacy '
          'policy explains it in full.',
        ),
      ),
      actions: [
        TextButton(
          key: const Key('consentNo'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Don\'t share'),
        ),
        FilledButton(
          key: const Key('consentYes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Share stats'),
        ),
      ],
    ),
  );
  if (share != null) ref.read(statsServiceProvider).setConsent(share);
}
