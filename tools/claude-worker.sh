#!/usr/bin/env bash
# Runs a job on the Anthropic subscription login with Haiku instead of DeepSeek:
# tools/flash.sh with FLASH_WORKER=claude. The same worktree, allow and deny
# lists, turn cap, preflight and report handling; only the worker changes.
# Documented in docs/design/claude-only-model.md, "The worker".
#
#   tools/claude-worker.sh --brief <file> [--here]   # a job, as flash.sh runs one
#   tools/claude-worker.sh --dry-run ...             # print the command, don't run it
#   tools/claude-worker.sh --preflight               # one tiny real call; exit 7 if it fails
#
# The options are flash.sh's (its header lists them); this file sets only the
# worker and its two knobs:
#   CLAUDE_WORKER_MODEL      the model, an exact id and not an alias (default claude-haiku-5-5)
#   CLAUDE_WORKER_MAX_TURNS  model rounds before the CLI stops the job (default 35)
#
# Isolation it achieves: --safe-mode in place of --bare loads no CLAUDE.md or
# user memory, no hooks, MCP servers, skills, agents or plugins; --strict-mcp-config
# keeps the MCP servers of any settings file out; --disable-slash-commands keeps
# the slash commands out; --no-session-persistence writes no session file, so
# nothing resumes later; CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 stops the automatic
# memory notes; ANTHROPIC_BASE_URL, ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN are
# unset for the run, so a key or base URL in the caller's shell can't send it to
# an API account instead of the login.
# Isolation it does not achieve: admin-managed settings (managed-settings.json and
# an organisation's policy) still apply; the run shares the account's 5-hour and
# weekly limits with every other Claude session, so a plan cutoff ends it; the CLI
# still reads its own auth files (it must, to use the login); and CLAUDE_CODE_*
# variables exported by the caller reach the worker (flash.sh sets the caps on
# purpose).
#
# Not for --web jobs: flash.sh refuses them (a research job stays on DeepSeek).
# Exit code: flash.sh's (0 passed, 2 bad arguments or setup, 3 a protected file
# changed, 4 a file outside --allow changed, 5 a check failed, 6 the changes
# couldn't be applied). --preflight failure is 7.
# Works in Git Bash on Windows and bash on macOS/Linux.
set -u

# flash.sh picks the worker from FLASH_WORKER (its wkind block); everything else
# is its own. exec keeps its exit code and its output as they are.
export FLASH_WORKER=claude
exec bash "$(dirname "$0")/flash.sh" "$@" < /dev/null # no stdin for the worker or its children (tune4 K1)
