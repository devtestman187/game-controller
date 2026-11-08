/// The smallest a piece may be drawn on the board in a `phones` match
/// (m12-phone-layout §0.3, §5), as its circumscribed diameter ([PieceShape.size])
/// in millimetres on the smallest phone screen.
///
/// A shown game fills a phone's whole safe area (m12-phone-layout §0.2, §0.7),
/// so the size comes from [PuzzleCamera.scale] and the phone's px per
/// millimetre, not from the body below the top bar. The one-row tray along the
/// top is what sets the floor: 9 mm can't be met on a landscape phone (§0.3).
///
/// Every Easy and Medium puzzle is above it today: on the iPhone SE the
/// smallest pieces are the rocket's window at 8.99 mm, the tree's sun at
/// 9.34, the house's sun at 9.42 and the boat's flag at 10.35 (§0.3), and the
/// lowest anywhere is 8.53 mm, the rocket's window on the small 16:9 phone.
/// `controller_app/test/puzzle_size_test.dart` fails when a puzzle or the
/// layout shrinks a piece below the floor, so a regression can't go unnoticed.
const double minPieceMm = 8.5;

/// The smallest a piece may be drawn in the other side's mirror, in mm
/// (m12-opponent-mirror rules 1 and 5). The mirror shows where they are and
/// what they have placed, not what the shapes are, so a piece there only has
/// to read as a mark: a quarter of the board's size is 2.13 mm for a piece at
/// [minPieceMm], which is a smudge on a phone held at arm's length, and 2.2 mm
/// is the smallest that reads. `PuzzleCamera.mirrorFraction` scales the mirror
/// to keep it, and the mirror tests check it on both phones.
///
/// It follows [minPieceMm] the same way: the board's mm per unit is at least
/// [minPieceMm] over the smallest piece's diameter, so the mirror's mm per
/// unit is its fraction of the board's, and the piece cancels out.
const double mirrorMinPieceMm = 2.2;
