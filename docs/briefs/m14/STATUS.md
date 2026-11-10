# M14 Party night: status

Branch `m14`, worktree `E:\AI\game-controller-m14`, cut from `m13` at 77ccf09 on Nov 9, 2026, after M13's closing review R4 and its fixes. The plan is docs/PRD-v2.md "Milestone 14" (G1–G5, G9, C20, T15, results on joined phones, the Arena waits for its players).

## Resume here (Nov 9, 2026, night)

The design is written: **docs/design/party-night.md** (decisions N1–N15, the jobs in four waves in its section 13, the owner's answers and open questions Q4–Q5 in section 12; Robo the CPU marble with three levels is job b3).

Done: **g1** (493e359) and Claude's **g1b** (the turned and phone-size rules in `check`, cb5915a), **g2** (6f896af), **g3** (43d02cb).

Owner's review of the mock-ups (Nov 9): the coin needs its own look and a spin; the four maps rethought as Bumper Round arenas that look like their names, with no finish; colour and accessory choice joins M14 (L7, in c3). All in the design (sections 7, 7b, 9); **m1c** redrew them (ab04218, 22 frames), sent to the owner Nov 9. **Approved** (owner, Nov 9: "Mockups look good."). Earlier: (m1 59b381e, m1b 1455bbb: 17 frames in Sunny and Night, docs/design/look-mockups/m14-*.png, sent Nov 9). The screen jobs (c1, b2, c2, c3, a3) wait for the OK.

Done since: **k1a** the level kit's shared core (8339db3: `tools/level.sh`, docs/levels.md, `LevelIssue` in game_kit).

Done since: **a1** points (37d366d; its Q1–Q3 go to a2: the phone host's panel points line, a board's side key, `pointsScale`/`night` in `ranges`).

Running: **a2** the cat (plus a1's Q1–Q3), **c1** the night (its Chaos touches sit behind one function Claude connects to a2's setting when both land), **k1b** (second run, after Claude answered its three questions) the Arena's maps in the kit (`playroom.json`, the map rules, `MapGrid`). Logs in the session scratchpad `flash-m14-<job>.log`. A job is done when its `docs/briefs/m14/<job>-report.md` exists here or in its job folder; if one is missing and no flash process runs, start it again with `tools/flash.sh --brief docs/briefs/m14/<brief>.md` (Bash `run_in_background`).

Device-test list (so far): hide a phone host mid-round and show it again: the round's music carries on from where it was (g3; SoLoud can't be unit-tested).

Then, in order:
1. Review each job as it lands, append "Claude's review", commit.
2. After m1b: save each of the 17 frames as a PNG with headless Chrome (`chrome --headless=new --screenshot=<file> --window-size=1280,720` or 816,384 for the phone frames, `party-mockups.html?frame=N&theme=sunny|night`; paths via `cygpath -m`) under docs/design/look-mockups/ as `m14-<theme>-NN-<name>.png`, re-check M13's 22 frames are byte-identical, look at every frame, commit, send to the owner. The screen jobs (c1, b2, c2, c3) wait for the OK.
3. After k1b: b1 (the Bumper Round's rules). After a1: a2 (the cat). Then b1, c1 and the rest as the design's section 13 says.
4. The finish celebration (owner, Nov 9) is design section 3a and job a3, after a1 and c1.
5. Avatars: answered, colour and accessory both, in M14 (L7, job c3).

Housekeeping: one old job worktree, `E:\AI\game-controller-m13-jobs\flash-20261109-083539-456`, could not be removed (a file in use); try `git worktree remove --force` again later, from the m13 worktree.

## Where M14 stands

- **Done before the branch:** the party research (research-party-games, research-party-design), the touchpoints scan, the Arena research with the owner's pick (the Bumper Round, G9: "We should add some scoring to determine a winner after 60 seconds"), and the Arena's sounds and music (a1, owner: "Arena sounds are good"), all on `m13` and so here.
- **Done on the branch:** the refreshed scan (scan-m14-refresh, with Claude's review, a90df03) and the design (docs/design/party-night.md, 7627ca8).
- **Running:** see "Resume here".
- **Next:** wave 2 (points, the Bumper Round's rules, the mock-ups), then waves 3 and 4, at most three jobs at a time.
- **M13:** closed. **`m13.4` tagged** on Nov 9 (owner: "Tag it"), on 2183739, version 0.13.0 build 345: every build succeeded (Play both apps, Windows, TestFlight internal) and the GitHub Release is up. Not promoted to external testers (the owner decides). Fixes from device testing of M13 land on `m13` and are merged into `m14`.
