import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';

/// The night's end the host sent this phone (M16 bugs4 np1): the final standings
/// and the awards, kept so the phone can show them after the host's reveal. Null
/// until the host sends one. A new view clears it, and so does a dropped link, as
/// [viewResultProvider] clears its result.
final nightEndProvider = NotifierProvider<NightEndNotifier, NightEndMessage?>(NightEndNotifier.new);

class NightEndNotifier extends Notifier<NightEndMessage?> {
  @override
  NightEndMessage? build() {
    final client = ref.watch(clientProvider);
    final sub = client.nightEnds.listen((end) => state = end);
    final viewSub = client.view.listen((event) {
      switch (event) {
        case ViewStarted():
          state = null;
        case ViewEnded() || ViewFrame() || HostAway() || HostBack() || PlayerAway() || PlayerBack():
          break;
      }
    });
    ref.onDispose(sub.cancel);
    ref.onDispose(viewSub.cancel);
    ref.listen(clientStateProvider, (previous, next) {
      if (!next.isConnected) state = null;
    });
    return null;
  }
}
