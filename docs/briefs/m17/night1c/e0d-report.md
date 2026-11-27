## Summary

Players 7 and 8 now get a ring on the host badge; players 1-6 draw the same tree as before. `tools/mine.sh`: OK, 13 tests in packages/party_host, format and analyze clean.

- NEW `player_badge_ring.dart`: `badgeNeedsRing(number)` (number > `PlayerCharacter.lastSlot`), `badgeRingDiscShare` (0.88), `PlayerBadgeRing` (key `playerBadgeRing`, paper-filled circle with ink outline, disc at 0.88 centred).
- `player_badge.dart`: ringed path wraps the ToyBadge. Ring box is `size`, or `max(size, 37 / 0.88)` in the frame, so the disc is at least `badgeNumberMinDiameterPx` (37, number 20.35 px).
- NEW `player_badge_ring_test.dart`: 4 tests, each under menu and TV look.

Computed values: 37 / 0.88 = 42.045 ring box; disc 42.045 * 0.88 = 37 (float slack 1e-9 in tests); 37 * 0.55 = 20.35 >= 20.

## Decisions
- `PlayerBadgeRing` is not exported from party_host.dart (not in allow:); the test imports the src path. Callers use it via PlayerBadge.
- The ring file's `key` defaults to `Key('playerBadgeRing')` as the brief asks.
- Outside the frame the ring box is `size` and the disc 0.88 of it (the brief's floor applies only in the frame).

## Self-check
1. Host setups: PlayerBadge is the same widget on all hosts; tests pump `framed: true` (host frame) in both looks. Phone and older-peer setups unaffected (no protocol change).
2. No kept state.
3. Pause, away, results etc. unchanged: a stateless widget swap.
4. Stayed inside allow:.
5. No stop needed.
6. Menu and TV look: all 4 tests run both via `forEachLook`; no fixed pixel height (box from size).

## Hand-over
Colour slot 7 and 8 still repeat colours 1 and 2; the ring is the only difference. Export of `PlayerBadgeRing` from party_host.dart left out (file not allowed).

## Commit message

m17 e0d: ring on host badges of players 7 and 8

Players 7 and 8 repeat colours 1 and 2 (six slots kept), so the host
badge now draws an ink ring with a paper gap around the disc.
The ring box grows in the frame so the disc keeps the 20 px number floor.
Players 1-6 draw the same tree as before. No protocol change.

## Status row

e0d: host badges of players 7 and 8 get a ring (6 colours kept); open: device check of the look on a TV.

## Delete

- none
