#!/usr/bin/env bash
# What the Claude agents cost: per-model token totals and an API-price estimate, read from the
# Claude Code transcripts (~/.claude/projects/**/*.jsonl, subagents/ included). For a batch
# report: put the --line output next to job-metrics in REVIEW.md.
#
#   tools/agent-cost.sh --since <time> [--until <time>] [--match <text>] [--root <dir>] [--flash-logs <dir>] [--line]
#     [--agents]
#
# --agents adds, after the normal output, one row per subagent transcript (agent type and description
# from its .meta.json, calls, dollars by model; sorted by dollars), a row for headless runs when there
# are any, and a last row for the main transcripts. The rows sum to the total. It also prints the
# driver REPORT line: call count, largest context (input + cache read + cache write of one main call)
# and the longest wait between two main calls, in minutes.
#
# <time> is ISO (2026-11-23T14:00, local unless it carries an offset or Z), `today`, or a
# relative 30m / 2h / 1d. --match keeps transcripts whose path contains the text (a project
# folder name such as E--AI-game-controller-m16). --root replaces ~/.claude/projects.
#
# Headless workers (`claude -p --no-session-persistence`, the runner's Haiku jobs) write no transcript;
# their flash-<job>.log keeps one usage line. Those runs count as WHO "head" (one call per run, the log's
# last-write time, cache write as 5m, never the long-prompt rate). --flash-logs names the folder to search
# (default docs/briefs of this repo when --root is not given; none otherwise).
#
# Each API call counts once (message id + requestId; Claude Code writes one line per content
# block). Rows are model x main/sub (sub = a subagents/ transcript). Cache writes are split into
# 5-minute and 1-hour (usage.cache_creation.ephemeral_*; a call without the split counts as 5m).
# Prices per 1M tokens: Opus $4 in / $20 out, Sonnet $2 / $10, Haiku $0.10 / $0.50 or $0.50 /
# $2.50 when the call's prompt (input + cache read + cache write) is over 100K; cache read 0.1x
# input, cache write 1.25x (5m) or 2x (1h). The last line counts Sonnet calls that came more than
# 5 or 60 minutes after the same transcript's previous call (a resume that rewrote its cache under
# the old 5-minute or the new 1-hour lifetime) and the cache those calls wrote.
#
# Exit 0, or 2 on bad arguments or a missing root.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
py=python
command -v "$py" > /dev/null 2>&1 || py=python3
exec "$py" -X utf8 "$here/agent_cost.py" "$@"
