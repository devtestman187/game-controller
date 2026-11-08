part of 'stats_screen.dart';

/// The stats sharing choice (T19), in the app bar.
class _SharingButton extends ConsumerWidget {
  const _SharingButton({required this.consent});

  final bool? consent;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: HostButton(
      key: const Key('statsSharing'),
      label: consent == true ? 'Sharing: on' : 'Sharing: off',
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
    padding: const EdgeInsets.only(right: 16),
    child: HostButton(
      key: const Key('statsExport'),
      label: 'Export',
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
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final shown = entries.isEmpty ? null : entries[selected.clamp(0, entries.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _statusLine(stats),
          key: const Key('statsStatus'),
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: loading
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
                      child: _SessionList(entries: entries, selected: selected, onSelect: onSelect),
                    ),
                    const SizedBox(width: 16),
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
          padding: const EdgeInsets.only(bottom: 6),
          child: _SessionButton(
            key: Key('session-$i'),
            label: e.label,
            detail: _detail(e.summary),
            selected: i == selected,
            onPressed: () => onSelect(i),
          ),
        ),
    ],
  );
}

class _SessionButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return FilledButton.tonal(
      onPressed: onPressed,
      style:
          ButtonStyle(
            alignment: Alignment.centerLeft,
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          ).merge(
            hostButtonLook(
              context,
              showFocus: ref.watch(hostFocusLookProvider),
              fill: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
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
