# identity1 wave 4 (cleanup and close): handoff for the next session (Nov 22, 2026)

State: branch m16 in worktree E:/AI/game-controller-m16; nothing pushed since 56259780 (push, tag, build only on the owner's word). Waves 1, 1b, 2, 3 committed (wave 3 tip 060b66a8; Haiku trial HAIKU-TRIAL.md). rehearsal1 (first Claude-only wave) did fix groups C, E and the gating helper (2be1c198). process6 runner fix committed (1eacb71e: combined check skips the tools suite when no tools file changed, STOP.md names the failing suite and case, selftest.sh clears runner env such as WORKER, the cause of the rehearsal1 "passes alone" failure). Weekly usage 74% at handoff (resets Nov 27 11:00 UTC).

## How we work now (owner, Nov 22)
Claude-only model is the default: docs/design/claude-only-model.md, docs/flash-digest.md (WORKER=claude start line, escalation ladder), docs/flash-lessons.md (rules 1-21), .claude/agents/thumb-batch.md. Opus main session: owner questions, design calls, short checks only. Sonnet driver: briefs, runner, verdicts, repair notes; hands off at ~100k. Haiku: coders (about 8 files, 2 packages, turns 35, `read:` with line ranges), waits (thumb-wait), long mechanical steps (thumb-haiku). Flash is the fallback for bigger jobs or a tight plan limit.

Brief rule from process6 (Nov 23, propose as a lesson): a job that edits a runner or check script lists in `check:` every test that exercises that script (run-wire-test.sh, run-jobs-split-test.sh and the matching run-*-test.sh), not only its own new tests; p6a passed its own tests and broke run-wire-test and the run-steps.sh size gate.

## Owner answers already given (Nov 22, REVIEW.md "Owner answers")
Blank nickname = display rule (done in n1); phone host list left as is; results band keeps the winner's character colour; Shape Race mirror dots stay on player 2's colour.

## Ask the owner first (open, from REVIEW.md "Open questions" and fix group D)
1. Q2: a dropped player's pick stays reserved for the reserve minute (colour and accessory)? Suggested yes; needs the `nowMs` seam (i1c Q2).
2. Q4: local players (TV keyboard, host phone's own player) get a `players` row with `PlayerCharacter.forPlayer(number)`? Suggested yes, so the phone lobby matches the TV.
3. Q5: `players` keeps an away player while the round holds their slot? Suggested yes, same rows as the frame's `pl`.
4. Join-screen badge number (REVIEW.md should, connect_panels.dart:82, settings_profile_section.dart:246): a teal phone shows "4" before it is player 1. Draw the number the join will get, or no number until paired?
5. Q8: a value object for roster + characters in the painters (replaces the six-parameter painters)? Suggested yes.

## Wave 4 jobs (Haiku-sized; write briefs after the answers)
- F: six-parameter painters → value object (if Q8 yes), the frame shortcut (`arena_painter.dart`, `arena_marble_painter.dart`, `server_game_frames.dart`); check arena connection.
- G: the rest by file from REVIEW.md group G (`host_chip_test.dart`, `identity_host_test.dart`, `character.dart` cross-check); `host_connection.dart` split (at the 380 cap) in its own job.
- D: join-screen badge number per answer 4.
- Q2/Q4/Q5 jobs per the answers (host side: host_players_broadcast.dart, host_connection.dart reservation; contract-first if `players` rows change).
- Wave 3 leftovers (docs/code-health.md "i1g wave 3 leftovers"): MatchView to its own match_view.dart; a split-board MatchPainter non-default-character test; puzzle_screen_test.dart:177 Robo comment.
- Q10: rename phone_metrics_test's group name in the next phone job.
- Tools speed-up (owner approved Nov 22; its own tools batch, may run beside wave 4 as it shares no files): `check.sh tools` takes ~526 s because 24 scripts run in sequence and eight end-to-end runner tests take ~60% (run-wire-test 97 s; run-gate, wait-run, run-worker-switch, process3-fix1, run-limits-wire, run-wave, mine 29-41 s), on slow Git Bash process starts, with real sleeps and 60 s timeouts. Jobs: (a) make the timing-based tests tolerate load (shorter stub sleeps, waits on a condition instead of fixed sleeps, one shared fixture repo per script, split run-wire-test); (b) then `selftest.sh -j N` parallel runs (target about 2 min). Each job checks only its own tests; one `check.sh tools` at batch end, run twice to show no flake.
Then the milestone-end review of identity1 (review policy: worker review first, Claude verifies), STATUS.md "Resume here", and stop. Item 6 (awards) starts only on the owner's go.

## Device checks waiting for the owner (Fixed, unverified)
Blank nickname shows "Player N" in the phone lobby and result card; chosen characters on Shape Race workers, TV score bars and a joined phone's Arena; earlier waves' list in REVIEW.md.
