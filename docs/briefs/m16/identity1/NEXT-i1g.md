# identity1 wave 3 (i1g): handoff for the next session (Nov 22, 2026)

State: branch m16, tip after this note's commit; nothing pushed since 56259780 (push/tag/build only on the owner's word). Waves 1, 1b, 2 committed (wave 2 tip a96407e9). process4 shipped and rehearsed (b7048a7b..885cb157; REHEARSAL-RESULT.md all PASS; full check.sh and check.sh tools pass). Rules: docs/flash-lessons.md (promoted P1-P3 in 9a1b6d8b). Weekly usage 64% at handoff.

## Owner decisions (Nov 22)
1. thumb-wait and thumb-haiku copied to C:/Users/mrman/.claude/agents/ (repo files are the source; re-copy after edits). They load in sessions started after the copy.
2. `.patch` exception: `tools/tests/fixtures/**` and `docs/briefs/**/probe-*.patch` are committed on purpose (thumb-batch.md Never line). Stray patches elsewhere stay unstaged.
3. i1g mechanism (main session's call, owner agreed): TV draws characters from the host's players (as arena_view.dart:147 does). Phone viewers get an OPTIONAL `ViewContext.characters` (player id or number → PlayerCharacter) in game_kit/lib/src/game_module.dart:69, filled where ViewContext is built (providers.dart:153). Missing entry → the number's default (Robo, no pick, old hosts). Do NOT add a character to the PlayerView snapshot (puzzle snapshot.dart:38; the game core has no characters, and it would need codec p[4] + lerp). Mind PlayerView is keyed by number, not id. Analysis: i1g-design notes in this note's "Evidence" below.
4. Small tools changes (approved; do as one tools job or hand edits, not inside i1g): apply-job.sh exits with its own code (not 1) when nothing applies; a job whose only outside-allow files are known churn (tools/churn.sh list) is churn-restored and applied with a log line instead of parked.
5. Haiku-direct trial: i1g is split contract-first.
   - i1g1 (contract, wave A): ViewContext.characters + its fill + Arena phone path stops using number defaults (arena_module.dart:48-51) + tests. Runs HAIKU-DIRECT, not through flash.
   - i1g2 (painters, wave B): every game painter still on forPlayer(n)/colors.player(row.number) draws the chosen character (PLAN.md:24 worker_painter.dart:82, PLAN.md:25 score_row.dart:259, Cat Chaos path PLAN.md:42), one non-default-character test per game. Runs on flash through the runner as usual.

## Haiku-direct procedure (i1g1)
- Rewrite i1g.md into i1g1.md / i1g2.md (`changes:` one bare symbol per item, `probe:` stub for ViewContext.characters, allow traced per flash-lessons rules 1-9). Run brief-check.sh and probe-deps.sh (via a Haiku helper) until clean; dry-run; commit briefs.
- Driver starts a Haiku agent (Agent tool, model haiku, isolation worktree, background) with: the brief path, docs/briefs/templates/COMMON.md, "edit only allow: files; run tools/mine.sh after each change; report changed files + test result in ≤15 lines". Driver stops it (TaskStop) past ~45 min.
- After: in the job's worktree run tools/mine.sh; bring the diff over with tools/apply-job.sh-style allow enforcement (or apply-job.sh if it accepts the worktree), tools/review.sh, the job's tests; commit as devtestman187 with a run.log line `HAIKU-DIRECT i1g1: <turns/min if known>, files`. Repairs: resume the SAME Haiku agent (SendMessage) with the failing output; max 2.
- Then i1g2 through the runner on flash (contract is now in the base).
- Measure for the owner: per job minutes, repairs, review findings, code quality notes; driver calls, Haiku calls/tokens (the agent's usage line), weekly usage before/after each job (main session runs get_usage). Write docs/briefs/m16/identity1/HAIKU-TRIAL.md.
- Stop after wave 3 and report. No push/tag/build.

## Evidence (from the i1g design check)
- Plan: i1g.md decisions "Identity shows everywhere players are drawn ... incl. Shape Race ... per-game test"; PRD-v2.md:869; ux-review/PROPOSAL.md:61-63.
- Data already flows: frame `chars` (protocol/lib/src/view.dart:116-153), GamePlayer.character (test_game/lib/src/arena_roster.dart:26), NightPlayer.character nullable (night_state.dart:23), round_results.dart:40 defaults only when missing.
- Old i1g.md contradicts itself (`changes: PlayerView.character` vs step 2 "from the frame's chars / roster"); probe-i1g.patch is the wrong stub: replace it.

## Open owner questions (from wave 2, still open)
- Blank nickname: the real hello sends "Phone AB12", so "Player N" never shows on the real path: hello sends no name, or display translates it?
- Phone's own host mode (controller_app/lib/src/storage.dart:55) lists no identity.
- Results band uses the winner's chosen colour (no brief asked): keep or revert?
