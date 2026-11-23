#!/usr/bin/env bash
# Shared fixture and helpers for the runner's wire tests: run-wire-test.sh and run-wire2-test.sh
# source this file. It is sourced, never run, and calls no exit. Each script sets $tmp and $loc,
# then calls wire_init and run_wire_template (once per script), and every case copies that one
# template repo into a fresh folder, so a case costs a copy instead of a git init and commit.
# The stubs fake tools/flash.sh, check.sh, review.sh, commit-job.sh and run-stop.sh, driven by
# FLASH_MODE and the STUB_* variables, so no worker, test suite or check runs.

# wire_init: the flutter and dart stubs, the fake clock, the default knobs and the result counters
wire_init() {
  fails=0
  cases=0
  out="$tmp/out.txt"
  rc=0
  repo=""
  batch="docs/briefs/fix" # relative: the runner's paths must be repo paths for git
  work=""
  mkdir -p "$tmp/bin" "$tmp/datebin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/flutter"
  cp "$tmp/bin/flutter" "$tmp/bin/dart"
  # A fake clock for the one case that needs time to run out: `date +%s` reads STUB_NOW. It is
  # on PATH only while STUB_NOW is set (a date call of its own is slow in Git Bash).
  real_date=$(command -v date)
  cat > "$tmp/datebin/date" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "+%s" ] && [ -f "\${STUB_NOW:-}" ]; then cat "\$STUB_NOW"; exit 0; fi
exec "$real_date" "\$@"
EOF
  chmod +x "$tmp/bin/flutter" "$tmp/bin/dart" "$tmp/datebin/date"
  FLASH_MODE=plain STUB_CHECK_FAIL=0 STUB_STOP_FAIL=0 PREFLIGHT_SKIP=1 RUN_MAX_MIN=360
  STUB_REVIEW_SLEEP_S="" STUB_FAIL_BRIEF="" STUB_STOP_ON_FAIL=0 STUB_JUMP_S="" STUB_NOW=""
  export FLASH_MODE STUB_CHECK_FAIL STUB_STOP_FAIL PREFLIGHT_SKIP RUN_MAX_MIN
  export STUB_REVIEW_SLEEP_S STUB_FAIL_BRIEF STUB_STOP_ON_FAIL STUB_JUMP_S STUB_NOW
}

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the runner printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

# The five stubs. They lean on the STUB_* variables fixture exports.
stubs() {
  cat > "$repo/tools/flash.sh" <<'EOF'
#!/usr/bin/env bash
echo flash >> "$STUB_MARK"
if [ "${1:-}" = "--preflight" ]; then
  [ "${FLASH_MODE:-}" = preflight ] && touch "$STUB_BATCH/STOP"
  echo "preflight ok (stub)"
  exit 0
fi
brief=${2:-}
write_report() { mkdir -p "$(dirname "$1")"; printf '## Summary\n\nstub report\n' > "$1"; }
review_report() { # review_report: the report a review brief asks for
  case "$(basename "$brief")" in
    run-review.md) echo "$STUB_BATCH/REVIEW.md" ;;
    *) echo "${brief%.md}-report.md" ;;
  esac
}
if [ "${FLASH_MODE:-plain}" = churn ]; then # a kept worktree whose only outside files are generated churn
  git worktree add --detach -q "$STUB_TREE" HEAD || exit 3
  printf 'changed\n' >> "$STUB_TREE/src/app.dart"
  write_report "$STUB_TREE/$STUB_REPORT"
  echo "---- flash: CHANGED FILES OUTSIDE --allow (stub):"
  echo "  site/shots/join.png"
  echo "  $STUB_RESULTS"
  echo "---- flash: the worktree is kept: $STUB_TREE"
  echo "---- flash: result 4"
  exit 4
fi
if [ "${FLASH_MODE:-plain}" = churnfail ]; then # churn only outside, a change of its own, and a patch the repo's own edit makes fail
  git worktree add --detach -q "$STUB_TREE" HEAD || exit 3
  printf 'changed\n' > "$STUB_TREE/src/app.dart"
  mkdir -p "$STUB_TREE/site/shots" && printf 'shot\n' > "$STUB_TREE/site/shots/join.png"
  write_report "$STUB_TREE/$STUB_REPORT"
  echo "---- flash: CHANGED FILES OUTSIDE --allow (stub):"
  echo "  site/shots/join.png"
  echo "---- flash: the worktree is kept: $STUB_TREE"
  echo "---- flash: result 4"
  exit 4
fi
if [ "${FLASH_MODE:-plain}" = churnempty ]; then # churn only outside, no change of its own (the patch is empty), the report in the repo
  git worktree add --detach -q "$STUB_TREE" HEAD || exit 3
  mkdir -p "$STUB_TREE/site/shots" && printf 'shot\n' > "$STUB_TREE/site/shots/join.png"
  write_report "$STUB_REPORT"
  echo "---- flash: CHANGED FILES OUTSIDE --allow (stub):"
  echo "  site/shots/join.png"
  echo "---- flash: the worktree is kept: $STUB_TREE"
  echo "---- flash: result 4"
  exit 4
fi
if [ "${FLASH_MODE:-plain}" = slow ]; then # a job that runs until the case touches $STUB_SLOW_DONE, so the case can signal the runner
  for _ in $(seq 300); do
    [ -f "${STUB_SLOW_DONE:-}" ] && break
    sleep 0.2
  done
  exit 0
fi
if [ -n "${STUB_REVIEW_SLEEP_S:-}" ] && [[ $brief == *-review.md ]]; then # a slow review: mark, sleep, report
  touch "$STUB_REVIEW_START"
  [ -n "${STUB_JUMP_S:-}" ] && echo "$(($(cat "$STUB_NOW") + STUB_JUMP_S))" > "$STUB_NOW"
  sleep "$STUB_REVIEW_SLEEP_S"
  write_report "$(review_report)"; touch "$STUB_REVIEW_DONE"
  exit 0
fi
if [ -n "${STUB_FAIL_BRIEF:-}" ] && [ "$(basename "$brief")" = "$STUB_FAIL_BRIEF" ]; then
  if [ "${STUB_STOP_ON_FAIL:-}" = 1 ]; then # raise the STOP file and stay alive until the runner sees it
    touch "$STUB_BATCH/STOP"
    sleep 30
  fi
  exit 1
fi
case "$brief" in *-review.md) write_report "$(review_report)" ;; *) write_report "$STUB_REPORT" ;; esac
exit 0
EOF
  cat > "$repo/tools/check.sh" <<'EOF'
#!/usr/bin/env bash
if [ "${STUB_CHECK_FAIL:-}" = 1 ]; then
  echo '00:01 +1 -1: test/app_test.dart: works [E]'
  echo '00:01 +1 -1: Some tests failed.'
  exit 1
fi
echo "check ok (stub)"
EOF
  cat > "$repo/tools/review.sh" <<'EOF'
#!/usr/bin/env bash
echo "RESULT: ok: nothing to report (stub)"
EOF
  cat > "$repo/tools/commit-job.sh" <<'EOF'
#!/usr/bin/env bash
git add -A && git commit -q -m "job: $(basename "$1" .md)" && echo "Committed: stub"
EOF
  cat > "$repo/tools/run-stop.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${3:-}" >> "$STUB_STOP_CALLS"
[ "${STUB_STOP_FAIL:-}" = 1 ] && { echo "RESULT: BAD INPUT: stub failure"; exit 3; }
printf 'STOP (stub)\ncause: %s\n' "${3:-}" > "${1%/}/STOP.md"
echo "RESULT: ok: STOP.md written (stub)"
EOF
  chmod +x "$repo"/tools/*.sh
}

# run_wire_template: the one repo every case copies: the runner files, the stubs, src, the batch
# and one commit. It is built in $tmp/template, which no case changes. Returns 1 if git fails.
run_wire_template() {
  repo="$tmp/template"
  mkdir -p "$repo/tools" "$repo/src" "$repo/$batch" "$repo/.dart_tool"
  cp "$loc/tools/run-jobs.sh" "$loc/tools/run-steps.sh" "$loc/tools/run-review.sh" "$loc/tools/churn.sh" \
    "$loc/tools/run-wave.sh" "$repo/tools/"
  stubs
  printf 'base\n' > "$repo/src/app.dart"
  printf '{}\n' > "$repo/.dart_tool/package_config.json"
  printf 'allow: src/app.dart · %s/runjob-report.md\n' "$batch" > "$repo/$batch/runjob.md"
  printf 'report: %s/runjob-report.md\n' "$batch" >> "$repo/$batch/runjob.md"
  printf 'runjob\n' > "$repo/$batch/waves.txt"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name t
  git -C "$repo" add -A
  git -C "$repo" commit -q -m base || return 1
}

fixture() { # fixture <case> [badreport]: a fresh copy of the template repo, a work folder, and the default knobs
  local base="$tmp/$1"
  repo="$base/repo" work="$base/work"
  FLASH_MODE=plain STUB_CHECK_FAIL=0 STUB_STOP_FAIL=0 PREFLIGHT_SKIP=1 RUN_MAX_MIN=360
  STUB_REVIEW_SLEEP_S="" STUB_FAIL_BRIEF="" STUB_STOP_ON_FAIL=0 STUB_JUMP_S="" STUB_NOW=""
  mkdir -p "$base" "$work"
  cp -rp "$tmp/template" "$repo" || return 1
  if [ "${2:-}" = badreport ]; then
    printf 'report: %s/runjob-report.md extra\n' "$batch" >> "$repo/$batch/runjob.md"
    git -C "$repo" commit -q -a -m "badreport brief" || return 1
  fi
  STUB_MARK="$base/flash-ran" STUB_BATCH="$batch" STUB_REPORT="$batch/runjob-report.md"
  STUB_TREE="$base/tree" STUB_RESULTS="$batch/runjob-results.json" STUB_STOP_CALLS="$base/stop-calls"
  STUB_SLOW_DONE="$base/slow-done"
  STUB_REVIEW_START="$base/review-start" STUB_REVIEW_DONE="$base/review-done"
  export STUB_MARK STUB_BATCH STUB_REPORT STUB_TREE STUB_RESULTS STUB_STOP_CALLS STUB_SLOW_DONE
  export STUB_REVIEW_START STUB_REVIEW_DONE
}

run_jobs() { # run_jobs [args]: the runner from the repo root, stubs first on PATH; sets rc and out
  local path="$tmp/bin:$PATH"
  rc=0
  [ -n "${STUB_NOW:-}" ] && path="$tmp/datebin:$path" # only the fake-clock case stubs date
  ( cd "$repo" && PATH="$path" NO_PUSH=1 RUN_WORK="$work" \
    timeout -k 5 60 bash tools/run-jobs.sh "$batch" "$@" ) > "$out" 2>&1 || rc=$?
}
start_jobs() { # start_jobs [args]: the runner in the background (a case signals it); sets runner_pid
  set -m # job control: without it a background bash starts with INT ignored, and its trap never runs
  ( cd "$repo" && PATH="$tmp/bin:$PATH" NO_PUSH=1 RUN_WORK="$work" bash tools/run-jobs.sh "$batch" "$@" ) \
    > "$out" 2>&1 &
  runner_pid=$!
  set +m
}
lock_pid() { # lock_pid: the pid in the runner's lock once it is taken, or nothing after 10 s
  local i
  for i in $(seq 100); do
    [ -s "$work/lock" ] && { cat "$work/lock"; return 0; }
    sleep 0.1
  done
  return 1
}
end_runner() { # end_runner <INT|TERM>: signal the runner ($rid, else its shell), collect its exit in rc;
  # one still alive after 15 s is killed, so a runner that ignores the signal fails the case, not the script
  local i
  kill -"$1" "${rid:-$runner_pid}" 2>/dev/null
  # bash runs the signal's trap when the job's stub returns: release the slow stub now, so a slow start
  # under load cannot leave the runner waiting out the 15 s below (the signal is already pending)
  [ -n "${STUB_SLOW_DONE:-}" ] && touch "$STUB_SLOW_DONE"
  for i in $(seq 150); do
    kill -0 "${rid:-$runner_pid}" 2>/dev/null || break
    sleep 0.1
  done
  kill -0 "${rid:-$runner_pid}" 2>/dev/null && kill -KILL "${rid:-$runner_pid}" 2>/dev/null
  wait "$runner_pid"
  rc=$?
  echo "end_runner $1: runner $rc, lock $(cat "$work/lock" 2>/dev/null)" >> "$out"
}
logged() { grep -qF "$1" "$repo/$batch/run.log" 2>/dev/null; } # logged <text>: run.log has it
more_briefs() { # more_briefs <job>...: a brief per job, one wave per job, committed
  local j
  for j in "$@"; do
    printf 'allow: src/app.dart · %s/%s-report.md\nreport: %s/%s-report.md\n' "$batch" "$j" "$batch" "$j" > "$repo/$batch/$j.md"
  done
  printf '%s\n' "$@" > "$repo/$batch/waves.txt"
  git -C "$repo" add -A && git -C "$repo" commit -q -m "more briefs"
}
seed_report() { # seed_report <job>: its report is on disk, so the runner resumes it (no job run, no 5 s poll)
  printf '## Summary\n\nstub report\n' > "$repo/$batch/$1-report.md"
}
stopmd() { [ -f "$repo/$batch/STOP.md" ] && grep -qF "$1" "$repo/$batch/STOP.md"; } # stopmd <text>
stop_committed() { git -C "$repo" cat-file -e "HEAD:$batch/STOP.md" 2>/dev/null; }
