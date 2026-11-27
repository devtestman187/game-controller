import 'variant.dart';

/// The Playlist picker (M17 plan 1.2): the host sets the order, and the playlist starts again when the night runs
/// longer than the order.
final class PlaylistPicker {
  const PlaylistPicker({required this.order});

  /// The variants in the order the host set, played one per round.
  final List<Variant> order;

  /// The variant for [round], which counts from 0; null when the [order] is empty.
  Variant? next(int round) {
    if (order.isEmpty) {
      return null;
    }
    return order[round % order.length];
  }
}
