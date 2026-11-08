part of 'stats_screen.dart';

/// The stats sharing choice (T19), in the app bar.
class _SharingButton extends ConsumerWidget {
  const _SharingButton({required this.consent});

  final bool? consent;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(right: ToySizes.space12),
    child: HostButton(
      key: const Key('statsSharing'),
      label: consent == true ? HostText.sharingOn : HostText.sharingOff,
      icon: consent == true ? Icons.cloud_upload_outlined : Icons.cloud_off_outlined,
      onPressed: () => askConsent(context, ref),
    ),
  );
}

/// Export of the session files, in the app bar.
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: ToySizes.space16),
    child: HostButton(
      key: const Key('statsExport'),
      label: HostText.export,
      icon: Icons.save_alt,
      autofocus: true,
      onPressed: onPressed,
    ),
  );
}

/// The screen's body: what the stats are doing, then the sessions to pick
/// from and the one picked.
class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.stats,
    required this.loading,
    required this.entries,
    required this.selected,
    required this.onSelect,
  });

  final StatsState stats;
  final bool loading;
  final List<({String label, Map<String, Object?> summary})> entries;
  final int selected;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final shown = entries.isEmpty ? null : entries[selected.clamp(0, entries.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToyCard(
          padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space12),
          child: Text(
            HostText.statusLine(stats),
            key: const Key('statsStatus'),
            style: look.type.body.copyWith(color: look.colors.inkSoft),
          ),
        ),
        const SizedBox(height: ToySizes.space16),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
              ? Center(
                  child: ToyCard(
                    child: Text(HostText.noSessions, style: look.type.button, textAlign: TextAlign.center),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: look.sizes.buttonHeight * _sessionListWidthShare,
                      child: _SessionList(entries: entries, selected: selected, onSelect: onSelect),
                    ),
                    const SizedBox(width: ToySizes.space16),
                    Expanded(
                      child: SingleChildScrollView(child: SessionView(summary: shown!.summary)),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// How wide the session list is, in button heights: enough for a date and a
/// line of its detail at both sizes.
const _sessionListWidthShare = 5.0;

/// The sessions to pick from: the live one, then the saved ones.
class _SessionList extends StatelessWidget {
  const _SessionList({required this.entries, required this.selected, required this.onSelect});

  final List<({String label, Map<String, Object?> summary})> entries;
  final int selected;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final (i, e) in entries.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: ToySizes.space8),
          child: _SessionButton(
            key: Key('session-$i'),
            label: e.label,
            detail: HostText.sessionDetail(e.summary),
            selected: i == selected,
            onPressed: () => onSelect(i),
          ),
        ),
    ],
  );
}

/// One session in the list: a paper card headed with its date, filled with
/// the look's focus colour while it is the one shown.
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
    final look = ToyLookScope.of(context);
    return HostCardButton(
      onPressed: onPressed,
      child: ToyCard(
        header: label,
        headerColor: selected ? look.colors.focus : look.colors.paper,
        popIn: false,
        padding: const EdgeInsets.symmetric(horizontal: ToySizes.space16, vertical: ToySizes.space12),
        child: Text(detail, style: look.type.body),
      ),
    );
  }
}
