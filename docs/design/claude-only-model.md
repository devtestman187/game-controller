# Claude-only development model (proposal, Nov 22, 2026)

Status: agreed with the owner in chat on Nov 22; to be tried on the next round. Replaces the flash (DeepSeek) worker for batch work once the rehearsal in "Rollout" passes. Until then `tools/flash.sh` stays the working path. Evidence: [identity1 HAIKU-TRIAL.md](../briefs/m16/identity1/HAIKU-TRIAL.md).

## Goals (owner)
1. Opus-class cost only for architecture work.
2. Sonnet orchestrates; Haiku does the mechanical work and most code reading and writing.
3. Guardrails against runaway workers, as now.
4. Agents follow a brief and get a few attempts before a stronger agent helps unblock them.
5. Every Haiku session stays under 100k tokens: each turn re-sends the whole context, so cost climbs with session length.
6. Anything repetitive that needs no decision is a script, not an agent.

## What the trial showed (identity1 wave 3)
| | i1g1 Haiku-direct | i1g2 flash |
|---|---|---|
| Wall time | 5 min (+1 min failed first try) | 23 min + 9 min runner pass |
| Size | 34 calls, 120k tokens | 161 turns, past the 150 cap, parked |
| Repairs | 0 | 0 (hand-applied with apply-job.sh) |
| Review | 0 must / 2 should / 4 could | 1 must (minor) / 2 should / 2 could |
| Weekly usage | +1 point (driver + Haiku coder) | +1 point (driver + waiters; flash is DeepSeek spend) |

Lessons: Haiku writes correct small contract code fast, but skipped review-rules and made one false claim in its report, so it needs a reviewer. The Haiku session (120k) and the Sonnet driver (136k, 164k) both passed 100k. Resuming the same agent for a repair grows its context. The Agent tool's `isolation: worktree` cut from the frozen main repo, not m16. i1g2 passed `--max-turns 150` without being stopped (cause unknown; see Open items).

## Roles
| Tier | Does | Never |
|---|---|---|
| Opus (main session) | Architecture, owner decisions, contract design, milestone reviews, fixing a brief or decision when a job stops on design | Orchestration, polling, feature code |
| Sonnet (driver) | Wave plan and briefs, verdicts on review findings, diagnosing a stuck job, repair notes | Code beyond a ≤30-line hand-fix through `apply-job.sh` |
| Haiku coder | One job from a brief and a context pack | Decisions, commits, editing the brief |
| Haiku scout | Trims a context pack when it is over budget | Code |
| Haiku helper | Review-finding triage, long waits (thumb-wait) | Anything a ≤30-line script output already answers |
| Haiku release (thumb-release) | The release checklist: lib review by `git diff`, uncached check, release.sh, build watch (cost1, Nov 23) | Fixes, triage, repairs (those stay on Sonnet) |

Drivers read [driver-kit.md](../driver-kit.md) (about 5K tokens) instead of the digest, flash-lessons, the framework and dev-tools (cost1, Nov 23: driver contexts were 77-199K). Every batch report carries a `tools/agent-cost.sh --line` result.

Rule: an agent runs only where a decision is needed. A script whose output is at most about 30 lines is run by the driver directly, which is cheaper than starting a helper.

## The worker: `tools/claude-worker.sh`
`flash.sh` already runs `claude -p` headless with allowed/denied tools, `--max-turns`, `--output-format json`, output caps and a preflight, pointed at DeepSeek through `ANTHROPIC_BASE_URL`. The Haiku worker is the same script without the DeepSeek override:
- the model pinned to an exact Haiku ID (not the alias), changed on purpose and logged;
- the subscription login instead of `--bare`'s API key, while keeping `--bare`'s isolation (no user memory, hooks or MCP servers loaded into a worker; check how in the rehearsal);
- the same allow/deny lists: edits only in its worktree; no `git`, `rm`, `curl`, Agent or web tools;
- the runner keeps waves, STOP file, limits, apply-job, review gates and tests-first proofs unchanged.
The Agent-tool path (Sonnet starts Haiku directly) stays a fallback, always in a worktree made by `worktree.sh`, never `isolation: worktree`.

## Sizing every job under 100k tokens
- A job touches at most about 8 files in at most 2 packages; contract-first splits as now (flash-lessons rule 3).
- About 35 turns per attempt (the trial: about 3.5k tokens per Haiku turn).
- The runner reads the worker's streamed usage and stops an attempt at 85k, keeping its worktree.
- `brief-check.sh` estimates a brief's tokens (allow-list file sizes + read lines + context pack) and warns over 70k.
- Prompt caching: every session opens with the same text (COMMON.md, rules, brief template), the job-specific context pack last.

## Context pack before each coder
`tools/context-pack.sh <brief>` writes `<job>-pack.md`: the brief's `read:` line ranges, the grep hits for each `changes:` symbol (switches, constructors, pinning tests) and the allow files' signatures. A Haiku scout trims it only when it passes about 300 lines. The coder reads the pack, not the repo: exploration is where most coding tokens go.

## Escalation ladder (run by `tools/run-escalate.sh`, never by agents)
| Attempt | Who | Input |
|---|---|---|
| 1 | Haiku coder | brief + context pack |
| 2 | New Haiku session | diff so far + failing output (analyzer errors, a broken test) |
| 3 | Sonnet diagnoses, then a new Haiku session applies | ≤30-line evidence pack + diff → a repair note with file:line and what to change |
| 4 | Sonnet | ≤30-line hand-fix through apply-job.sh, or park the job |
| design | Opus | only when Sonnet classes the stop as design (contract wrong, brief contradicts code): fixes the brief or decision, never the code |

- Every retry is a fresh session; nothing is resumed.
- Limits per job: 3 Haiku attempts, 1 Sonnet escalation, the existing minute and turn limits. 2 parked jobs in one wave stop the wave for Opus.
- A worker with a question writes `BLOCKED.md` and exits; the runner treats that as its own state and goes straight to attempt 3.
- A plan-limit cutoff (5-hour window) is logged as "paused, resume after reset", never counted as an attempt.

## Reviews
1. `tools/review.sh` (mechanical) on every job.
2. A Haiku helper triages each review finding against the diff (real / not real / unsure, with file:line).
3. Sonnet gives verdicts only on real and unsure findings; Real findings become fix jobs as now (max 2 rounds).
4. Opus reviews at milestone end and before public builds (review policy unchanged).

## Driver guardrails
- Sonnet driver hands off at 100k context through DRIVER-NOTES.md (the trial driver went to 164k).
- Waits over about 3 min go to thumb-wait; the driver makes no polling calls.
- A STALLED report is trusted only after the worker log has been still for the job's expected-min (the trial's STALLED was spurious: the worker log writes at job end).
- Hand-committed jobs go into done.txt before a restart.

## Scripts to write (no agent decision needed)
| Script | Does |
|---|---|
| `claude-worker.sh` | the Haiku worker (above) |
| `worktree.sh make\|clean <job>` | worktree from the milestone branch tip; removed after apply |
| `context-pack.sh <brief>` | the coder's context pack |
| `run-escalate.sh` | attempt counting, next attempt's input, when to page Sonnet |
| `job-metrics.sh <dir>` | worker JSON → one run.log line per job (tokens, turns, minutes, attempt, level) and the batch table |
| `brief-size.sh` (or a brief-check rule) | token estimate per brief, warn over 70k |
| `sync-agents.sh` | copy repo `.claude/agents/thumb-*` to the user-level agents folder (written in cost1, Nov 23) |
| `agent-cost.sh` | per-model tokens and API-price estimate from the Claude transcripts; 5m/1h cache split; Sonnet resumes over 5/60 min (cost1, Nov 23) |
| `fake-claude-worker.sh` | test stub with the real exit codes and JSON shape (flash-lessons rule 19) |

## Dependencies to settle in the tools batch
1. Headless permissions on the subscription login (the main safety gap; flash today is boxed by `--bare` plus its tool lists).
2. Plan limits: all workers share the 5-hour window; cap concurrent jobs (2-3 on this PC, also for pub-cache and CPU) and pause rather than fail at a cutoff.
3. Usage visibility: the main session reads weekly usage (get_usage) at batch start and end unless a scriptable source is found.
4. Docs and calibration: digest, framework, COMMON.md, flash-lessons, `run-limits.sh` floors and the job template assume flash; recalibrate floors from the first Claude batches.
5. Fallback: keep `flash.sh` working until the rehearsal passes; decide whether the M14 DeepSeek harness (docs/HANDOFF.md) stays on M14.
6. Agent files and memory notes that describe the flash setup are updated at the switch.

## Open items
- Why i1g2 reached 161 turns under `--max-turns 150` (the report's turn count vs the CLI's count, or a gap in the cap): check before relying on turn caps.
- Whether a Haiku coder follows review-rules reliably when the context pack quotes the relevant rules (the trial's Haiku skipped the file).

## Rollout
1. Tools batch (on flash, as today): claude-worker.sh, worktree.sh, context-pack.sh, run-escalate.sh, job-metrics.sh, the brief-size rule, the 85k stop, fake-claude-worker.sh and runner tests.
2. Rehearsal: one real wave of 2-3 jobs on Haiku; measure per job against flash (minutes, attempts, findings, tokens, weekly usage).
3. Switch: update the digest, framework, agents and memory; flash stays as fallback for one milestone.

## Prompt cache lifetime (Nov 23, 2026)
The user settings (`~/.claude/settings.json`, every project and milestone on this PC) and this repo's `.claude/settings.json` both set `"promptCacheTtl": "1h"` and `"subagentPromptCacheTtl": "1h"` (Claude Code 2.1.242 or later; docs: https://code.claude.com/docs/en/prompt-caching).
- **Why:**
  - By default subagents (the Sonnet drivers, thumb-haiku, thumb-wait) keep a 5-minute cache, so a driver resuming after a 5–60 minute runner wait rewrites its whole context.
  - Nov 23 logs: Sonnet subagent cache cost $20.23 in 460 calls (4.37M tokens written). Replaying the same calls with a 1-hour cache: $15.07 (1.29M written), about $5 a day or 2% of the weekly limit. Haiku subagents go from $0.18 to $0.24.
  - 1-hour writes cost 2× input against 1.25× for 5-minute writes; reads cost 0.1× and restart the timer.
  - `promptCacheTtl` keeps the main session on 1 hour once the plan limit is passed and usage credits are in use (Claude Code drops it to 5 minutes there by default).
- **Scope:**
  - The user settings cover every session and `claude -p` run on this PC, whatever its folder.
  - The repo file covers checkouts of a branch that has it, on any PC.
  - An agent's `experimental.cacheTtl` frontmatter would be ignored on usage credits; these settings are not.
- **Check:**
  - Run `claude -p "hello" --output-format json` in the worktree. `usage.cache_creation.ephemeral_1h_input_tokens` should be non-zero.
  - For subagents, look in the session's `subagents/*.jsonl` transcripts.
- **Revert:**
  - Delete the two keys from both files; the defaults come back.
  - Or force 5 minutes everywhere without editing either file: set the environment variable `FORCE_PROMPT_CACHING_5M=1`, which takes precedence over both.
  - Revert it if a batch shows more cache writes than before, for example if drivers stop waiting (the Sonnet-cost plan) and most subagents run under 5 minutes.
