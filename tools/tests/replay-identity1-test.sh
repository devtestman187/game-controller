#!/usr/bin/env bash
# Replays identity1's waves 1 and 2 on the real history: tools/brief-check.sh must FAIL for every
# miss those waves recorded (i1a's new message breaks a switch in client_messages.dart and
# host_connection.dart, the codec's _decoders never learns the message, the m9_test files pin the
# message set, the hello capability list), and with REPLAY_PROBE=1 tools/probe-deps.sh must FAIL
# i1a's two error files as in no job's allow (wave1) and as a same-wave dependence on i1a2
# (wave1-split).
#
#   bash tools/tests/replay-identity1-test.sh                 # the six brief-check misses (a few seconds)
#   REPLAY_PROBE=1 bash tools/tests/replay-identity1-test.sh  # and the two probe-deps cases (minutes)
#
# The fixtures under tools/tests/fixtures/replay are the identity1 briefs with the changes: and
# probe: lines added, a folder per batch; expected.txt lists what each tool must print, one line
# per recorded miss; BASES.txt holds the two bases, so no checkout is needed: BRIEF_CHECK_REF and
# PROBE_BASE both read a commit's tree. A base this clone does not have (a shallow or a fresh
# clone) is a `PASS skip` line naming the reason, because neither tool can read a commit that
# isn't there. probe-deps runs only under REPLAY_PROBE=1: it checks the base out in a throwaway
# worktree and runs pub get and analyze there, which takes minutes.
#
# Prints PASS <case> / FAIL <case> (the tool's output indented under a failure) and exits 1 if
# any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
fixtures=tools/tests/fixtures/replay
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/replay-identity1-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
skips=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the tool printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

# BASES.txt: line 1 is wave1's and wave1-split's base, line 2 is wave2's (expected.txt's last
# line says which line holds which batch). The copies carry a CR on each line: dropped on the way in.
mapfile -t bases < <(tr -d '\r' < "$fixtures/BASES.txt" | awk 'NF')
batch_base() { # batch_base <batch>: the commit that batch's briefs are replayed at
  case $1 in
    wave1 | wave1-split) printf '%s' "${bases[0]:-}" ;;
    wave2) printf '%s' "${bases[1]:-}" ;;
  esac
}

have_base() { # have_base <sha>: 0 when this clone has that commit (a shallow clone may not)
  [ -n "$1" ] && git cat-file -e "$1^{commit}" > /dev/null 2>&1
}

out="$tmp/out.txt"
fail_names() { # fail_names <text>: 0 when a FAIL line of $out holds that text
  grep '^FAIL' "$out" | grep -qF -- "$1"
}

run_brief_check() { # run_brief_check <batch>: one run covers the batch; the rc goes beside its output
  local rc=0
  BRIEF_CHECK_REF="$(batch_base "$1")" bash tools/brief-check.sh "$fixtures/$1" > "$tmp/$1.out" 2>&1 || rc=$?
  printf '%s\n' "$rc" > "$tmp/$1.rc"
}

# expected.txt: `batch tool step what the tool must print the miss`, one line per recorded miss, `#`
# comments. A brief-check line's step is the rule (`changes`) and the word after it the file name
# the FAIL line must hold (on host_connection.dart:188 the `:188` is the recorded location, dropped).
tr -d '\r' < "$fixtures/expected.txt" > "$tmp/expected.txt"

# One brief-check run per batch (the tool checks every job of the batch at once); a batch whose
# base the clone lacks is not run, and its misses become the skip lines below.
for batch in $(awk '$1 !~ /^#/ && $2 == "brief-check" && !seen[$1]++ { print $1 }' "$tmp/expected.txt"); do
  have_base "$(batch_base "$batch")" && run_brief_check "$batch"
done

while read -r batch tool _ rest; do
  [ "$tool" = brief-check ] || continue
  read -r needle miss <<< "$rest"
  needle=${needle%:*} # host_connection.dart:188 -> host_connection.dart
  out="$tmp/$batch.out"
  [ -f "$out" ] || printf 'no base for %s in BASES.txt, so the tool did not run\n' "$batch" > "$out"
  base=$(batch_base "$batch")
  if [ -z "$base" ]; then
    r=1
  elif ! have_base "$base"; then
    pass "skip $batch brief-check: base $base is not in this clone"
    skips=$((skips + 1))
    continue
  elif [ "$(cat "$tmp/$batch.rc" 2> /dev/null)" = 1 ] && [ -n "$needle" ] && fail_names "$needle"; then
    # An empty needle would match any FAIL line: it is no assertion, so it passes nothing.
    r=0
  else
    r=1
  fi
  report "$batch brief-check FAILs on $needle: $miss" "$r"
done < "$tmp/expected.txt"

# The two probe-deps lines of expected.txt, restated as the two cases below. The wave2 layers line
# and the apply-job line are rehearsal items, done by hand and so not asserted here: the layers
# WARN needs the arena_character_painter.dart the fix itself wrote, and apply-job runs a real job.
if [ "${REPLAY_PROBE:-0}" = 1 ]; then
  probe() { # probe <batch>: probe-deps at the batch's base; sets rc and writes $out
    rc=0
    out="$tmp/probe-$1.out"
    PROBE_BASE="$(batch_base "$1")" bash tools/probe-deps.sh "$fixtures/$1" > "$out" 2>&1 || rc=$?
  }

  # wave1: i1b and i1c allow neither file the stub's analyze errors name, so each is in no allow.
  probe wave1
  if [ "$rc" = 1 ] && fail_names 'client_messages.dart is in no job' &&
    fail_names 'host_connection.dart is in no job'; then r=0; else r=1; fi
  report "wave1 probe-deps FAILs client_messages.dart and host_connection.dart, in no job's allow" "$r"

  # wave1-split: the same two files, now only i1a2's allow holds them, in i1a's own wave.
  probe wave1-split
  if [ "$rc" = 1 ] &&
    fail_names 'client_messages.dart is only in the allow of i1a2, a job of the same wave 1' &&
    fail_names 'host_connection.dart is only in the allow of i1a2, a job of the same wave 1'; then r=0; else r=1; fi
  report "wave1-split probe-deps FAILs i1a2's same-wave fix of both files the i1a stub breaks" "$r"
else
  echo "probe-deps cases not run: REPLAY_PROBE=1 runs them (minutes: pub get and analyze at the base)"
fi

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
# A replay that asserted nothing is not a pass; only a base this clone lacks may leave nothing to
# check, and that case prints its skip line above.
if [ "$cases" = 0 ] && [ "$skips" = 0 ]; then
  echo "FAIL the replay asserted nothing: expected.txt names no case for a base this clone has"
  echo "RESULT: FAILED: 1 of 0 case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed, $skips batch(es) skipped"
