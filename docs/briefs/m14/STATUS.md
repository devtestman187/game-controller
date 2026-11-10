# M14 Party night: status

Branch `m14`, worktree `E:\AI\game-controller-m14`, cut from `m13` at 77ccf09 on Nov 9, 2026, after M13's closing review R4 and its fixes. The plan is docs/PRD-v2.md "Milestone 14" (G1–G5, G9, C20, T15, results on joined phones, the Arena waits for its players).

## Where M14 stands

- **Done before the branch:** the party research (research-party-games, research-party-design), the touchpoints scan, the Arena research with the owner's pick (the Bumper Round, G9: "We should add some scoring to determine a winner after 60 seconds"), and the Arena's sounds and music (a1, owner: "Arena sounds are good"), all on `m13` and so here.
- **Running:** scan-m14-refresh, a read-only refresh of the touchpoints scan at HEAD with the Bumper Round added.
- **Next:** Claude writes the M14 design (docs/design/party-night.md) from the PRD, the research and the refreshed scan; then the groundwork jobs (R4's carry-overs, the Shape Race rules split, the empty-rounds stats bug), then the features, at most three jobs at a time.
- **M13:** closed. `m13.4` is not tagged: the owner decides when (fast-forward main to `m13`, then `tools/release.sh m13.4`). Fixes from device testing of M13 land on `m13` and are merged into `m14`.
