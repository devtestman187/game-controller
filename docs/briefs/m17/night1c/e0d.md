job: night1c e0d — players 7 and 8 get a ring on their badge (6 colours kept)
stop: no protocol change, no character.dart change (lastSlot stays 6, protocolVersion stays 1), no 7th colour, no change to the phone app; host badges only; no change to the 20 px number floor
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/ui/player_badge.dart:1-71 (PlayerBadge) · packages/party_host/test/player_badge_test.dart:1-60 · packages/party_host/test/support/all_looks.dart (forEachLook, pumpHostLook) · packages/protocol/lib/src/character.dart:12-40 (forPlayer wraps past the sixth colour) · plan, quoted (city-rush-plan e0d): "Players 7-8: number badge, accessory and outline, 6 colour slots kept" and "keep 6 slots in M17, use number badges, accessory and outline on the host"
changes: badgeNeedsRing · PlayerBadgeRing
probe: docs/briefs/m17/night1c/probe-e0d.patch
model: sonnet
turns: 60
expected-min: 30
touch-target: exempt a badge is not a touch target
tests-first: exempt the ring is new; the new test needs the new symbols, so it fails to compile on the base
do:
1 NEW packages/party_host/lib/src/ui/player_badge_ring.dart: `bool badgeNeedsRing(int number) => number > PlayerCharacter.lastSlot;` and `class PlayerBadgeRing extends StatelessWidget` ({required Widget child, required double size}) that draws, around a disc of `size * 0.88` centred in a `size` square, a ring in the look's ink colour (`ToyLookScope.of(context).colors.ink`, width `look.sizes.outlineWidth`) with a gap of paper colour between disc and ring; key `Key('playerBadgeRing')`.
2 player_badge.dart: in `PlayerBadge.build`, when `badgeNeedsRing(number)` wrap the ToyBadge in PlayerBadgeRing. The ring box is the badge's `_diameter` as today, but the inner disc must still hold the 20 px number floor inside the host frame: size the ring box as `max(diameter, badgeNumberMinDiameterPx / 0.88)` inside the frame so the disc never goes under badgeNumberMinDiameterPx. Players 1-6 draw exactly what they draw today (no ring, same widget tree).
3 Tests: NEW packages/party_host/test/player_badge_ring_test.dart, written and run first, under both looks (`forEachLook` or pumpHostLook with HostLook.menu and HostLook.tv): numbers 1-6 have no `playerBadgeRing`; 7 and 8 have it; the ToyBadge of number 7 still reports number 7 and a character, and its diameter is at least badgeNumberMinDiameterPx; the number text of 8 is at least 20 px in the frame (ToyBadge number share 0.55 of diameter); the ring box of 7 and 8 is square. Existing test/player_badge_test.dart must still pass.
4 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error. In packages/party_host run `flutter test test/player_badge_test.dart test/player_badge_ring_test.dart`.
allow: packages/party_host/lib/src/ui/player_badge_ring.dart · packages/party_host/lib/src/ui/player_badge.dart · packages/party_host/test/player_badge_ring_test.dart · packages/party_host/test/player_badge_test.dart
check: format analyze
report: docs/briefs/m17/night1c/e0d-report.md
