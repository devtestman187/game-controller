#!/usr/bin/env bash
# Sourced by tools/run-jobs.sh, after it has cd'd to the repo root:
#   . "$dir/run-wave.sh"   (dir: the folder holding run-jobs.sh)
# The wait on one wave's jobs: one poll for every job the wave started, so each job's own limit
# is checked while any job of the wave runs. A job that passes its limit or fails stops alone: it
# is parked (logged, its process tree killed) and its siblings run on. At the wave's end the
# runner checks and commits the finished jobs, then stops naming the parked ones; they are not in
# done.txt, so a restart runs them again. The STOP file, RUN_MAX_MIN and a failed combined check
# still stop everything (tools/run-jobs.sh's check_stop and checks).
# A job over RUN_TURN_CAP turns whose own run ended with result 0 and a report is accepted (after the runner has
# run its check: suites and its new tests itself, cap_verify) with a
# WARN (its own checks passed; flash.sh's --max-turns stays the hard stop); over the cap with any
# other result it is parked.
# Not run on its own; it reads the runner's globals (B, LOGS, started, pids, since, limits,
# RUN_TURN_CAP, RUN_LIMIT_UNIT_S, RUN_POLL_S) and its note, stop, check_stop, kill_tree, usage,
# run_expected_min and apply_safe helpers, and writes its ok, extra and parked arrays.

job_limit_over() { # job_limit_over <index into started>: 0 when that job passed its own limit
  local i=$1
  [ "${limits[$i]}" -gt 0 ] || return 1
  [ $(($(date +%s) - ${since[$i]})) -ge "${limits[$i]}" ]
}

park() { # park <job>: the job stops alone; its siblings run on and the wave's end stops naming it
  parked+=("$1")
  park_tree "$1"
}

park_keeps() { # park_keeps <job> <path>: 0 when the path stays in the tree, because it was dirty before the wave
  # (the churn snapshot) or another job of this wave lists it in its allow: (a sibling's file is not the parked job's)
  local j=$1 a=$2 o
  grep -qxF -- "$a" "${CHURN_SNAPSHOT:-/dev/null}" 2> /dev/null && return 0
  for o in "${started[@]}"; do
    case " ${parked[*]:-} " in *" $o "*) continue ;; esac # a parked sibling's files are not protected
    [ "$o" = "$j" ] && continue
    sed -n 's/^allow: *//p' "$B/$o.md" 2> /dev/null | tr -d '\r' | sed 's/ *· */\n/g; s:/$::' |
      grep -qxF -- "$a" && return 0
  done
  return 1
}

park_tree() { # park_tree <job>: its allow: files and report leave the tree, saved as $WORK/parked-<job>.patch, so the
  # combined check of its siblings never sees them (wave2-789: parked n8b3, n8e2 and n8e3 broke the siblings' check).
  # A path park_keeps names (dirty before the wave, or a sibling's allow:) stays. A restart runs the job again;
  # a hand-fix copies from the kept worktree (tools/apply-job.sh), not from this patch.
  local j=$1 a rep paths=() kept=() untracked tracked
  while IFS= read -r a; do
    a=${a%/}
    case "$a" in '' | "$B"/*) continue ;; esac # the batch folder is the runner's own (run.log, done.txt)
    paths+=("$a")
  done < <(sed -n 's/^allow: *//p' "$B/$j.md" 2> /dev/null | tr -d '\r' | sed 's/ *· */\n/g')
  rep=$(sed -n 's/^report: *//p' "$B/$j.md" 2> /dev/null | tr -d '\r')
  [ -n "$rep" ] && paths+=("$rep")
  for a in "${paths[@]}"; do park_keeps "$j" "$a" || kept+=("$a"); done
  paths=("${kept[@]}")
  [ ${#paths[@]} -gt 0 ] || return 0
  untracked=$(git ls-files --others --exclude-standard -- "${paths[@]}")
  [ -n "$untracked" ] && printf '%s\n' "$untracked" | xargs -d '\n' git add -N
  git diff --binary HEAD -- "${paths[@]}" > "$WORK/parked-$j.patch"
  git reset -q -- "${paths[@]}"
  [ -s "$WORK/parked-$j.patch" ] || { rm -f "$WORK/parked-$j.patch"; return 0; }
  tracked=$(git diff --name-only HEAD -- "${paths[@]}")
  [ -n "$tracked" ] && printf '%s\n' "$tracked" | xargs -d '\n' git checkout HEAD --
  [ -n "$untracked" ] && printf '%s\n' "$untracked" | xargs -d '\n' rm -f
  note "job $j parked: its files are saved in $WORK/parked-$j.patch and out of the tree (the siblings' check does not see them)"
}

cap_verify() { # cap_verify <job>: the runner's own format/analyze and the job's new tests; 0 when they pass.
  # An over-cap job is never taken on its report's word (f2 of wave2-789 was incomplete).
  local j=$1 suites t pkg cmd out=$WORK/cap-$j.log
  suites=$(sed -n 's/^check: *//p' "$B/$j.md" | head -n 1 | tr -d '\r')
  [ -n "$suites" ] || suites="format analyze"
  # shellcheck disable=SC2086
  tools/check.sh $suites > "$out" 2>&1 || return 1
  while IFS= read -r t; do
    [ -f "$t" ] || continue
    pkg=${t%%/test/*}
    cmd="dart test"; grep -q 'sdk: flutter' "$pkg/pubspec.yaml" 2> /dev/null && cmd="flutter test"
    ( cd "$pkg" && timeout 300 $cmd "${t#"$pkg"/}" ) >> "$out" 2>&1 || return 1
  done < <(sed -n 's/^allow: *//p' "$B/$j.md" | tr -d '\r' | sed 's/ *· */\n/g' | grep '/test/.*_test\.dart$')
  return 0
}

limit_stop() { # limit_stop <index>: park the job, naming its limit and its estimate; its siblings run on
  local i=$1 j
  j=${started[$i]}
  note "job $j passed its limit ($((${limits[$i]} / ${RUN_LIMIT_UNIT_S:-60})) min," \
    "estimate $(run_expected_min "$B/$j.md")) (parked, siblings continue)"
  kill_tree "${pids[$i]}"
  park "$j"
}

turn_cap() { # turn_cap <job> <rc>: the job's turns, from the usage row `usage` reads, against
  # RUN_TURN_CAP or its brief's `turns: <n>` line. Over the cap with result 0 and the job's report:
  # a WARN and 0 (accepted); over the cap with any other result: a park line and 1. No usage row
  # (a stand-in worker): nothing to count.
  local j=$1 rc=$2 t cap
  t=$(usage "$B/$j.md" | sed -n 's/^\([0-9][0-9]*\) turns.*/\1/p')
  [ -n "$t" ] || return 0
  cap=$(sed -n 's/^turns:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$B/$j.md" | head -n 1)
  case $cap in '' | 0) cap=$RUN_TURN_CAP ;; esac
  [ "$t" -gt "$cap" ] || return 0
  if [ "$rc" -eq 0 ] && [ -f "$B/$j-report.md" ]; then
    if cap_verify "$j"; then
      note "WARN: job $j used $t turns, over its cap of $cap (its own checks passed; accepted)"
      return 0
    fi
    note "job $j used $t turns, over its cap of $cap and the runner's own check or tests failed (see $WORK/cap-$j.log) (parked, siblings continue)"
    return 1
  fi
  note "job $j used $t turns, over its cap of $cap (parked, siblings continue)"
  return 1
}

usage_wall() { # usage_wall <job> <index into started>: a usage row of "1 turns, 0 min" for a job that ran many minutes
  # is a session that resumed after a timed-out command: claude's result JSON counts the last resume only (n9b2, n8b3 of
  # wave2-789: 1 logged turn, 25-28 min real). The row cannot be repaired, so the log says so instead of misleading.
  local u m wall
  u=$(usage "$B/$1.md")
  [ -n "$u" ] || return 0
  m=${u##*, }; m=${m% min}
  wall=$((($(date +%s) - ${since[$2]}) / ${RUN_LIMIT_UNIT_S:-60}))
  [ "$wall" -ge 5 ] && [ $((m * 2)) -lt "$wall" ] &&
    note "WARN: $1 logged $u but ran $wall min wall: a resumed session's usage row covers its last resume only, its real turns are unknown"
  return 0
}

finished_job() { # finished_job <index>: wait its exit, log it, cap it, then sort it into ok or parked
  local i=$1 j rc
  j=${started[$i]}
  wait "${pids[$i]}"; rc=$?
  note "$j finished: result $rc ($(usage "$B/$j.md")) $(job_line "$j")"
  usage_wall "$j" "$i"
  # Result 4 with only generated churn outside the list comes first: the churn is dropped and the job's own files are
  # applied, so the cap below judges a result 0 (n9b1, n8c, n8b2, f4 were parked as "over cap" with churn as the only fault).
  if [ $rc -eq 4 ] && apply_safe "$j" "$LOGS/flash-$j.log"; then
    [ -n "$DROPPED" ] && note "$j: dropped generated churn outside its list: $DROPPED"
    [ -n "$APPLIED" ] && note "$j: applied always-fine files outside its list: $APPLIED"
    extra+=($APPLIED); rc=0
  fi
  turn_cap "$j" "$rc" || { park "$j"; return; }
  if [ $rc -eq 0 ] && [ -f "$B/$j-report.md" ]; then ok+=("$j")
  else note "job $j parked (result $rc); its siblings continue"; park "$j"; fi
}

wave_wait() { # wave_wait: the poll on every started job: each job's limit, the STOP file, then its exit
  local pending=("${!pids[@]}") i rest
  while [ ${#pending[@]} -gt 0 ]; do
    check_stop
    rest=()
    for i in "${pending[@]}"; do
      if job_limit_over "$i"; then limit_stop "$i"; else rest+=("$i"); fi # a parked job is not waited for
    done
    pending=("${rest[@]}")
    rest=()
    for i in "${pending[@]}"; do
      if kill -0 "${pids[$i]}" 2>/dev/null; then rest+=("$i"); else finished_job "$i"; fi
    done
    pending=("${rest[@]}")
    [ ${#pending[@]} -gt 0 ] && sleep "${RUN_POLL_S:-5}"
  done
}

job_line() { # job_line <job>: `model <id>, ladder <n>, tokens in/read/write/out <a>/<b>/<c>/<d>` for run.log
  # model: the brief's `model:` line (haiku default, or sonnet) or CLAUDE_WORKER_MODEL; ladder: the brief's
  # `ladder: <n>` line, else 2 when it carries a `repair:` note, else 1; tokens: the job's flash usage row.
  local f=$B/$1.md m lv tok
  m=$(sed -n 's/^model: *//p' "$f" | head -n 1 | tr -d '\r')
  case $m in sonnet) m=claude-sonnet-5-5 ;; haiku) m=claude-haiku-5-5 ;; '') m=${CLAUDE_WORKER_MODEL:-claude-haiku-5-5} ;; esac
  [ "${WORKER:-}" = claude ] || m=${FLASH_MODEL:-flash}
  lv=$(sed -n 's/^ladder: *\([0-9][0-9]*\).*/\1/p' "$f" | head -n 1)
  [ -n "$lv" ] || { grep -q '^repair:' "$f" && lv=2 || lv=1; }
  tok=$(awk -F'\t' -v b="$f" 'index($10, b){t=$5"/"$6"/"$7"/"$8} END{print t}' "${FLASH_USAGE_LOG:-$HOME/.thumbparty/flash-usage.tsv}" 2>/dev/null)
  echo "model $m, ladder $lv, tokens in/read/write/out ${tok:-n/a}"
}

pause_after_wave() { # pause_after_wave <n>: RUN_PAUSE_AFTER_WAVE=1 stops (a clean pause) after every wave but the last
  # Its review is committed first (stop waits for it). The driver verdicts the findings, writes the must-fix ones as a
  # fix job `f<n>` in the NEXT wave of waves.txt (files no later job allows), commits, and restarts (docs/driver-kit.md 6b).
  [ "${RUN_PAUSE_AFTER_WAVE:-}" = 1 ] && [ "$1" -lt "${#WAVES[@]}" ] || return 0
  stop "PAUSED after wave $1 (RUN_PAUSE_AFTER_WAVE=1): its review is committed; verdict it, add fix jobs to the next wave of waves.txt, commit, restart"
}

# 3b. A finished job leaves no debug code (tools/debug-leftovers.sh): BISECT markers, debug early returns, prints in tests.
leftovers() { # leftovers <job>...
  local out
  [ -f tools/debug-leftovers.sh ] || return 0
  out=$(bash tools/debug-leftovers.sh 2>&1) && return 0
  finding "debug leftovers after $*: $(grep -m3 ^FAIL <<< "$out" | tr '\n' ';')"
  stop "debug leftovers in the wave's added Dart lines ($(grep -c ^FAIL <<< "$out") found; run tools/debug-leftovers.sh); nothing of this wave is committed"
}
