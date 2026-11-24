#!/usr/bin/env bash
# Tests tools/agent-cost.sh: a call written twice (same message id + requestId) counts once;
# calls before --since are left out; a <synthetic> model is skipped; cache writes split into 5m
# and 1h (a call with no split counts as 5m); prices per model with Haiku at 5x over a 100K
# prompt; Sonnet resumes over 5 and 60 minutes counted per transcript with what they wrote;
# --match keeps matching paths; bad arguments exit 2.
#
#   bash tools/tests/agent-cost-test.sh
#
# Expected costs (per 1M: opus 4/20, sonnet 2/10, haiku 0.10/0.50 or 0.50/2.50 long):
#   opus  m1: 1000 in, 2000 out, 10000 read, 4000 1h write  = 0.08
#   sonnet s1 50000 5m write (no split) + s2 (10 min later) 20000 1h + s3 (70 min later) 30000 1h
#          = 0.12602 + 0.08102 + 0.12 = 0.33
#   fable f1 1000 in, 1000 out, 100000 read (0.025x), 10000 5m write (1.25x), at 8/40
#          = 0.008 + 0.04 + 0.02 + 0.1 = 0.168; total 0.588
#   haiku h1 small 0.0006 + h2 200000 read (long) 0.0125 = 0.01; total 0.42 without fable
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/agent-cost-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
out="$tmp/out.txt"
check() { # check <case> <text that must appear in $out>
  if grep -qF -- "$2" "$out"; then echo "PASS $1"; else echo "FAIL $1 (want: $2)"; sed 's/^/    | /' "$out"; fails=$((fails + 1)); fi
}

root="$tmp/projects/proj"
mkdir -p "$root/sess/subagents"
line() { # line <id> <ts> <model> <usage json>
  printf '{"type":"assistant","requestId":"r-%s","timestamp":"%s","message":{"id":"%s","model":"%s","usage":%s}}\n' "$1" "$2" "$1" "$3" "$4"
}
{
  line m0 2026-11-23T09:00:00Z claude-opus-5-5 '{"input_tokens":999999,"output_tokens":0}'
  line m1 2026-11-23T10:00:00Z claude-opus-5-5 '{"input_tokens":1000,"output_tokens":2000,"cache_read_input_tokens":10000,"cache_creation_input_tokens":4000,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":4000}}'
  line m1 2026-11-23T10:00:00Z claude-opus-5-5 '{"input_tokens":1000,"output_tokens":2000,"cache_read_input_tokens":10000,"cache_creation_input_tokens":4000,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":4000}}'
  line x1 2026-11-23T10:01:00Z '<synthetic>' '{"input_tokens":0,"output_tokens":0}'
  echo 'not json "usage"'
} > "$root/sess.jsonl"
{
  line s1 2026-11-23T10:00:00Z claude-sonnet-5-5 '{"input_tokens":10,"output_tokens":100,"cache_creation_input_tokens":50000}'
  line s2 2026-11-23T10:10:00Z claude-sonnet-5-5 '{"input_tokens":10,"output_tokens":100,"cache_creation_input_tokens":20000,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":20000}}'
  line s3 2026-11-23T11:20:00Z claude-sonnet-5-5 '{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":30000,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":30000}}'
} > "$root/sess/subagents/agent-a.jsonl"
{
  line h1 2026-11-23T10:00:00Z claude-haiku-5-5 '{"input_tokens":1000,"output_tokens":1000}'
  line h2 2026-11-23T10:05:00Z claude-haiku-5-5 '{"input_tokens":0,"output_tokens":1000,"cache_read_input_tokens":200000}'
} > "$root/sess/subagents/agent-h.jsonl"

{
  line f1 2026-11-23T10:30:00Z claude-fable-5-2 '{"input_tokens":1000,"output_tokens":1000,"cache_read_input_tokens":100000,"cache_creation_input_tokens":10000}'
} > "$root/sess/subagents/agent-f.jsonl"

since=2026-11-23T09:30:00Z
bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" --line > "$out" 2>&1
check line-opus 'opus $0.08 (cw5m 0.00M cw1h 0.00M)'
check line-sonnet 'sonnet $0.33 (cw5m 0.05M cw1h 0.05M)'
check line-haiku 'haiku $0.01'
check line-fable 'fable $0.17 (cw5m 0.01M cw1h 0.00M)'
check line-total 'total $0.59'
check line-gaps 'sonnet resumes >5m 2 (0.05M written), >60m 1 (0.03M written)'

bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" > "$out" 2>&1
check table-opus-dedup 'opus     main       1      1000      2000       10000          0       4000     0.08'
check table-sonnet-sub 'sonnet   sub        3        20       200           0      50000      50000     0.33'
check table-long 'haiku calls over 100K prompt (5x price): 1'
if grep -q synthetic "$out"; then echo "FAIL synthetic-skipped"; fails=$((fails + 1)); else echo "PASS synthetic-skipped"; fi

bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" --match agent-h --line > "$out" 2>&1
check match 'haiku $0.01 (cw5m 0.00M cw1h 0.00M); total $0.01'

bash tools/agent-cost.sh --root "$tmp/projects" > "$out" 2>&1
rc=$?
if [ "$rc" = 2 ]; then echo "PASS no-since-exit-2"; else echo "FAIL no-since-exit-2 (got $rc)"; fails=$((fails + 1)); fi
bash tools/agent-cost.sh --root "$tmp/nope" --since 1h > "$out" 2>&1
rc=$?
if [ "$rc" = 2 ]; then echo "PASS missing-root-exit-2"; else echo "FAIL missing-root-exit-2 (got $rc)"; fails=$((fails + 1)); fi

[ "$fails" = 0 ] || exit 1
