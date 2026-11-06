import 'dart:math';

import 'package:protocol/protocol.dart';

/// What [MetricsOutbox.add] did with a batch.
enum OutboxResult {
  /// An older or equal batch of the segment was already waiting; nothing
  /// changed and nothing is sent.
  ignored,

  /// The batch waits for an acknowledgement now.
  kept,

  /// The batch waits, and the oldest segment was dropped to make room.
  droppedOldest,
}

/// Metrics batches not yet acknowledged, the newest per segment, oldest
/// segment first (M9). Kept across reconnects, so a Wi-Fi drop loses none
/// (internal).
final class MetricsOutbox {
  /// At most this many segments wait for an ack. The oldest go first.
  static const maxOutbox = 64;

  final _outbox = <String, MetricsMessage>{};

  /// The highest acknowledged batch per segment still in [_outbox].
  final _acked = <String, int>{};

  /// Segments waiting for the TV to acknowledge them.
  int get waiting => _outbox.length;

  /// Batches the TV hasn't acknowledged yet, oldest segment first.
  Iterable<MetricsMessage> get unacknowledged =>
      _outbox.values.where((batch) => (_acked[batch.segment] ?? -1) < batch.index);

  /// Queues [batch], keeping only the newest of its segment.
  OutboxResult add(MetricsMessage batch) {
    final previous = _outbox[batch.segment];
    if (previous != null && previous.index >= batch.index) return OutboxResult.ignored;
    _outbox.remove(batch.segment);
    _outbox[batch.segment] = batch;
    if (_outbox.length <= maxOutbox) return OutboxResult.kept;
    final oldest = _outbox.keys.first;
    _outbox.remove(oldest);
    _acked.remove(oldest);
    return OutboxResult.droppedOldest;
  }

  /// Notes the TV's answer: a finished segment goes, otherwise its highest
  /// acknowledged batch is remembered.
  void acknowledge(MetricsAckMessage ack) {
    final batch = _outbox[ack.segment];
    if (batch == null) return;
    if (ack.index >= batch.index && batch.ended) {
      _outbox.remove(ack.segment);
      _acked.remove(ack.segment);
    } else {
      _acked[ack.segment] = max(_acked[ack.segment] ?? -1, ack.index);
    }
  }
}
