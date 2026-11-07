import 'package:flutter/widgets.dart';
import 'package:game_kit/game_kit.dart';

/// A snapshot holding one dot at [x], which [lerpTo] moves: enough for a test
/// to read the position a [FrameView] drew.
final class DotSnapshot implements GameSnapshot {
  const DotSnapshot(this.x);

  /// The version [DotModule] says its snapshots are.
  static const version = 3;

  final double x;

  @override
  Map<String, Object?> toJson() => {'v': version, 'x': x};

  @override
  GameSnapshot lerpTo(GameSnapshot next, double t) {
    if (next is! DotSnapshot) throw ArgumentError.value(next, 'next', 'A dot snapshot lerps with another dot snapshot');
    return DotSnapshot(x + (next.x - x) * t);
  }
}

/// A module for [DotViewer], so a test controls the ID and version a start
/// carries.
final class DotModule implements GameModule {
  const DotModule();

  @override
  String get id => 'dot';

  @override
  int get snapshotVersion => DotSnapshot.version;

  /// The setup must say where the dot starts, so a setup that doesn't fit
  /// throws as a real viewer's would.
  @override
  GameViewer createViewer(Map<String, Object?> setup) {
    if (setup['start'] is! num) throw const FormatException('start');
    return const DotViewer();
  }
}

/// Decodes and draws dot frames.
final class DotViewer implements GameViewer {
  const DotViewer();

  @override
  GameSnapshot decode(Map<String, Object?> json) {
    if (json['v'] != DotSnapshot.version) throw FormatException('v: ${json['v']}');
    final x = json['x'];
    if (x is! num) throw const FormatException('x');
    return DotSnapshot(x.toDouble());
  }

  @override
  Widget build(BuildContext context, GameSnapshot snapshot, ViewContext view) {
    if (snapshot is! DotSnapshot) throw ArgumentError.value(snapshot, 'snapshot', 'A dot viewer draws dot frames');
    return DotDraw(snapshot: snapshot, view: view);
  }
}

/// The dot on the screen: a test reads the drawn [snapshot] and the [view] the
/// viewer was given off it.
final class DotDraw extends StatelessWidget {
  const DotDraw({required this.snapshot, required this.view, super.key});

  final DotSnapshot snapshot;
  final ViewContext view;

  @override
  Widget build(BuildContext context) => Text('x: ${snapshot.x}');
}
