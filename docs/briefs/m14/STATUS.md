# M14 Party night: status

Branch `m14`, worktree `E:\AI\game-controller-m14`, cut from `m13` at 77ccf09 on Nov 9, 2026, after M13's closing review R4 and its fixes. The plan is docs/PRD-v2.md "Milestone 14" (G1–G5, G9, C20, T15, results on joined phones, the Arena waits for its players).

## Resume here (Nov 9, 2026, night)

The design is written: **docs/design/party-night.md** (decisions N1–N15, the jobs in four waves in its section 13, the owner's answers and open questions Q4–Q5 in section 12; Robo the CPU marble with three levels is job b3).

Done: **g2** (arena.dart split, 6f896af) and **g3** (empty rounds, the round music across a hidden app with Claude's fix for the phone host's engine restart, the Arena's keys, `RoundResult`; 43d02cb).

Running: **g1** (puzzle: split game.dart and puzzle_rules.dart, the three rules into `check`, `Level.hard`, the parser's casts) and **m1** (mock-ups: `docs/design/party-mockups.html` on shared parts in `mockup-parts.js`). Logs in the session scratchpad `flash-m14-g1.log`, `flash-m14-m1.log`. A job is done when its `docs/briefs/m14/<job>-report.md` exists here or in its job folder; if one is missing and no flash process runs, start it again with `tools/flash.sh --brief docs/briefs/m14/<brief>.md` (Bash `run_in_background`).

Device-test list (so far): hide a phone host mid-round and show it again: the round's music carries on from where it was (g3; SoLoud can't be unit-tested).

Then, in order:
1. Review g1 (tests, `tools/review.sh --base 79ce8fb`), append "Claude's review", commit.
2. Review m1; save each frame as a PNG (`party-mockups.html?frame=N&theme=sunny|night`) under docs/design/look-mockups/ with the prefix `m14-`, check `look-mockups.html` still draws M13's frames the same, send the PNGs to the owner. The screen jobs (c1, b2, c2, c3) wait for the OK.
3. After g1: a1 points (G1) and k1 the level kit (G10, design section 7b; its brief must leave `arena_field.dart`, now 391 lines, under 300). The Arena lane runs k1 → b1 → k2 (the four maps) → b2 → b3 (Robo).
3. Waves 3 and 4 as the design's section 13 says, then the full review R5 and device tests. A build only on the owner's word.

Housekeeping: one old job worktree, `E:\AI\game-controller-m13-jobs\flash-20261109-083539-456`, could not be removed (a file in use); try `git worktree remove --force` again later, from the m13 worktree.

## Where M14 stands

- **Done before the branch:** the party research (research-party-games, research-party-design), the touchpoints scan, the Arena research with the owner's pick (the Bumper Round, G9: "We should add some scoring to determine a winner after 60 seconds"), and the Arena's sounds and music (a1, owner: "Arena sounds are good"), all on `m13` and so here.
- **Done on the branch:** the refreshed scan (scan-m14-refresh, with Claude's review, a90df03) and the design (docs/design/party-night.md, 7627ca8).
- **Running:** the groundwork jobs g1–g3 (wave 1).
- **Next:** wave 2 (points, the Bumper Round's rules, the mock-ups), then waves 3 and 4, at most three jobs at a time.
- **M13:** closed. **`m13.4` tagged** on Nov 9 (owner: "Tag it"), on 2183739, version 0.13.0 build 345: every build succeeded (Play both apps, Windows, TestFlight internal) and the GitHub Release is up. Not promoted to external testers (the owner decides). Fixes from device testing of M13 land on `m13` and are merged into `m14`.
