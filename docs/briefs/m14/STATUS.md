# M14 Party night: status

Branch `m14`, worktree `E:\AI\game-controller-m14`, cut from `m13` at 77ccf09 on Nov 9, 2026, after M13's closing review R4 and its fixes. The plan is docs/PRD-v2.md "Milestone 14" (G1–G5, G9, C20, T15, results on joined phones, the Arena waits for its players).

## Resume here (Nov 9, 2026, night)

The design is written: **docs/design/party-night.md** (decisions N1–N15, the jobs in four waves in its section 13, the owner's answers and open questions Q4–Q5 in section 12; Robo the CPU marble with three levels is job b3).

Done: **g1** (493e359) and Claude's **g1b** (the turned and phone-size rules in `check`, cb5915a), **g2** (6f896af), **g3** (43d02cb).

Running: **m1** mock-ups (`docs/design/party-mockups.html`), **a1** points (G1, snapshot version 2, `MatchResult.round`), **k1a** the level kit's shared core (`tools/level.sh`, docs/levels.md). Logs in the session scratchpad `flash-m14-<job>.log`. A job is done when its `docs/briefs/m14/<job>-report.md` exists here or in its job folder; if one is missing and no flash process runs, start it again with `tools/flash.sh --brief docs/briefs/m14/<brief>.md` (Bash `run_in_background`).

Device-test list (so far): hide a phone host mid-round and show it again: the round's music carries on from where it was (g3; SoLoud can't be unit-tested).

Then, in order:
1. Review each job as it lands, append "Claude's review", commit.
2. m1: save each frame as a PNG (`party-mockups.html?frame=N&theme=sunny|night`) under docs/design/look-mockups/ with the prefix `m14-`, check `look-mockups.html` still draws M13's frames the same, send the PNGs to the owner. The screen jobs (c1, b2, c2, c3) wait for the OK.
3. After k1a: k1b (maps in the kit). After a1: a2 (the cat). Then b1, c1 and the rest as the design's section 13 says.
4. Open owner question: avatars (PRD L7, "Later") were raised on Nov 9; Claude recommended picking an accessory with the nickname in c3.

Housekeeping: one old job worktree, `E:\AI\game-controller-m13-jobs\flash-20261109-083539-456`, could not be removed (a file in use); try `git worktree remove --force` again later, from the m13 worktree.

## Where M14 stands

- **Done before the branch:** the party research (research-party-games, research-party-design), the touchpoints scan, the Arena research with the owner's pick (the Bumper Round, G9: "We should add some scoring to determine a winner after 60 seconds"), and the Arena's sounds and music (a1, owner: "Arena sounds are good"), all on `m13` and so here.
- **Done on the branch:** the refreshed scan (scan-m14-refresh, with Claude's review, a90df03) and the design (docs/design/party-night.md, 7627ca8).
- **Running:** see "Resume here".
- **Next:** wave 2 (points, the Bumper Round's rules, the mock-ups), then waves 3 and 4, at most three jobs at a time.
- **M13:** closed. **`m13.4` tagged** on Nov 9 (owner: "Tag it"), on 2183739, version 0.13.0 build 345: every build succeeded (Play both apps, Windows, TestFlight internal) and the GitHub Release is up. Not promoted to external testers (the owner decides). Fixes from device testing of M13 land on `m13` and are merged into `m14`.
