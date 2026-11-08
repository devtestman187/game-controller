import 'dart:async';

import '../session_uploader.dart';
import '../stats_service.dart';
import '../stats_state.dart';

/// Analytics for the tests: [summaries] are the saved sessions, [consents]
/// every answer to the consent prompt.
class FakeStats implements StatsService {
  FakeStats({bool? consent}) : _state = StatsState(consent: consent, uploadConfigured: true);

  StatsState _state;
  final _changes = StreamController<StatsState>.broadcast();

  /// The saved sessions, as [sessions] reports them.
  final summaries = <Map<String, Object?>>[];

  /// Every answer given to the consent prompt.
  final consents = <bool>[];

  /// How many times the sessions were exported.
  int exports = 0;

  /// Replaces the state and tells the listeners.
  void emit(StatsState s) {
    _state = s;
    _changes.add(s);
  }

  @override
  StatsState get state => _state;

  @override
  Stream<StatsState> get changes => _changes.stream;

  @override
  Future<List<SessionFile>> sessions() async => [
    for (final (i, s) in summaries.indexed) SessionFile('/sessions/s$i.json', s),
  ];

  @override
  Future<String> exportAll() async {
    exports++;
    return 'D:/Downloads/thumb-party-sessions';
  }

  @override
  void setConsent(bool share) {
    consents.add(share);
    emit(_state.copyWith(consent: share));
  }

  @override
  Future<void> uploadNow() async {}
}

/// An uploader that keeps what it was given and can be told to fail.
class FakeUploader implements SessionUploader {
  /// Every summary uploaded successfully, in order.
  final uploaded = <Map<String, Object?>>[];

  /// While set, every upload fails with this message.
  String? failWith;

  @override
  Future<String?> upload(Map<String, Object?> summary) async {
    if (failWith != null) return failWith;
    uploaded.add(summary);
    return null;
  }
}
