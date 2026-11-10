# M14 Party night: status

Branch `m14`, worktree `E:\AI\game-controller-m14`, cut from `m13` at 77ccf09 on Nov 9, 2026, after M13's closing review R4 and its fixes. The plan is docs/PRD-v2.md "Milestone 14" (G1–G5, G9, C20, T15, results on joined phones, the Arena waits for its players).

## Resume here (Nov 9, 2026, 22:50: paused on the owner's word)

The owner, low on usage: "once the current tasks complete, stop work and save your state ... I will tell you when to restart." **Start nothing until the owner says restart.**

**The plan**: docs/design/party-night.md (decisions N1–N15; job order in section 13; the owner's answers in section 12). **Mock-ups approved** (Nov 9: "Mockups look good."): docs/design/look-mockups/m14-*.png, drawn by docs/design/party-mockups.html (+ mockup-parts.js, mockup-maps.js).

**Done and pushed**: g1 + g1b, g2, g3, k1a, a1, m1/m1b/m1c, **c1** the party night (595eb74; Claude's fix: Back on a night's results records the round), **k1b** the maps in the kit (218fcc1; Claude: gap floor 1.6 marbles between faces, new maps aim for 2.5; the size rule's message test waits for k2a).

**a2 (the cat + Chaos) was still running at the pause**: log `flash-m14-a2.log` in the session scratchpad, job folder `E:\AI\game-controller-m14-jobslash-20261109-215355-31972`. On restart: if `docs/briefs/m14/a2-cat-report.md` is in this tree (result 0 applies it here, uncommitted) review it; if it is only in the job folder (result 4) apply by hand without the out-of-allow files; if neither and no flash process runs, start it again with `tools/flash.sh --brief docs/briefs/m14/a2-cat.md` (Bash `run_in_background`). Then run the gate (`tools/check.sh format analyze puzzle host phone tv`), append "Claude's review", commit, push.

**Next, in order** (at most three jobs at once):
1. Connect c1's `NightChaos` (packages/party_host/lib/src/night/party_night.dart) to a2's `PuzzleSettings.chaos`: `catVisitsTonight` reads the host's setting, `settingsForRound` sets Chaos off in the last round; test-first, by hand.
2. **b1** the Bumper Round's rules (k1b is in): contacts, coins in the map's zones with the spinning-coin look, 60 s clock, snapshot v2 with the map id, `GameEvent` sound names, `RoundResult` with winners/draw; it replaces k1b's 300-byte coin reserve with real coins.
3. **s1** the new sounds (meow, points, fanfare, celebration, new_record).
4. **c3** the phone (nicknames, colour + accessory choice unique per game, results on joined phones via `view_end.result`, a phone's own results in a night get Next) and **a3** the finish celebration (section 3a).
5. k2a (map pieces; turns on the size rule's message test) → k2b (the four maps, renders to the owner for review) → b2 (Arena screens; flips `nightBumperRoundReady`) → c2 (awards reveal at the place `night_scoreboard_screen.dart` marks, best times) → b3 (Robo, steering with `MapGrid`).
6. Review R5, the comfort check (G5), device tests, a build only on the owner's word.

**Mock-up pictures**: saved with headless Chrome: `"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --no-first-run --user-data-dir=<scratch>/prof --virtual-time-budget=8000 --hide-scrollbars --window-size=1280,720 --screenshot=<file> "file:///<cygpath -m page>?frame=N&theme=sunny|night"` (phone frames 816,384). Console errors: add `--enable-logging --v=0` and read `<profile>/chrome_debug.log`. Chrome writes nothing to stdout, so `--dump-dom` doesn't work here.

**Device-test list (so far)**: hide a phone host mid-round and show it again: the round's music carries on from where it was (g3; SoLoud can't be unit-tested).

Housekeeping: one old job worktree, `E:\AI\game-controller-m13-jobs\flash-20261109-083539-456`, could not be removed (a file in use); try `git worktree remove --force` again later, from the m13 worktree.

## Where M14 stands

- **Done before the branch:** the party research (research-party-games, research-party-design), the touchpoints scan, the Arena research with the owner's pick (the Bumper Round, G9: "We should add some scoring to determine a winner after 60 seconds"), and the Arena's sounds and music (a1, owner: "Arena sounds are good"), all on `m13` and so here.
- **Done on the branch:** the refreshed scan (scan-m14-refresh, with Claude's review, a90df03) and the design (docs/design/party-night.md, 7627ca8).
- **Running:** see "Resume here".
- **Next:** wave 2 (points, the Bumper Round's rules, the mock-ups), then waves 3 and 4, at most three jobs at a time.
- **M13:** closed. **`m13.4` tagged** on Nov 9 (owner: "Tag it"), on 2183739, version 0.13.0 build 345: every build succeeded (Play both apps, Windows, TestFlight internal) and the GitHub Release is up. Not promoted to external testers (the owner decides). Fixes from device testing of M13 land on `m13` and are merged into `m14`.
