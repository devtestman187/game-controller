import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/device.dart';

const _showTipsKey = 'showTips';

final showTipsProvider = NotifierProvider<ShowTipsNotifier, bool>(ShowTipsNotifier.new);

/// Whether Home shows the coach marks (first-time help). A missing saved key
/// means show them; finishing or skipping the marks, or the Settings switch,
/// sets it.
class ShowTipsNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(prefsProvider).getBool(_showTipsKey) ?? true;

  /// Sets the flag and saves it, so the next launch reads the same value.
  Future<void> set(bool show) async {
    state = show;
    await ref.read(prefsProvider).setBool(_showTipsKey, show);
  }
}
