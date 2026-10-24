part of 'messages.dart';

/// Controller buttons. The wire name is the enum name.
enum ControllerButton { a, b, x, y, start, select }

/// The controller's whole input state: which buttons are held and where the
/// D-pad points.
///
/// The phone sends the full state on every change instead of separate
/// down/up events, so the TV can never miss a release: the latest message is
/// always the truth, and an empty state releases everything.
final class InputStateMessage extends Message {
  InputStateMessage({required this.seq, Set<ControllerButton> buttons = const {}, this.dx = 0, this.dy = 0})
    : buttons = Set.unmodifiable(buttons) {
    if (dx < -1 || dx > 1 || dy < -1 || dy > 1) {
      throw ArgumentError('dx and dy must be -1, 0 or 1, got ($dx, $dy)');
    }
  }

  static const String wireType = 'input';

  /// Increases with every state the phone sends on a connection, so the TV
  /// can drop anything out of order.
  final int seq;
  final Set<ControllerButton> buttons;

  /// D-pad direction: -1 left, 1 right.
  final int dx;

  /// D-pad direction: -1 up, 1 down (screen coordinates).
  final int dy;

  bool get isNeutral => buttons.isEmpty && dx == 0 && dy == 0;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'seq': seq,
    // Sorted so equal states encode identically.
    'buttons': [for (final b in ControllerButton.values) if (buttons.contains(b)) b.name],
    'dx': dx,
    'dy': dy,
  };

  static InputStateMessage fromPayload(Map<String, Object?> p) {
    final raw = p['buttons'];
    if (raw is! List) throw const FormatException('Field "buttons" must be a list');
    final buttons = <ControllerButton>{};
    for (final name in raw) {
      if (name is! String) throw const FormatException('Button names must be strings');
      // Unknown names come from a newer phone. Ignore them.
      final button = ControllerButton.values.where((b) => b.name == name).firstOrNull;
      if (button != null) buttons.add(button);
    }
    final dx = requireInt(p, 'dx');
    final dy = requireInt(p, 'dy');
    if (dx.abs() > 1 || dy.abs() > 1) throw const FormatException('dx and dy must be -1, 0 or 1');
    return InputStateMessage(seq: requireInt(p, 'seq'), buttons: buttons, dx: dx, dy: dy);
  }

  // Lists aren't compared by value in the base class, so compare here.
  @override
  bool operator ==(Object other) =>
      other is InputStateMessage &&
      other.seq == seq &&
      other.dx == dx &&
      other.dy == dy &&
      other.buttons.length == buttons.length &&
      other.buttons.containsAll(buttons);

  @override
  int get hashCode => Object.hash(seq, dx, dy, Object.hashAllUnordered(buttons));
}
