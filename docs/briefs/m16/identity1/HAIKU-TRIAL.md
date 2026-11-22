# Haiku-direct trial (identity1 wave 3, Nov 22)

i1g1 (contract) ran as a Haiku agent coding directly; i1g2 (painters) ran on flash through the runner. Usage readings come from the main session (weekly all-models / 5-hour window): start 65/32, after briefs 65/36, after i1g1 66/38, after i1g2 67/46. Whole trial: +2 weekly.

## 1. Per job

| | Briefs (phase 1) | i1g1, Haiku-direct (phase 2) | i1g2, flash via runner (phase 3) |
|---|---|---|---|
| Minutes | 5.3 harness (about 20 wall by the driver's clock) | coder 5 (+1 failed first try); phase 16.8 | worker 23 (limit 40 x1.5); phase 68.8 |
| Turns / calls | 24 driver, 3 Haiku checkers (7 calls) | Haiku 34 calls (+11 in the failed try); helper 8 | worker 161 turns; driver about 18 |
| Repairs | 3 brief-check rounds (symbols too broad, allow gaps) | 0 repairs; 1 re-dispatch (wrong worktree base) | 1 hand-apply (result 4: churn PNGs and run.log outside allow), 1 runner restart for tests-first and review |
| Review findings | none (tools: 0 FAIL, 1 WARN) | 0 must, 2 should, 4 could | 1 must, 2 should, 2 could |
| Code quality | n/a | minimal lib diff (record field, one fill, one pass-through), 6 tests in both looks; weak spots: crown test compares renders only, duplicated test harness, self-check skipped review-rules, a wrong claim in the report | right design (characters by number, defaults as fallback), MatchView moved to keep view.dart under 380 (two public widgets in one file), split-board path untested, one test that proves nothing new |
| Gates | brief-check, probe-deps, dry-run ok | review 0 fail; kit 77, arena 252, puzzle 445 | review 0 fail; puzzle 449, host pass; tests-first ok |
| Driver calls / tokens | 28 / 120k | 37 / 136k | 53 / 164k |
| Waiter / helper calls | 3 agents, 7 calls | Haiku coder 34 calls, 120k tokens; checker 8 calls, 10k | thumb-wait 12+4+3, checker 2; each waiter 11-13k tokens |
| Usage delta (weekly / 5 h) | 0 / +4 | +1 / +2 | +1 / +8 |

## 2. Where the money went
Flash spends DeepSeek money, not plan usage. i1g2's +1 weekly is the driver plus the waiters and checkers only. i1g1's +1 weekly includes the Haiku coder (120k tokens) on top of the driver. So Haiku-direct is a plan-usage cost where flash is not; its saving would only be time. The 5-hour window moved most in phase 3 (+8) because the driver waited 68 minutes and re-read two reviews.

## 3. Guardrail gaps seen
- `isolation: worktree` cut the Haiku agent's tree from the frozen E:/AI/game-controller (no briefs, no tools/mine.sh), so it stopped blocked after 1 min and 11 calls. The fix was a worktree of branch m16 made by hand, with the agent told to work only there.
- i1g2 reached 161 turns while flash.sh passes `--max-turns ${FLASH_MAX_TURNS:-150}`. run.log shows only `finished: result 4 (161 turns, 23 min)`; the usage line counts 161 turns, so either the harness counts turns differently from the flag or the flag stops only at a message boundary. Not explained by the logs; the result was accepted only after a hand-apply because of result 4, not because of the turn count.
- thumb-wait reported STALLED after 20 minutes of a healthy job: the worker log and run.log are written only at the end of a job, so wait-run saw no movement. Spurious; the next wait found the log moving.
- The driver's context passed 100k in phases 2 and 3 (136k and 164k tokens by the harness). Resuming the same agent keeps its whole history, so each resume starts bigger.
- The runner counts a hand-committed job as "committed by hand" and reruns tests-first and review on restart unless done.txt names it; i1g1 had to be added to done.txt before the run or it would have run again.
- A brief's `changes:` symbols that are common words (`characters`, `forPlayer`, `PuzzlePainter`) flooded brief-check with 121 and then 15 FAILs; only rare symbols (`ViewContext`, `_paintWorkers`) worked.

## 4. Verdict on Haiku-direct for contract-sized jobs
Fit for a small contract job (one record field, one fill, a few tests): it finished in 5 minutes with no repairs and clean gates, but only after the worktree base was right.
It needs a reviewer on test strength and the report: it skipped review-rules, gave a false claim about toyTvProvider, and wrote a weak accessory test; and its plan-usage cost is real where flash's is not.
Use it for tiny contracts where the driver's review is cheap; keep painter-sized and multi-file jobs on flash.

## Proposed lessons (also in docs/flash-lessons.md)
See P1-P3 there.
