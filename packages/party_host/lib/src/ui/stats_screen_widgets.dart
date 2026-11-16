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

/// The crash reports choice (design sentry-consent.md), in the app bar beside
/// the stats one, and only where a report could be sent: pressing it asks the
/// crash question, and its label follows this instance's answer.
class _CrashSharingButton extends ConsumerWidget {
  /// The button; it draws nothing where [crashAvailableProvider] is false.
  const _CrashSharingButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(crashAvailableProvider)) return const SizedBox.shrink();
    final on = ref.watch(consentProvider).crash == true;
    return Padding(
      padding: const EdgeInsets.only(right: ToySizes.space12),
      child: HostButton(
        key: const Key('statsCrash'),
        label: on ? ConsentText.crashOn : ConsentText.crashOff,
        icon: on ? Icons.bug_report : Icons.bug_report_outlined,
        onPressed: () => askCrashConsent(context, ref),
      ),
    );
  }
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

/// What the Stats screen shows of the saved sessions (M14 sentry1): their
/// entries, the one picked, and where the read of them stands — still going,
/// failed with a Retry, or done. It travels as one thing, so the body takes
/// the screen's whole sessions area as a single value.
class _SessionsRead {
  const _SessionsRead({
    required this.entries,
    required this.selected,
    required this.onSelect,
    required this.isLoading,
    required this.hasFailed,
    required this.onRetry,
  });

  /// One line of the list for each session: the live one, then the saved.
  final List<({String label, Map<String, Object?> summary})> entries;

  /// Which entry is shown.
  final int selected;

  /// Shows the entry at an index.
  final void Function(int index) onSelect;

  /// Whether the session files are still being read.
  final bool isLoading;

  /// Whether the read failed, so the area shows the error and its Retry.
  final bool hasFailed;

  /// Reads the session files again.
  final VoidCallback onRetry;
}

/// The screen's body: what the stats are doing, then the sessions to pick
/// from and the one picked.
class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats, required this.read});

  final StatsState stats;
  final _SessionsRead read;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final entries = read.entries;
    final shown = entries.isEmpty ? null : entries[read.selected.clamp(0, entries.length - 1)];
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
          child: read.isLoading
              ? const Center(child: CircularProgressIndicator())
              : read.hasFailed
              ? _SessionsFailed(onRetry: read.onRetry)
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
                      child: _SessionList(entries: entries, selected: read.selected, onSelect: read.onSelect),
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

/// The saved sessions could not be read (M14 sentry1): says so in place of
/// the list, and its Retry reads them again.
class _SessionsFailed extends StatelessWidget {
  const _SessionsFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Center(
      child: ToyCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(HostText.sessionsFailed, style: look.type.button, textAlign: TextAlign.center),
            const SizedBox(height: ToySizes.space16),
            HostButton(key: const Key('statsRetry'), label: HostText.retry, icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
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
