# M14 Party night: status

Branch `m14`, worktree `E:\AI\game-controller-m14`, cut from `m13` at 77ccf09 on Nov 9, 2026, after M13's closing review R4 and its fixes. The plan is docs/PRD-v2.md "Milestone 14" (G1–G5, G9, C20, T15, results on joined phones, the Arena waits for its players).

## Resume here (Nov 10, 2026: low-usage mode)

**Working mode: low-usage** (owner, Nov 10: write all remaining briefs at once, flash-worker decides safe things itself, Claude reviews once at the end, then one batch of fixes). Switch back to normal mode on the owner's word.

Done and pushed before the run: g1–g3, k1a, k1b, a1, m1–m1c, c1, **a2** (51adc35, committed after its checks, **not yet reviewed by Claude**: review it with the rest).

**The run**: `docs/briefs/m14/run-m14.sh` runs every remaining brief in waves (x1 b1 s1 → k2a c3 → k2b a3 → b2 → c2 → b3 → r5), runs `tools/check.sh` after each wave and commits each job with `tools/commit-job.sh --push`. Its progress is in `docs/briefs/m14/run-m14.log` (not committed), job logs in the session scratchpad. If it stopped, the log says why: fix that, then run it again (it skips committed jobs).

**At the end (Claude)**: read every report's "Decisions" and "Blocked", r5's review findings, the combined diff, render the new screens against the mock-ups, review a2; show the owner the four maps (docs/design/maps/*.png); write one fix brief with everything; run it; short final check; device tests; a build only on the owner's word.

**Mock-up pictures**: saved with headless Chrome: `"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --no-first-run --user-data-dir=<scratch>/prof --virtual-time-budget=8000 --hide-scrollbars --window-size=1280,720 --screenshot=<file> "file:///<cygpath -m page>?frame=N&theme=sunny|night"` (phone frames 816,384). Console errors: add `--enable-logging --v=0` and read `<profile>/chrome_debug.log`. Chrome writes nothing to stdout, so `--dump-dom` doesn't work here.

**Device-test list (so far)**: hide a phone host mid-round and show it again: the round's music carries on from where it was (g3; SoLoud can't be unit-tested).

Housekeeping: one old job worktree, `E:\AI\game-controller-m13-jobs\flash-20261109-083539-456`, could not be removed (a file in use); try `git worktree remove --force` again later, from the m13 worktree.

## Where M14 stands

- **Done before the branch:** the party research (research-party-games, research-party-design), the touchpoints scan, the Arena research with the owner's pick (the Bumper Round, G9: "We should add some scoring to determine a winner after 60 seconds"), and the Arena's sounds and music (a1, owner: "Arena sounds are good"), all on `m13` and so here.
- **Done on the branch:** the refreshed scan (scan-m14-refresh, with Claude's review, a90df03) and the design (docs/design/party-night.md, 7627ca8).
- **Running:** see "Resume here".
- **Next:** wave 2 (points, the Bumper Round's rules, the mock-ups), then waves 3 and 4, at most three jobs at a time.
- **M13:** closed. **`m13.4` tagged** on Nov 9 (owner: "Tag it"), on 2183739, version 0.13.0 build 345: every build succeeded (Play both apps, Windows, TestFlight internal) and the GitHub Release is up. Not promoted to external testers (the owner decides). Fixes from device testing of M13 land on `m13` and are merged into `m14`.
