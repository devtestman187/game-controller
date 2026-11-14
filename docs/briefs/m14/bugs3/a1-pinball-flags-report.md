## Summary

**B-007 (Block Castle's bottom flags) — fixed.** Scenery was drawn before the walls, so a flag at a wall lost its
pole and cloth under the wall's fill: Block Castle's two bottom flags stand at the foot of the vertical walls at
x=0.15 and x=0.85, which covered their whole poles (the top flags start just above their walls, so they read).
Flags are now drawn after the walls; no other map has one.
- `packages/test_game/lib/src/arena_piece_painter.dart`: flags skipped in `pieces()`; new `pennants()` draws them.
- `packages/test_game/lib/src/arena_painter.dart`: `paint()` calls `pieces.pennants(...)` right after `_walls`.
- `packages/test_game/test/map_flags_test.dart` (new): paints every map and checks each flag's pole is the ink.
  On the old code Block Castle's (0.15, 0.79) flag sampled (48, 130) as 0x2c285a, the wall, 20 off the ink
  0x1e1646 (limit 8), so it fails; all four pass now.

**B-004 (Pinball stage no music) — not reproduced; one engine hardening.** Music is chosen by the mode, never
the map (`HostMusic`; no per-map table); Pinball's Bumper Round starts and keeps `arena` from the card and from a
night; `arena*.ogg` are present and valid. New tests pin the Arena's piece on all five kit maps (they pass on the
old code too, since the bug does not reproduce). The one device-only cause that fits the busiest map: SoLoud
steals the oldest voice when its 16 are full, the music is the oldest, and a stolen loop never restarts.
- `packages/party_host/lib/src/sound_loop.dart`: the loop's voice is protected, so effects are stolen first. Not
  unit-testable: the tests' `FakeSoundPlayer` sits above SoLoud, which needs a device.
- `packages/party_host/test/round_music_test.dart`: one test per kit map, that its Bumper Round plays `arena`.
  These 16 lines are **not in this job's commit**: they landed in i1's commit `c4e4e00`, whose report does not
  mention them. So no commit in the run matches this line, and B-004's tests belong to i1's commit (corrected
  here rather than moved, as the run's review asks).

**Decisions:** draw flags after the walls instead of moving map data (the walls are the map's look and play);
flags before movers and hazards (those must still read over them); sample the pole 0.75 of the piece's size above
the foot (below the cloth, above a flag-on-post's top); protect the loop's voice rather than raise the budget
(fixes the music only, leaves other voices alone).
**Not done:** B-004 is unreproduced, so its fix is a hypothesis needing a device; no other map has flags.
**On a device:** a four-player Pinball Bumper Round for a minute, listening for the music going quiet; then Block
Castle's two bottom corners (poles and cloth whole, in front of walls and posts).

## Self-check (review-rules part A)

1. **Every host setup** — drawing only: the TV host draws the field, joined phones get frames from the host and draw
   the same picture from `ArenaPainter`; the music change is in the host's own player. The arena + phone suites pass.
2. **Kept state** — the loop's voice protection lives and dies with the voice: it is set when the loop starts and
   the handle is dropped on `stop`/`reset`/engine restart, when the voice is gone anyway. `round_music_test.dart`
   covers start, tempo change, stop and pause.
3. **New state with the others** — no new state: the drawing order changes nothing that pauses, waits or blocks;
   the sound change is one flag on the loop's voice, and the music's pause/stop/fade paths are untouched and tested.
4. **In the job's folder** — all edits are in `packages/test_game`, `packages/party_host` and this report.
5. **Stop rather than overstep** — nothing outside `allow:` was needed; B-004 is reported as unreproduced instead of
   guessed at further than the one engine hardening.

**Checks** (the brief's `check: format analyze arena host phone tv`, all six pass; re-run on the bugs3 tree, since
this report gave only "the arena + phone suites pass"): `format` pass · `analyze` pass · `arena` pass · `host` pass ·
`phone` pass · `tv` pass.

## Commit message

Block Castle's flags draw over the walls, and the music keeps its voice

B-007: the maps' decor was drawn before the walls, so Block Castle's two bottom
flags lost their poles and cloth under the vertical walls at their feet. The
flags are now drawn after the walls and posts (ArenaPiecePainter.pennants), and
a new test paints every map and checks each flag's pole is ink, which failed on
the old code.
B-004: the round's music is chosen by the mode, never the map, and Pinball's
Bumper Round starts the Arena's piece in tests. As the one device-only cause
that fits, the loop's SoLoud voice is protected so a busy map's effects cannot
steal the music; five tests pin the Arena's piece on every kit map.

## Status row

B-007 fixed (flags drawn over walls, tested on every map); B-004 not reproduced (music is per mode; loop voice protected, device check open).

## Delete

- packages/party_host/test/zz_scratch_test.dart
- packages/test_game/test/zz_scratch_test.dart
- packages/test_game/build/scratch-castle.png
- packages/test_game/build/scratch_bytes.dart
