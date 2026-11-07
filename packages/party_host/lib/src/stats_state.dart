/// What the Stats screen shows about collection and upload (M9).
final class StatsState {
  const StatsState({
    this.consent,
    this.uploadConfigured = false,
    this.waiting = 0,
    this.uploaded = 0,
    this.lastError,
    this.current,
    this.lastSaved,
    this.saved = 0,
  });

  /// The adult's answer: true to share, false not to, null if never asked.
  final bool? consent;

  /// Whether this build knows where to upload the sessions.
  final bool uploadConfigured;

  /// Finished sessions waiting to be uploaded (with consent, while offline).
  final int waiting;

  /// Sessions uploaded from this device.
  final int uploaded;

  /// Why the last upload failed, if it did.
  final String? lastError;

  /// The session being recorded right now, or null.
  final Map<String, Object?>? current;

  /// The last session saved to a file (m12 §0.6): it stays after the session
  /// ends, so a host phone can put its last session in the Diagnostics report.
  final Map<String, Object?>? lastSaved;

  /// Session files on this device.
  final int saved;

  /// A copy with the given fields changed. The members that take `Object?`
  /// can be set to null; leaving them out keeps the current value.
  StatsState copyWith({
    Object? consent = _keep,
    int? waiting,
    int? uploaded,
    Object? lastError = _keep,
    Object? current = _keep,
    Object? lastSaved = _keep,
    int? saved,
  }) => StatsState(
    consent: identical(consent, _keep) ? this.consent : consent as bool?,
    uploadConfigured: uploadConfigured,
    waiting: waiting ?? this.waiting,
    uploaded: uploaded ?? this.uploaded,
    lastError: identical(lastError, _keep) ? this.lastError : lastError as String?,
    current: identical(current, _keep) ? this.current : current as Map<String, Object?>?,
    lastSaved: identical(lastSaved, _keep) ? this.lastSaved : lastSaved as Map<String, Object?>?,
    saved: saved ?? this.saved,
  );
}

/// Marks a [StatsState.copyWith] argument that wasn't given, so the current
/// value (including null) is kept.
const Object _keep = Object();
