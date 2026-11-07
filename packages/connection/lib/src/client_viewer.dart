import 'package:protocol/protocol.dart';

import 'viewer_stats.dart';

/// What a controller that shows the game measures, and how it goes into the
/// metrics batches it sends (m12 §4, §6) (internal; [ControllerClient] makes
/// one for a controller that listed [Capability.view]).
///
/// It holds only the phone's side: the input times a drawn frame is measured
/// from, and the samples and counts of [ViewerStats]. Drawing and playout
/// belong to the viewer (`FrameView` on a phone, `SimView` in the simulated
/// controller), so a controller that only sends inputs measures nothing.
final class ClientViewer {
  /// The samples and counts so far, reset on view_start by the viewer.
  final ViewerStats stats = ViewerStats(hz: ViewerStats.simStepHz);

  /// Remembers that [state] went out at its own `sentAtMs`, so the frame that
  /// acknowledges its seq can be measured from that send. A state with no send
  /// time (an older phone's) can't be measured and is ignored.
  void inputSent(InputStateMessage state) {
    final sentAtMs = state.sentAtMs;
    if (sentAtMs != null) stats.inputSent(state.seq, sentAtMs);
  }

  /// [batch] with the samples and counts measured since the last batch (m12
  /// §6), and starts the next batch.
  ///
  /// Called once per batch as it is given to the client, so a batch waiting
  /// for a reconnect keeps its samples and a re-sent one takes no more.
  MetricsMessage withSamples(MetricsMessage batch) {
    final drained = stats.drain();
    return MetricsMessage(
      segment: batch.segment,
      index: batch.index,
      mode: batch.mode,
      durationMs: batch.durationMs,
      ended: batch.ended,
      data: batch.data,
      stages: drained.stages,
      view: drained.view,
    );
  }
}
