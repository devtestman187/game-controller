job: M14 b1: the Bumper Round's rules (G9): contacts, coins in the map's zones, the 60 s clock, most coins wins, snapshot v2 with the map id, sound names on events, RoundResult
pub: no
stop: after it.
read: docs/PRD-v2.md G9 · docs/design/party-night.md sections 2, 7 ("How a coin looks"), 7b, 11 · docs/design/party-mockups.html and mockup-parts.js (the coin, the Bumper frames) and their PNGs in docs/design/look-mockups/m14-* · docs/briefs/m14/k1b-arena-maps-kit-report.md (ArenaMap, bumper starts and coin zones, MapGrid.spotsIn, the 300-byte coin reserve) · packages/test_game/lib/src (arena*.dart, map*.dart) · packages/game_kit/lib/src/round_result.dart and the GameEvent type · docs/protocol.md (the arena snapshot) · docs/coding-guidelines.md · docs/review-rules.md
decide: low-usage mode (owner, Nov 10, 2026): never stop for a question. Where the brief or design leaves a choice, make the safest one that fits docs/design/party-night.md, the approved mock-ups and docs/coding-guidelines.md, and list each under "Decisions" in the report with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

Claude's design (section 7 is the source; this is how to build it):
1. A round **mode**: `race` (today) or `bumper`. `ArenaGame` takes a map and a mode; the default stays race on the Playroom, so every existing test passes. The waiting card picks the mode in job b2.
2. **Bumper rules**: four marbles from the map's bumper starts; marble-to-marble contacts push both (no knock-out); hazards send a marble back to its start as the race does. **Coins** appear in the map's coin zones (spots from `MapGrid.spotsIn`), a few at a time, a new one when one is taken; touching one scores +1. A **60 s clock**; at time-up most coins wins, a tie is a draw (shared win). A coin is drawn as the approved spinning stamped coin, never like a bumper or a hazard (mockup-parts.js `coin`); with effects off it does not spin.
3. **Snapshot version 2** names the map id (phones draw the static map from their own copy) and carries coins, scores and the clock; it replaces k1b's 300-byte coin reserve with real coins and keeps the 2048-byte budget with four marbles; docs/protocol.md lists it.
4. **Events**: `GameEvent` gains a sound name (coin, bump, time-up) so hosts play sounds by name; the Arena sound keys exist since g3.
5. **RoundResult**: each player's coins as points, the winners (or the draw), and the counters the awards need (coins, bumps given) in `stats`.

tests (each failing first): contacts push both marbles; a coin taken scores +1 and a new one appears in a zone; coins only in zones, never on walls; the clock ends the round at 60 s and stands still when the round does; most coins wins and a tie is a draw; the snapshot round-trips with the map id, coins and scores and stays under budget with four marbles; events carry sound names; the RoundResult values; a race on the Playroom plays exactly as before. All existing tests pass (arena, kit, host, tv, phone).

in the report: the rules as built with numbers (coins out at once, spawn, speeds), a sample snapshot, sizes, test counts before and after.

self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · leave no scratch file behind · touch nothing outside allow: (the job is refused otherwise)
allow: docs/briefs/m14/b1-bumper-rules-report.md · docs/protocol.md · packages/test_game · packages/game_kit/lib · packages/game_kit/test
check: format analyze arena kit host tv phone
report: docs/briefs/m14/b1-bumper-rules-report.md
