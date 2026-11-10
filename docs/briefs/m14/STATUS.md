# M14 Party night: status

Branch `m14`, worktree `E:\AI\game-controller-m14`, cut from `m13` at 77ccf09 on Nov 9, 2026, after M13's closing review R4 and its fixes. The plan is docs/PRD-v2.md "Milestone 14" (G1–G5, G9, C20, T15, results on joined phones, the Arena waits for its players).

## Resume here (Nov 9, 2026, evening)

Two things were still running when the session was compacted:
1. **The m13.4 release** (GitHub run 42738679821: Play, Windows, TestFlight). Check it with `tools/release.sh --status m13.4`. A failure: read the run's log and tell the owner; never promote to external testers.
2. **scan-m14-refresh** (flash job; log in the session scratchpad `flash-m14-scan.log`). Done when `docs/briefs/m14/scan-m14-refresh-report.md` exists in its job folder or here. If it is missing and no flash process runs, start it again: `tools/flash.sh --brief docs/briefs/m14/scan-m14-refresh.md` with Bash `run_in_background`.

Then, in order:
3. Review the scan report, append "Claude's review", commit.
4. Write the M14 design, `docs/design/party-night.md`, from docs/PRD-v2.md M14 (G1–G5, G9, C20, T15, results on joined phones, the Arena's waiting card), the research reports in this folder and the scan's "Suggested M14 order". Put open questions to the owner; the PRD is already approved, so no mock-up gate unless the design adds new screens worth showing.
5. The groundwork jobs: R4's carry-overs (the three puzzle rules into the rule book; the round music resuming where it was after an app hidden mid-round; `Level.hard`; the parser's casts), the Shape Race rules split, the empty-rounds stats bug, and `arena.dart` (487 lines) split before the Bumper Round.
6. The features, at most three flash jobs at once, batched by area. The Bumper Round job wires the a1 sounds (SoundKeys, CREDITS rows) and the Arena's own round music (`HostMusic`/`MusicLoop` with a second set of three files, and the Arena reporting its clock and end).

Housekeeping: one old job worktree, `E:\AI\game-controller-m13-jobs\flash-20261109-083539-456`, could not be removed (a file in use); try `git worktree remove --force` again later, from the m13 worktree.

## Where M14 stands

- **Done before the branch:** the party research (research-party-games, research-party-design), the touchpoints scan, the Arena research with the owner's pick (the Bumper Round, G9: "We should add some scoring to determine a winner after 60 seconds"), and the Arena's sounds and music (a1, owner: "Arena sounds are good"), all on `m13` and so here.
- **Running:** scan-m14-refresh, a read-only refresh of the touchpoints scan at HEAD with the Bumper Round added.
- **Next:** Claude writes the M14 design (docs/design/party-night.md) from the PRD, the research and the refreshed scan; then the groundwork jobs (R4's carry-overs, the Shape Race rules split, the empty-rounds stats bug), then the features, at most three jobs at a time.
- **M13:** closed. **`m13.4` tagged** on Nov 9 (owner: "Tag it"), on 2183739, version 0.13.0 build 345: Play (both apps), TestFlight internal and a GitHub Release. Not promoted to external testers (the owner decides). Fixes from device testing of M13 land on `m13` and are merged into `m14`.
