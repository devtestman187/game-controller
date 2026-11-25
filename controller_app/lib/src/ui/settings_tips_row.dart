import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_prefs.dart';
import '../home/home_text.dart';

/// The Settings switch for Home's coach marks (the tips). On means the marks
/// show the next time Home is idle; the choice is saved by [showTipsProvider].
class ShowTipsRow extends ConsumerWidget {
  const ShowTipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SwitchListTile(
    key: const Key('showTipsSwitch'),
    contentPadding: EdgeInsets.zero,
    title: const Text(HomeText.showTips),
    value: ref.watch(showTipsProvider),
    onChanged: (v) => ref.read(showTipsProvider.notifier).set(v),
  );
}
