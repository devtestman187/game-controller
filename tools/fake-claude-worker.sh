#!/usr/bin/env bash
# Stands in for the `claude` CLI itself in tests of tools/claude-worker.sh: one
# line of the JSON a headless run prints with --output-format json, and the exit
# code the CLI gives, so the preflight and a job's log can be tested with no
# Claude login, no network and no token spend.
#
#   tools/fake-claude-worker.sh --model <id> [--max-turns <n>]   # what flash.sh runs
#
# Every other option is ignored; the answer depends on FAKE_CLAUDE_MODE. Env,
# all optional:
#   FAKE_CLAUDE_MODE       what the run answers: ok (default), denial, max_turns, auth
#   FAKE_CLAUDE_ARGS_FILE  a file that gets, per run, the argument list (one line)
#                          and a line `env: base=<ANTHROPIC_BASE_URL> key=<ANTHROPIC_API_KEY>`
#
# The modes: ok is success with no permission denial, result PREFLIGHT-DONE and
# exit 0; denial is the same JSON with one permission_denials entry; max_turns
# stops at the cap (subtype error_max_turns, is_error true, terminal_reason
# max_turns, num_turns one past the cap, exit 1); auth is an auth error ("Invalid
# API key - Please run /login", is_error true, exit 1).
# The field names and exit codes are the real CLI's: a --max-turns stop is exit 1
# with that JSON, and num_turns counts each tool call of a parallel batch while
# the cap counts model rounds, so a stopped run's count can pass the cap.
# Exit code: 0 for ok and denial, 1 for max_turns and auth (as the CLI does), 2
# for a bad mode or a --max-turns that isn't a whole number.
# Works in Git Bash on Windows and bash on macOS/Linux.
set -u

# Sample numbers for one stand-in run: they fill the JSON's shape, which is all
# the log's readers look at.
in_tokens=1200
out_tokens=80
cache_read_tokens=9000
cache_creation_tokens=400
cost_usd=0.0012
turns_ok=3
cap_default=35
# A fixed sample id: a real run prints a fresh one, which no reader keys on.
session_id="00000000-0000-4000-8000-000000000000"

bad() { echo "fake-claude-worker: $1" >&2; exit 2; }

whole() { # whole <name> <value>: exits 2 unless the value is digits
  case "$2" in '' | *[!0-9]*) bad "$1 takes a whole number, got '$2'" ;; esac
}

mode="${FAKE_CLAUDE_MODE:-ok}"
case "$mode" in ok | denial | max_turns | auth) ;; *)
  bad "FAKE_CLAUDE_MODE must be ok, denial, max_turns or auth, got '$mode'" ;;
esac

# The argument list as one line, so a newline inside the task can't split it.
argv="$(printf '%s' "$*" | tr '\n\r' '  ')"
model="model-not-given"
cap=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model)
      [ $# -ge 2 ] || bad "--model needs a value"
      model="$2"
      shift
      ;;
    --max-turns)
      [ $# -ge 2 ] || bad "--max-turns needs a value"
      cap="$2"
      shift
      ;;
    -h | --help)
      sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
  shift
done
[ -n "$cap" ] || cap="$cap_default"
whole --max-turns "$cap"

args_file="${FAKE_CLAUDE_ARGS_FILE:-}"
if [ -n "$args_file" ]; then
  {
    printf '%s\n' "$argv"
    printf 'env: base=%s key=%s\n' "${ANTHROPIC_BASE_URL:-}" "${ANTHROPIC_API_KEY:-}"
  } >> "$args_file" || bad "couldn't append to $args_file"
fi

usage="{\"input_tokens\":$in_tokens,\"cache_creation_input_tokens\":$cache_creation_tokens,"
usage+="\"cache_read_input_tokens\":$cache_read_tokens,\"output_tokens\":$out_tokens}"
model_usage="{\"inputTokens\":$in_tokens,\"outputTokens\":$out_tokens,\"cacheReadInputTokens\":$cache_read_tokens,"
model_usage+="\"cacheCreationInputTokens\":$cache_creation_tokens,\"webSearchRequests\":0,\"costUSD\":$cost_usd}"

# emit: the run's one JSON line, from the fields the mode sets below.
emit() {
  printf '{"type":"result","subtype":"%s","is_error":%s,"num_turns":%s,"result":"%s","session_id":"%s",' \
    "$subtype" "$is_error" "$num_turns" "$result_text" "$session_id"
  printf '"usage":%s,"modelUsage":{"%s":%s},"permission_denials":%s%s}\n' \
    "$usage" "$model" "$model_usage" "$denials" "$terminal"
}

denials="[]"
terminal=',"terminal_reason":"completed"'
code=0
case "$mode" in
  ok)
    subtype="success" is_error=false num_turns=$turns_ok result_text="PREFLIGHT-DONE"
    ;;
  denial)
    subtype="success" is_error=false num_turns=$turns_ok result_text="PREFLIGHT-DONE"
    denials='[{"tool_name":"Bash","tool_use_id":"toolu_p5a_not_a_real_id","tool_input":'
    denials+='{"command":"tools/check.sh --list"}}]'
    ;;
  max_turns)
    subtype="error_max_turns" is_error=true num_turns=$((10#$cap + 1))
    result_text="Stopped at the maximum number of turns"
    terminal=',"terminal_reason":"max_turns"'
    code=1
    ;;
  auth)
    subtype="error_during_execution" is_error=true num_turns=$turns_ok
    result_text="Invalid API key - Please run /login"
    terminal=""
    code=1
    ;;
esac
emit
exit "$code"
