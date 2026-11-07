import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';

/// The game's controls for this phone (PRD v2 P5): labels, hidden buttons
/// and the allowed modes. Standard when no game sets them or no TV is
/// connected.
final gameLayoutProvider = NotifierProvider<GameLayoutNotifier, GameLayoutMessage>(GameLayoutNotifier.new);

class GameLayoutNotifier extends Notifier<GameLayoutMessage> {
  @override
  GameLayoutMessage build() {
    final client = ref.watch(clientProvider);
    final sub = client.layouts.listen((l) => state = l);
    ref.onDispose(sub.cancel);
    return client.layout;
  }
}

/// The game's status panel for this phone (PRD v2 P6), hidden when empty.
final gameStatusProvider = NotifierProvider<GameStatusNotifier, StatusMessage>(GameStatusNotifier.new);

class GameStatusNotifier extends Notifier<StatusMessage> {
  @override
  StatusMessage build() {
    final client = ref.watch(clientProvider);
    final sub = client.statuses.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return client.status;
  }
}

/// Whether a game is drawn on this phone behind the controls (m12 §2.7)
/// because this phone is hosting it: the host route turns it on (m12 §3).
/// A game a host sends this phone is [viewActiveProvider] instead, and
/// [showsGameProvider] is the two together.
final gameShownProvider = NotifierProvider<GameShownNotifier, bool>(GameShownNotifier.new);

class GameShownNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool shown) => state = shown;
}

/// Whether this phone shows a game at all (m12 §2.7): its own while hosting
/// ([gameShownProvider]), or the one the host sends it ([viewActiveProvider]).
/// While it does, the status panel is hidden and the controls take the saved
/// opacity; in controller mode there's nothing behind them and they stay
/// fully opaque.
final showsGameProvider = Provider<bool>((ref) => ref.watch(gameShownProvider) || ref.watch(viewActiveProvider));

/// Haptic events from the TV (M5): how many arrived and were played, and
/// the latest, for Diagnostics.
typedef TvHaptics = ({int received, int played, HapticEventMessage? last});

final tvHapticsProvider = NotifierProvider<TvHapticsNotifier, TvHaptics>(TvHapticsNotifier.new);

/// Plays every haptic event the TV sends, in any input mode. The controller
/// screen keeps it alive.
class TvHapticsNotifier extends Notifier<TvHaptics> {
  @override
  TvHaptics build() {
    // Make sure the capability check has run before the first event.
    ref.watch(hapticsCapabilitiesProvider);
    final client = ref.watch(clientProvider);
    final player = ref.watch(hapticsPlayerProvider);
    final sub = client.hapticEvents.listen((message) async {
      await player.event(message);
      if (ref.mounted) state = (received: client.hapticsReceived, played: player.eventsPlayed, last: message);
    });
    ref.onDispose(sub.cancel);
    return (received: client.hapticsReceived, played: player.eventsPlayed, last: player.lastEvent);
  }
}

/// The TV's latest "How did the controls feel?" prompt (M9), until it's
/// answered or skipped. The controller screen shows it.
final ratingPromptProvider = NotifierProvider<RatingPromptNotifier, RatingAskMessage?>(RatingPromptNotifier.new);

class RatingPromptNotifier extends Notifier<RatingAskMessage?> {
  @override
  RatingAskMessage? build() {
    final client = ref.watch(clientProvider);
    final sub = client.ratingAsks.listen((ask) {
      ref.read(logProvider).add('rating', 'The TV asks how the controls felt (${ask.game})');
      state = ask;
    });
    ref.onDispose(sub.cancel);
    return null;
  }

  /// Sends the answer. A null [face] means skipped.
  void answer(RatingFace? face, {List<String> tags = const []}) {
    final ask = state;
    if (ask == null) return;
    state = null;
    ref.read(clientProvider).sendRating(RatingMessage(id: ask.id, face: face, tags: tags));
    ref.read(logProvider).add('rating', face == null ? 'Skipped the rating' : 'Rated ${face.name} ${tags.join(' ')}');
  }
}
