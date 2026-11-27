#!/usr/bin/env bash
# Tests tools/agent-cost.sh: a call written twice (same message id + requestId) counts once;
# calls before --since are left out; a <synthetic> model is skipped; cache writes split into 5m
# and 1h (a call with no split counts as 5m); prices per model with Haiku at 5x over a 100K
# prompt; Sonnet resumes over 5 and 60 minutes counted per transcript with what they wrote;
# --match keeps matching paths; headless worker logs (flash-<job>.log, no transcript because the
# worker runs with --no-session-persistence) count when --flash-logs names their folder, as one
# Haiku call priced at the normal rate (not the 5x long-prompt rate); bad arguments exit 2.
#
#   bash tools/tests/agent-cost-test.sh
#
# Expected costs (per 1M: opus 4/20, sonnet 2/10, haiku 0.10/0.50 or 0.50/2.50 long):
#   opus  m1: 1000 in, 2000 out, 10000 read (0.05x), 4000 1h write = 0.004 + 0.04 + 0.002 + 0.032
#          = 0.078
#   sonnet s1 50000 5m write (no split) + s2 (10 min later) 20000 1h + s3 (70 min later) 30000 1h
#          = 0.12602 + 0.08102 + 0.12 = 0.32704 (no cache reads)
#   fable f1 1000 in, 1000 out, 100000 read (0.025x), 10000 5m write (1.25x), at 8/40
#          = 0.008 + 0.04 + 0.02 + 0.1 = 0.168; total 0.078 + 0.32704 + 0.0131 + 0.168 = 0.58614
#   haiku h1 small 0.0006 + h2 200000 read (long, 0.1x) 0.0125 = 0.0131; total 0.418 without fable
# --agents (the last cases): rows per agent with dollars by model, the rows summing to the total, the
# driver line (3 main calls, largest context 100000, a 70-minute gap), and the same output without it.
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

# inline waits: agent-w has 3 Bash calls that wait (wait-run.sh, sleep, timeout 170) and 2 that do not
# (timeout 30, a plain ls); agent-a has none. The meta file names the agent.
{
  for i in 1 2 3 4 5; do
    case $i in 1) c='bash tools/wait-run.sh d --max 150';; 2) c='sleep 20';; 3) c='timeout 170 bash x';; 4) c='timeout 30 bash x';; *) c='ls';; esac
    printf '{"type":"assistant","timestamp":"2026-11-23T10:0%s:00Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"tu%s","name":"Bash","input":{"command":"%s"}}]}}
' "$i" "$i" "$c"
  done
} > "$root/sess/subagents/agent-w.jsonl"
echo '{"description":"Waity driver"}' > "$root/sess/subagents/agent-w.meta.json"
# waiters are not flagged: a thumb-wait agent, and a thumb-haiku agent whose description says wait
sed "s/\"tu/\"tw/" "$root/sess/subagents/agent-w.jsonl" > "$root/sess/subagents/agent-tw.jsonl"
echo '{"agentType":"thumb-wait","description":"Wait for wave 1"}' > "$root/sess/subagents/agent-tw.meta.json"
sed "s/\"tu/\"hw/" "$root/sess/subagents/agent-w.jsonl" > "$root/sess/subagents/agent-hw.jsonl"
echo '{"agentType":"thumb-haiku","description":"Wait for check"}' > "$root/sess/subagents/agent-hw.meta.json"
sed "s/\"tu/\"hp/" "$root/sess/subagents/agent-w.jsonl" > "$root/sess/subagents/agent-hp.jsonl"
echo '{"agentType":"thumb-haiku","description":"Evidence pack"}' > "$root/sess/subagents/agent-hp.meta.json"

since=2026-11-23T09:30:00Z
bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" --line > "$out" 2>&1
check line-opus 'opus $0.08 (cw5m 0.00M cw1h 0.00M)'
check line-sonnet 'sonnet $0.33 (cw5m 0.05M cw1h 0.05M)'
check line-haiku 'haiku $0.01'
check line-fable 'fable $0.17 (cw5m 0.01M cw1h 0.00M)'
check line-total 'total $0.59'
check line-gaps 'sonnet resumes >5m 2 (0.05M written), >60m 1 (0.03M written)'
check line-waits '; inline waits >1: 2 agents'

bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" > "$out" 2>&1
check table-opus-dedup 'opus     main       1      1000      2000       10000          0       4000     0.08'
check table-sonnet-sub 'sonnet   sub        3        20       200           0      50000      50000     0.33'
check table-waits-driver 'Waity driver 3'
check table-waits-pack 'Evidence pack 3'
if grep -q 'Wait for' "$out"; then echo "FAIL waiters-skipped"; fails=$((fails + 1)); else echo "PASS waiters-skipped"; fi
check table-long 'haiku calls over 100K prompt (5x price): 1'
if grep -q synthetic "$out"; then echo "FAIL synthetic-skipped"; fails=$((fails + 1)); else echo "PASS synthetic-skipped"; fi

bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" --match agent-h --line > "$out" 2>&1
check match 'haiku $0.01 (cw5m 0.00M cw1h 0.00M); total $0.01'

mkdir -p "$tmp/logs/b"
cat > "$tmp/logs/b/flash-hjob.log" <<'LOG'
---- flash: worker exit 0, model claude-haiku-5-5, log /tmp/x.log
---- flash usage: 12 turns, 51 s, input 1000 + cache read 1000000 + cache write 100000, output 2000 tokens
LOG
touch -d 2026-11-23T10:30:00Z "$tmp/logs/b/flash-hjob.log"
# input 1000*0.1 + output 2000*0.5 + read 1M*0.01 + write 100K*0.125 = 23600 / 1e6 = 0.0236 (a 5x rate would be 0.118)
bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" --flash-logs "$tmp/logs" --match hjob --line > "$out" 2>&1
check headless-counted 'haiku $0.02 (cw5m 0.10M cw1h 0.00M); total $0.02'
bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" --flash-logs "$tmp/logs" > "$out" 2>&1
check headless-row 'haiku    head       1      1000      2000     1000000     100000          0     0.02'
bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" --match hjob --line > "$out" 2>&1
check headless-off-without-folder 'no calls'

mkdir -p "$tmp/logs/s"
cat > "$tmp/logs/s/flash-sjob.log" <<'LOG'
---- flash: worker exit 0, model claude-sonnet-5-5, log /tmp/y.log
---- flash usage: 12 turns, 51 s, input 1000 + cache read 1000000 + cache write 100000, output 2000 tokens
LOG
touch -d 2026-11-23T10:30:00Z "$tmp/logs/s/flash-sjob.log"
# sonnet 2/10: input 2000 + output 20000 + read 1M*0.05*2=100000 + write 100K*1.25*2=250000 = 372000 / 1e6 = 0.372
bash tools/agent-cost.sh --root "$tmp/projects" --since "$since" --flash-logs "$tmp/logs" --match sjob --line > "$out" 2>&1
check headless-sonnet-priced 'sonnet $0.37'

bash tools/agent-cost.sh --root "$tmp/projects" > "$out" 2>&1
rc=$?
if [ "$rc" = 2 ]; then echo "PASS no-since-exit-2"; else echo "FAIL no-since-exit-2 (got $rc)"; fails=$((fails + 1)); fi
bash tools/agent-cost.sh --root "$tmp/nope" --since 1h > "$out" 2>&1
rc=$?
if [ "$rc" = 2 ]; then echo "PASS missing-root-exit-2"; else echo "FAIL missing-root-exit-2 (got $rc)"; fails=$((fails + 1)); fi

# --agents: one row per subagent transcript (type and description from its .meta.json, dollars by
# model), then the headless runs and the main transcripts; the rows sum to the total. The driver line
# gives the REPORT fields: main calls, largest context, longest gap between two main calls. Its own
# folder, so the cases above keep their numbers.
agroot="$tmp/agents/proj"
mkdir -p "$agroot/subagents"
{
  line m1 2026-11-23T10:00:00Z claude-opus-5-5 '{"input_tokens":1000,"output_tokens":2000}'
  line m2 2026-11-23T10:10:00Z claude-opus-5-5 '{"input_tokens":0,"output_tokens":1000,"cache_read_input_tokens":100000}'
  line m3 2026-11-23T11:20:00Z claude-opus-5-5 '{"input_tokens":5000,"output_tokens":0,"cache_creation_input_tokens":20000,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":20000}}'
} > "$agroot/sess.jsonl"
{
  line p1 2026-11-23T10:00:00Z claude-haiku-5-5 '{"input_tokens":1000,"output_tokens":1000}'
  line p2 2026-11-23T10:05:00Z claude-sonnet-5-5 '{"input_tokens":0,"output_tokens":1000}'
} > "$agroot/subagents/agent-a.jsonl"
echo '{"agentType":"thumb-haiku","description":"Evidence pack"}' > "$agroot/subagents/agent-a.meta.json"
{
  line q1 2026-11-23T10:20:00Z claude-sonnet-5-5 '{"input_tokens":0,"output_tokens":10000}'
  line q2 2026-11-23T10:30:00Z claude-opus-5-5 '{"input_tokens":0,"output_tokens":1000}'
} > "$agroot/subagents/agent-b.jsonl"
echo '{"agentType":"thumb-build","description":"Wave 2 build"}' > "$agroot/subagents/agent-b.meta.json"
# main 0.264 (opus m1 0.044, m2 0.04, m3 0.18); agent-a 0.0106; agent-b 0.12; total 0.3946.
# Driver: 3 main calls, largest context m2 100000 (cache read), gaps 10 min and 70 min.

bash tools/agent-cost.sh --root "$tmp/agents" --since "$since" --agents > "$out" 2>&1
check agents-rows-sum 'rows sum $0.3946'
check agents-build-models 'opus $0.0200, sonnet $0.1000'
check agents-evidence-models 'sonnet $0.0100, haiku $0.0006'
check agents-main-models 'opus $0.2640'
check driver-line 'driver: calls 3, largest context 100000 tokens, longest wait 70 min'
b=$(grep -n 'Wave 2 build' "$out" | head -1 | cut -d: -f1)
a=$(grep -n 'Evidence pack' "$out" | head -1 | cut -d: -f1)
m=$(grep -n 'main transcripts' "$out" | head -1 | cut -d: -f1)
if [ -n "$b" ] && [ -n "$a" ] && [ -n "$m" ] && [ "$b" -lt "$a" ] && [ "$a" -lt "$m" ]; then
  echo "PASS agents-sorted-main-last"
else
  echo "FAIL agents-sorted-main-last (lines build=$b evidence=$a main=$m)"; sed 's/^/    | /' "$out"; fails=$((fails + 1))
fi

bash tools/agent-cost.sh --root "$tmp/agents" --since "$since" > "$out" 2>&1
check agents-off-total 'total $0.39'
if grep -q -e 'driver:' -e 'rows sum' "$out"; then echo "FAIL agents-off-unchanged"; fails=$((fails + 1)); else echo "PASS agents-off-unchanged"; fi

# headless runs (the two logs above, 0.0236 haiku and 0.372 sonnet) are a row of their own: 0.3946 + 0.3956
bash tools/agent-cost.sh --root "$tmp/agents" --since "$since" --flash-logs "$tmp/logs" --agents > "$out" 2>&1
check agents-headless-row 'headless worker runs'
check agents-headless-sum 'rows sum $0.7902'

[ "$fails" = 0 ] || exit 1
