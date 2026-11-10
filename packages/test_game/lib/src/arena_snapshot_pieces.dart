part of 'arena_snapshot.dart';

/// The pieces a frame carries besides its walls and hazards (M14 k2a), as
/// [ArenaSnapshot.fromJson] reads them.
typedef _Pieces = ({
  bool mirrored,
  List<(Offset, Offset)> movers,
  String theme,
  List<SpringSpec> springs,
  List<PostSpec> posts,
  List<BeltSpec> belts,
  List<DecorSpec> decor,
});

/// A frame's mirror flag, movers, theme and still pieces, each read from its
/// key and left at its default when the frame leaves the key out.
_Pieces _piecesOf(Map<String, Object?> j) => (
  mirrored: j['mi'] == 1,
  movers: [
    for (final m in (j['mv'] as List? ?? const []))
      if ((m as List).cast<num>() case [final x1, final y1, final x2, final y2])
        (Offset(x1.toDouble(), y1.toDouble()), Offset(x2.toDouble(), y2.toDouble())),
  ],
  theme: j['th'] as String? ?? 'playroom',
  springs: [
    for (final s in (j['sp'] as List? ?? const []))
      if ((s as List).cast<num>() case [final x, final y, ...final rest])
        SpringSpec(Offset(x.toDouble(), y.toDouble()), radius: rest.isEmpty ? springRadius : rest.first.toDouble()),
  ],
  posts: [
    for (final p in (j['po'] as List? ?? const []))
      if ((p as List).cast<num>() case [final x, final y, ...final rest])
        PostSpec(Offset(x.toDouble(), y.toDouble()), radius: rest.isEmpty ? postRadius : rest.first.toDouble()),
  ],
  belts: [
    for (final b in (j['bl'] as List? ?? const []))
      if ((b as List).cast<num>() case [final x1, final y1, final x2, final y2, ...final rest])
        BeltSpec(
          Offset(x1.toDouble(), y1.toDouble()),
          Offset(x2.toDouble(), y2.toDouble()),
          width: rest.isEmpty ? beltWidth : rest.first.toDouble(),
        ),
  ],
  decor: [
    for (final d in (j['dc'] as List? ?? const []))
      if ((d as List).cast<num>() case [final kind, final x, final y, ...final rest])
        if (kind >= 0 && kind < DecorKind.values.length)
          DecorSpec(
            DecorKind.values[kind.toInt()],
            Offset(x.toDouble(), y.toDouble()),
            size: rest.isEmpty ? decorSize : rest.first.toDouble(),
          ),
  ],
);
