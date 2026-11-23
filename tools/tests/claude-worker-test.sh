#!/usr/bin/env bash
# Tests tools/claude-worker.sh (the Haiku worker on the anthropic subscription
# login) and tools/fake-claude-worker.sh (the stand-in for the `claude` CLI it
# runs under): the dry-run command the wrapper builds, its two env knobs, plain
# flash.sh left as it was, --web refused, the preflight's exit code through four
# stand-in answers, the stand-in's JSON shapes, and the env line that keeps an
# API key or base URL out of a run.
#
#   bash tools/tests/claude-worker-test.sh
#
# Every case runs bash with a `claude` shim on PATH that execs the stand-in, so
# no Claude login, network or token spend is needed; the whole run takes a few
# seconds. Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
# Works in Git Bash on Windows and bash on macOS/Linux.
set -u

cd "$(dirname "$0")/../.." || exit 2
worker="$(pwd)/tools/claude-worker.sh"
flash="$(pwd)/tools/flash.sh"
stub="$(pwd)/tools/fake-claude-worker.sh"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/claude-worker-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
# report <case> <0 passed | 1 failed>: on a failure, show the start of what the run printed.
report() {
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then
    pass "$1"
  else
    fail "$1"
    head -c 600 "$out" | sed 's/^/    | /'
  fi
}

out="$tmp/out.txt"
rc=0
has() { grep -qF -- "$1" "$out"; }
field_of() { sed -n "$1p" "$2" | tr -d '\r'; } # field_of <line> <file>: that line, without a CR

# flash.sh only asks whether `claude` is installed before a dry run (the
# preflight and a real run start the CLI itself), so a shim that execs the
# stand-in stands in for the CLI. On Windows the shim's folder must be a POSIX
# path on PATH: a `C:\...` entry is split at its colon, the shim is not found
# and a real `claude` on PATH runs instead.
stubbin="$tmp/bin"
mkdir -p "$stubbin"
cat > "$stubbin/claude" << EOF
#!/usr/bin/env bash
exec bash "$stub" "\$@"
EOF
chmod +x "$stubbin/claude"
stub_path="$stubbin"
if command -v cygpath > /dev/null 2>&1; then stub_path="$(cygpath -u "$stubbin")"; fi

# run_worker [VAR=value]...: claude-worker.sh --dry-run with those variables set.
run_worker() {
  rc=0
  PATH="$stub_path:$PATH" env "$@" bash "$worker" --dry-run "task" > "$out" 2>&1 || rc=$?
}
# run_preflight [VAR=value]...: claude-worker.sh --preflight with those variables set.
run_preflight() {
  rc=0
  PATH="$stub_path:$PATH" env "$@" bash "$worker" --preflight > "$out" 2>&1 || rc=$?
}

run_worker
r=1
if [ "$rc" = 0 ] && has "worker: claude | model: claude-haiku-5-5 | max-turns: 35"; then r=0; fi
report "the wrapper runs the claude worker on claude-haiku-5-5 with a 35-turn cap" "$r"

r=1
if has "--safe-mode" && has "--strict-mcp-config" && has "--disable-slash-commands" \
  && has "--no-session-persistence" && ! has "--bare"; then r=0; fi
report "the claude worker isolates with --safe-mode and its three flags, never --bare" "$r"

run_worker CLAUDE_WORKER_MODEL=claude-haiku-9-9-test CLAUDE_WORKER_MAX_TURNS=7
r=1
if [ "$rc" = 0 ] && has "model: claude-haiku-9-9-test | max-turns: 7 |" \
  && has "--model claude-haiku-9-9-test" && has "--max-turns 7"; then r=0; fi
report "CLAUDE_WORKER_MODEL and CLAUDE_WORKER_MAX_TURNS set the model and the turn cap" "$r"

rc=0
PATH="$stub_path:$PATH" env -u FLASH_WORKER -u FLASH_MODEL -u FLASH_MAX_TURNS bash "$flash" --dry-run "task" > "$out" 2>&1 || rc=$?
r=1
if [ "$rc" = 0 ] && has "worker: flash | model: deepseek-v4-flash | max-turns: 150 |" && has "--bare" \
  && has "--max-turns 150"; then r=0; fi
report "plain flash.sh still runs the DeepSeek worker with --bare and 150 turns" "$r"

web_brief="$tmp/web-brief.md"
printf 'job: p5a web check\nweb: yes\nreport: docs/p5a-web-check.md\n' > "$web_brief"
rc=0
PATH="$stub_path:$PATH" bash "$worker" --brief "$web_brief" --dry-run > "$out" 2>&1 || rc=$?
r=1
if [ "$rc" = 2 ] && has "DeepSeek-only"; then r=0; fi
report "--web under the claude worker is refused with exit 2 (a DeepSeek-only job type)" "$r"

turns_brief="$tmp/turns-brief.md"
printf 'job: turns case\nturns: 50\nreport: docs/turns-case.md\n' > "$turns_brief"
rc=0
PATH="$stub_path:$PATH" bash "$worker" --brief "$turns_brief" --dry-run > "$out" 2>&1 || rc=$?
r=1
if [ "$rc" = 0 ] && has "max-turns: 50"; then r=0; fi
report "a brief's turns line raises the claude worker's --max-turns (50)" "$r"

low_brief="$tmp/low-turns-brief.md"
printf 'job: low turns case\nturns: 20\nreport: docs/low-turns-case.md\n' > "$low_brief"
rc=0
PATH="$stub_path:$PATH" bash "$worker" --brief "$low_brief" --dry-run > "$out" 2>&1 || rc=$?
r=1
if [ "$rc" = 0 ] && has "max-turns: 35"; then r=0; fi
report "a brief's turns line below the default does not lower the claude worker's --max-turns (35)" "$r"

args_ok="$tmp/args-ok.txt"
run_preflight FAKE_CLAUDE_ARGS_FILE="$args_ok"
r=1
if [ "$rc" = 0 ] && has "preflight ok"; then r=0; fi
report "--preflight through the claude worker exits 0 when the CLI answers ok" "$r"

r=1
if grep -qF -- "--safe-mode" "$args_ok" && grep -qF -- "--max-turns 8" "$args_ok" \
  && grep -qF -- "Preflight, nothing else" "$args_ok"; then r=0; fi
report "the CLI gets --safe-mode and the preflight's own --max-turns 8 with its task" "$r"

r=1
if [ "$(field_of 2 "$args_ok")" = "env: base= key=" ]; then r=0; fi
report "the stand-in's env line is empty with no API variables set" "$r"

args_env="$tmp/args-env.txt"
run_preflight ANTHROPIC_BASE_URL=https://api.deepseek.example/anthropic ANTHROPIC_API_KEY=sk-p5a-not-a-key \
  FAKE_CLAUDE_ARGS_FILE="$args_env"
r=1
if [ "$rc" = 0 ] && [ "$(field_of 2 "$args_env")" = "env: base= key=" ]; then r=0; fi
report "the CLI's env line stays empty when ANTHROPIC_BASE_URL and ANTHROPIC_API_KEY were exported" "$r"

run_preflight FAKE_CLAUDE_MODE=denial FAKE_CLAUDE_ARGS_FILE="$tmp/args-denial.txt"
r=1
if [ "$rc" = 7 ] && has "PREFLIGHT FAILED" && has "permission_denials"; then r=0; fi
report "--preflight exits 7 when the CLI reports a permission denial" "$r"

run_preflight FAKE_CLAUDE_MODE=max_turns FAKE_CLAUDE_ARGS_FILE="$tmp/args-max-turns.txt"
r=1
if [ "$rc" = 7 ] && has "PREFLIGHT FAILED (exit 1)"; then r=0; fi
report "--preflight exits 7 when the CLI stops at its turn cap (the CLI exits 1)" "$r"

run_preflight FAKE_CLAUDE_MODE=auth FAKE_CLAUDE_ARGS_FILE="$tmp/args-auth.txt"
r=1
if [ "$rc" = 7 ] && has "PREFLIGHT FAILED (exit 1)"; then r=0; fi
report "--preflight exits 7 when the CLI reports an auth error (the CLI exits 1)" "$r"

rc=0
bash "$stub" --model claude-haiku-5-5 --max-turns 8 > "$out" 2>&1 || rc=$?
r=1
if [ "$rc" = 0 ] && [ "$(wc -l < "$out" | tr -d '[:space:]')" = 1 ] && has '"type":"result"' \
  && has '"subtype":"success"' && has '"is_error":false' && has 'PREFLIGHT-DONE' \
  && has '"permission_denials":[]' && has '"terminal_reason":"completed"' \
  && has '"modelUsage":{"claude-haiku-5-5":'; then r=0; fi
report "the stand-in's ok answer is the CLI's one-line JSON, modelUsage keyed by --model" "$r"

rc=0
FAKE_CLAUDE_MODE=max_turns bash "$stub" --model claude-haiku-9-9-test --max-turns 4 > "$out" 2>&1 || rc=$?
r=1
if [ "$rc" = 1 ] && has '"subtype":"error_max_turns"' && has '"is_error":true' && has '"num_turns":5' \
  && has '"terminal_reason":"max_turns"'; then r=0; fi
report "a max-turns stop is exit 1 with error_max_turns and num_turns one past the cap (4 gives 5)" "$r"

rc=0
FAKE_CLAUDE_MODE=auth bash "$stub" --model claude-haiku-9-9-test --max-turns 8 > "$out" 2>&1 || rc=$?
r=1
if [ "$rc" = 1 ] && has '"is_error":true' && has "Invalid API key - Please run /login"; then r=0; fi
report "an auth answer is exit 1 with is_error true and the CLI's /login message" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
exit 0
