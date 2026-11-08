import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metrics/metrics.dart';
import 'package:toy_look/toy_look.dart';

import '../text/host_text.dart';
import '../providers.dart';
import '../stats_service.dart';
import '../stats_state.dart';
import 'host_button.dart';
import 'host_card_button.dart';
import 'host_screen.dart';

part 'stats_screen_widgets.dart';

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
      messenger.showSnackBar(SnackBar(content: Text(HostText.savedTo(path)), duration: const Duration(seconds: 8)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(HostText.exportFailed(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsStateProvider);
    // The live session first, then the saved ones (newest first).
    final current = stats.current;
    final entries = [
      if (current != null) (label: HostText.now, summary: current),
      for (final f in _sessions)
        if (f.id != current?['id']) (label: HostText.sessionTitle(f.summary), summary: f.summary),
    ];
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostScreen(
        title: HostText.stats,
        actions: [
          _SharingButton(consent: stats.consent),
          _ExportButton(onPressed: _export),
        ],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ToySizes.space16),
            child: _StatsBody(
              stats: stats,
              loading: _loading,
              entries: entries,
              selected: _selected,
              onSelect: (i) => setState(() => _selected = i),
            ),
          ),
        ),
      ),
    );
  }
}

/// One session on the paper: for each phone and input mode, time, presses,
/// empty taps, near misses and input delay (PRD v2 M9's first acceptance
/// test). Its length and rounds head the card, the note under the table
/// explains the columns.
class SessionView extends StatelessWidget {
  const SessionView({super.key, required this.summary});

  final Map<String, Object?> summary;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final rows = rowsOf(summary)..sort((a, b) => a.install.compareTo(b.install));
    final players = {
      for (final p in (summary['players'] as List?) ?? const [])
        if (p is Map) p['install'] as String?: p,
    };
    return ToyCard(
      padding: const EdgeInsets.all(ToySizes.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(HostText.sessionLine(summary), style: look.type.button),
          const SizedBox(height: ToySizes.space16),
          _SessionTable(rows: rows, players: players),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: ToySizes.space12),
              child: Text(HostText.noPlayersYet, style: look.type.body),
            ),
          const SizedBox(height: ToySizes.space16),
          Text(HostText.inputDelayNote, style: look.type.body),
        ],
      ),
    );
  }
}

/// One row for each phone and input mode.
class _SessionTable extends StatelessWidget {
  const _SessionTable({required this.rows, required this.players});

  final List<ModeRow> rows;

  /// Each phone's entry in the summary, by install id.
  final Map<String?, Map<Object?, Object?>> players;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final heading = look.type.button.copyWith(color: look.colors.inkSoft);
    return Table(
      key: const Key('sessionTable'),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        TableRow(children: [for (final h in HostText.sessionHeaders) _Cell(h, style: heading)]),
        for (final r in rows)
          TableRow(
            children: [
              _Cell(HostText.playerKind(players[r.install], r.deviceKind == 'unknown' ? r.platform : r.deviceKind)),
              _Cell(HostText.modeRow(r.mode)),
              _Cell(HostText.timePlaying(r.activeMs)),
              _Cell('${r.presses}'),
              _Cell('${r.empty}'),
              _Cell('${r.near}'),
              _Cell('${r.slide}'),
              _Cell(r.inputMedianMs == null ? HostText.dash : HostText.inputDelayRow(r.inputMedianMs!, r.inputP95Ms)),
              _Cell(
                r.good + r.okay + r.bad == 0
                    ? HostText.dash
                    : [
                        if (r.good > 0) '${r.good} good',
                        if (r.okay > 0) '${r.okay} okay',
                        if (r.bad > 0) '${r.bad} bad',
                      ].join(', '),
              ),
            ],
          ),
      ],
    );
  }
}

/// One cell of the table, on the paper.
class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: ToySizes.space24, bottom: ToySizes.space8),
    child: Text(text, style: style ?? ToyLookScope.of(context).type.body),
  );
}

/// How wide the consent prompt's text is, in logical pixels: a comfortable
/// line length for a paragraph an adult reads once.
const _consentWidthPx = 560.0;

/// The consent prompt (PRD v2 T19): on first launch, and from the Stats
/// screen to change the answer. It is for the adult, so it says plainly what
/// is shared and that nothing is shared by default.
///
/// Its paper, ink edge and ink text come from the look's dialog theme (M13
/// 3a); M13 3b gives it the host's own buttons, so the remote's focus and a
/// thumb press work as they do everywhere else.
Future<void> askConsent(BuildContext context, WidgetRef ref) async {
  final share = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      key: const Key('consentDialog'),
      title: const Text(HostText.consentQuestion),
      content: const SizedBox(width: _consentWidthPx, child: Text(HostText.consentBody)),
      actions: [
        HostButton(
          key: const Key('consentNo'),
          label: HostText.dontShare,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        HostButton(
          key: const Key('consentYes'),
          label: HostText.shareStats,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (share != null) ref.read(statsServiceProvider).setConsent(share);
}
