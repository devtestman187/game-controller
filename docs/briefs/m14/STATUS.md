# M14 Party night: status

Branch `m14`, worktree `E:\AI\game-controller-m14`, cut from `m13` at 77ccf09 on Nov 9, 2026, after M13's closing review R4 and its fixes. The plan is docs/PRD-v2.md "Milestone 14" (G1–G5, G9, C20, T15, results on joined phones, the Arena waits for its players).

## Resume here (Nov 9, 2026, late night, before a compaction)

**The plan**: docs/design/party-night.md (decisions N1–N15; job order in section 13; the owner's answers in section 12). **Mock-ups approved** (owner, Nov 9: "Mockups look good."): docs/design/look-mockups/m14-*.png, 22 frames in Sunny and Night, drawn by docs/design/party-mockups.html (+ mockup-parts.js, mockup-maps.js). They are the target for every new screen.

**Done and pushed**: g1 + Claude's g1b (Shape Race split, all puzzle rules in `check`), g2 (arena.dart split), g3 (empty rounds, hidden-app music incl. Claude's phone-host restart fix, Arena SoundKeys, `RoundResult`), k1a (one level kit: `tools/level.sh`, docs/levels.md, `LevelIssue` in game_kit), a1 (points, snapshot v2, `MatchResult.round`), m1/m1b/m1c (mock-ups).

**Running when compacted** (Bash background, logs in the session scratchpad `flash-m14-<job>.log`; k1b's second run logs to `flash-m14-k1b2.log`):
- **a2** the cat + Chaos setting + a1's Q1–Q3 (phone host's panel points line, a board's `sd` side key, `pointsScale`/`night` in `ranges`);
- **c1** the party night (Party night card, start card, scoreboard, double banner, final scores; Bumper button disabled behind one flag until b2);
- **k1b** the Arena's maps in the kit (second run; Claude answered: the gap rule is about routes, the goal rule covers only the part a marble must reach, `puzzle_new_test.dart` may change).
A job is done when `docs/briefs/m14/<job>-report.md` exists here or in its job folder (`E:\AI\game-controller-m14-jobslash-*`). If one is missing and no flash process runs, start it again with `tools/flash.sh --brief docs/briefs/m14/<brief>.md` (Bash `run_in_background`). Result 4: apply by hand from the job folder without the out-of-allow files, then `git worktree remove --force` it.

**When they land** (review each, append "Claude's review", commit, push):
1. After **a2 and c1** both land: connect c1's Chaos function to a2's `PuzzleSettings.chaos` (off in a night's last round; the start card's cat line only when Chaos isn't off), test-first, by hand.
2. After **k1b**: **b1** the Bumper Round's rules (contacts, coins in the map's zones with the spinning-coin look, 60 s clock, snapshot v2 with the map id, `GameEvent` sound names, `RoundResult` with winners/draw).
3. **s1** the new sounds (meow, points, fanfare, celebration, new_record), any time a slot is free.
4. After c1: **c3** the phone (nicknames, colour + accessory choice unique per game, results card on joined phones via `view_end.result`) and **a3** the finish celebration (section 3a; touches `puzzle_screen.dart` after c1).
5. Then k2a (map pieces: springs, bouncy walls, posts, movers, belts, still hazards, themes/decor, snapshot names the map) → k2b (the four maps, renders to the owner) → b2 (Arena screens: waiting card with modes, maps, Robo's levels; ready beat on TV; results; music clock; turn on the night's Bumper button) → c2 (awards reveal with qualifiers, best times) → b3 (Robo).
6. Then the full review R5 (worker first, Claude verifies), the comfort check (G5), device tests, and a build only on the owner's word.

**Mock-up pictures**: saved with headless Chrome: `"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --no-first-run --user-data-dir=<scratch>/prof --virtual-time-budget=8000 --hide-scrollbars --window-size=1280,720 --screenshot=<file> "file:///<cygpath -m page>?frame=N&theme=sunny|night"` (phone frames 816,384). Console errors: add `--enable-logging --v=0` and read `<profile>/chrome_debug.log`. Chrome writes nothing to stdout, so `--dump-dom` doesn't work here.

**Device-test list (so far)**: hide a phone host mid-round and show it again: the round's music carries on from where it was (g3; SoLoud can't be unit-tested).

Housekeeping: one old job worktree, `E:\AI\game-controller-m13-jobs\flash-20261109-083539-456`, could not be removed (a file in use); try `git worktree remove --force` again later, from the m13 worktree.

## Where M14 stands

- **Done before the branch:** the party research (research-party-games, research-party-design), the touchpoints scan, the Arena research with the owner's pick (the Bumper Round, G9: "We should add some scoring to determine a winner after 60 seconds"), and the Arena's sounds and music (a1, owner: "Arena sounds are good"), all on `m13` and so here.
- **Done on the branch:** the refreshed scan (scan-m14-refresh, with Claude's review, a90df03) and the design (docs/design/party-night.md, 7627ca8).
- **Running:** see "Resume here".
- **Next:** wave 2 (points, the Bumper Round's rules, the mock-ups), then waves 3 and 4, at most three jobs at a time.
- **M13:** closed. **`m13.4` tagged** on Nov 9 (owner: "Tag it"), on 2183739, version 0.13.0 build 345: every build succeeded (Play both apps, Windows, TestFlight internal) and the GitHub Release is up. Not promoted to external testers (the owner decides). Fixes from device testing of M13 land on `m13` and are merged into `m14`.
