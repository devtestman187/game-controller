/// The City Rush board as a widget (M17 map2b): the cached static map with the moving layer over
/// it, fitted to whatever room it is given, from a phone to a TV. It only draws the snapshot.
library;

import 'package:flutter/widgets.dart';
import 'package:toy_look/toy_look.dart';

import '../board.dart';
import '../rules.dart';
import 'city_layout.dart';
import 'city_overlay_painter.dart';
import 'city_painter.dart';
import 'city_scene.dart';

/// The smallest a token's disc may be, in dp: a thumb-sized mark that stays readable on a phone
/// where eight players crowd the board.
const cityMinTokenDiameterDp = 24.0;

/// The smallest tile, in dp, that still has room for Bolts chips. Below it the chips are dropped
/// so a phone is not cluttered; the number badges stay. 20 puts 8 players on a 360x640 phone
/// (tile 17.4 dp) below it and every TV size above it.
const cityChipMinTileSize = 20.0;

/// Draws [snapshot] on the room it is given: the board, built tiles, tokens and, when the tiles
/// are big enough, the Bolts chips.
class CityMapView extends StatefulWidget {
  /// Creates a view of [snapshot].
  const CityMapView({required this.snapshot, super.key});

  /// What to draw.
  final CitySnapshot snapshot;

  @override
  State<CityMapView> createState() => _CityMapViewState();
}

class _CityMapViewState extends State<CityMapView> {
  final CityStaticCache _cache = CityStaticCache();
  CityLayout? _layout;
  Board? _layoutBoard;
  CityRules? _layoutRules;

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  /// The layout for [size], kept while the size, board and rules are the same.
  CityLayout _layoutFor(Size size, CitySnapshot snapshot) {
    final kept = _layout;
    if (kept != null &&
        kept.size == size &&
        identical(_layoutBoard, snapshot.board) &&
        identical(_layoutRules, snapshot.rules)) {
      return kept;
    }
    final layout = CityLayout.compute(size: size, board: snapshot.board, rules: snapshot.rules);
    _layout = layout;
    _layoutBoard = snapshot.board;
    _layoutRules = snapshot.rules;
    return layout;
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final snapshot = widget.snapshot;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final layout = _layoutFor(size, snapshot);
        final shown = layout.tileSize < cityChipMinTileSize ? _withoutChips(snapshot) : snapshot;
        return SizedBox.fromSize(
          size: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: CityPainter(layout: layout, board: snapshot.board, look: look, cache: _cache),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: CityOverlayPainter(
                    layout: layout,
                    scene: CityScene.from(shown, layout),
                    look: look,
                    minTokenDiameter: cityMinTokenDiameterDp,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  CitySnapshot _withoutChips(CitySnapshot snapshot) => CitySnapshot(
    board: snapshot.board,
    rules: snapshot.rules,
    tilesBuilt: snapshot.tilesBuilt,
    tokens: snapshot.tokens,
    bolts: null,
    hasRoadworks: snapshot.hasRoadworks,
  );
}
