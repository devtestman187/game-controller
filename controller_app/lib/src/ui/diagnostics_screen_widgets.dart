part of 'diagnostics_screen.dart';

/// The log's heading and its last 200 lines, on a tray.
Widget _logBlock(BuildContext context, WidgetRef ref) {
  final lines = ref.watch(logLinesProvider);
  final look = ToyLookScope.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: ToySizes.space8, bottom: ToySizes.space4),
        child: Text(
          SettingsText.logHeading(lines.length),
          style: look.type.button.copyWith(color: look.colors.onBackground),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          color: look.colors.tray,
          borderRadius: BorderRadius.circular(ToySizes.space8),
          border: Border.all(color: look.colors.ink, width: look.sizes.outlineWidth),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ToySizes.space8),
          child: SelectableText(
            lines.length > _keptLogLines ? lines.sublist(lines.length - _keptLogLines).join('\n') : lines.join('\n'),
            style: look.type.body.copyWith(fontFamily: 'monospace', height: _logLineHeight),
          ),
        ),
      ),
    ],
  );
}

/// A group of rows: a toy card with its name in the header band, then one row
/// per label and value. A group that needs attention takes the bad fill
/// (M13 3c).
class _Section extends StatelessWidget {
  const _Section(this.title, this.rows, {this.highlight = false});

  /// A row's label against the look's button height: the 150 px it has always
  /// had on the phone.
  static const _labelWidthShare = 3.125;

  final String title;
  final List<(String, String)> rows;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ToySizes.space12),
      child: ToyCard(
        header: title,
        headerColor: highlight ? look.colors.bad : null,
        padding: const EdgeInsets.all(ToySizes.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: ToySizes.space4 / 2),
                child: label.isEmpty
                    ? Text(value)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: look.sizes.buttonHeight * _labelWidthShare,
                            child: Text(label, style: look.type.body.copyWith(color: look.colors.inkSoft)),
                          ),
                          Expanded(child: SelectableText(value)),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
