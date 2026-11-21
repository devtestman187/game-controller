import 'dart:async';

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../night/night_awards.dart';
import '../text/host_text.dart';
import 'host_button.dart';
import 'host_focus_ring.dart';
import 'night_widgets.dart';

/// A tile's height on the night's start card, in frame px (DESIGN section 4):
/// the award's disc, its name in the look's room, and the "i" beside them.
const awardTileHeightPx = 84.0;

/// The award's disc in a tile, in frame px: the picture a player knows the
/// award by (the reveal draws the same key large).
const awardTileDiscPx = 48.0;

/// The "i" button's box in a tile, in frame px: a touch target a thumb finds
/// without aiming.
const awardTileInfoPx = 48.0;

/// The room between the awards' tiles, in frame px: the look's step, so three
/// tiles read as one row.
const awardTileGapPx = ToySizes.space16;

/// How wide the award's explanation is, in frame px: a small card, so the line
/// never covers the awards it explains (DESIGN section 4).
const awardExplanationWidthPx = 480.0;

/// What the award's explanation is tall besides its OK button, in frame px
/// (B-033): one height for every award, so a player's eye finds the same box
/// whatever line it holds.
///
/// Measured from the tallest of the twelve awards laid out at
/// [awardExplanationWidthPx] in the frame's type: its header band, the 24 px
/// padding above and below the body, one line of 22 px text and the 24 px gap
/// (207 measured with the menu's 48 px button less that button). At 432 px of
/// room every award's line stays on one line, so this holds the longest.
const awardExplanationFixedPx = 159.0;

/// How tall the award's explanation is in [look], in frame px (B-033, M16 bugs1
/// f1): [awardExplanationFixedPx] plus the look's own button, so the OK button
/// sits wholly inside the box on every host — 207 with the menu's 48 px button
/// and 223 with the TV's 64 px one. Both fit the shortest frame (540 px) with
/// room to spare, so the box never has to scroll.
double awardExplanationHeightPx(ToyLook look) => awardExplanationFixedPx + look.sizes.buttonHeight;

/// One of the night's three awards on its start card (M16 phonehost2 S3,
/// DESIGN section 4): its picture and its name on one line, and an "i" that
/// opens the line that says who wins it.
///
/// The card names the award in one row of three equal tiles instead of three
/// cards of their own: the name is what a player reads, and the reason the
/// award is given is one tap away (the design's "small popover, so no text is
/// lost"), so the three fit the body's height without a scroll.
class AwardTile extends StatelessWidget {
  const AwardTile({super.key, required this.award, required this.colour});

  /// The award this tile names.
  final NightAward award;

  /// The award's colour: its disc's fill, as the card's three had it.
  final Color colour;

  /// Opens the award's explanation over the screen.
  void _explain(BuildContext context) => unawaited(
    showDialog<void>(
      context: context,
      builder: (_) => _AwardExplanation(award: award),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return Container(
      height: awardTileHeightPx,
      padding: const EdgeInsets.all(ToySizes.space12),
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border.all(color: colors.ink, width: look.sizes.outlineWidth),
        borderRadius: BorderRadius.circular(ToySizes.cardCorner),
      ),
      child: Row(
        children: [
          NightDisc(colour: colour, icon: nightAwardIcon(award.picture), size: awardTileDiscPx),
          const SizedBox(width: ToySizes.space12),
          Expanded(
            child: Text(
              award.title,
              style: ToyType.frame.body.copyWith(color: colors.ink),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: ToySizes.space8),
          SizedBox.square(
            dimension: awardTileInfoPx,
            child: HostFocusRing(
              child: IconButton(
                key: Key('awardInfo-${award.name}'),
                tooltip: award.title,
                color: colors.ink,
                icon: const Icon(Icons.info_outline),
                onPressed: () => _explain(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The award's explanation (DESIGN section 4): its name and the one line that
/// says who wins it, in a small card over the screen. A tap outside it, Escape
/// or its own button closes it, so it never traps a player mid-screen.
///
/// Every award's explanation is the same [awardExplanationWidthPx] by
/// [awardExplanationHeightPx] box in a look (B-033): the award's own line
/// decides what it says, never how big it is. The card is given that size rather
/// than growing to its text, and its body scrolls only if a longer line one day
/// needs more than the height has.
class _AwardExplanation extends StatelessWidget {
  const _AwardExplanation({required this.award});

  final NightAward award;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    return Center(
      child: SizedBox(
        width: awardExplanationWidthPx,
        height: awardExplanationHeightPx(look),
        child: ToyCard(
          key: const Key('awardExplanation'),
          header: award.title,
          padding: const EdgeInsets.all(ToySizes.space24),
          popIn: false,
          scrollBody: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(award.line, style: ToyType.frame.body.copyWith(color: colors.ink)),
              const SizedBox(height: ToySizes.space24),
              HostButton(
                key: const Key('awardExplanationClose'),
                label: HostText.ok,
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
