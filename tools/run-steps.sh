#!/usr/bin/env bash
# Sourced by tools/run-jobs.sh, after it has cd'd to the repo root:
#   . "$dir/run-steps.sh"   (dir: the folder holding run-jobs.sh)
# The steps the runner takes between a job's start and its commit, and its stop
# helpers (STOP.md, the time limit and the lock). Not run on its own; it reads the
# runner's globals (B, WORK, CHURN_OUTSIDE, SAFE_OUTSIDE, SIZE_STOP, RUN_MAX_MIN,
# RUN_START_S) and its note, finding, stop, unchurn, committed and kill_tree helpers.
# The combined check runs under the limits of tools/run-limits.sh (sourced below).

# The per-step limits and their helpers. A folder holding only the runner's files, as the
# copies in tools/tests/run-wire-test.sh do, has no run-limits.sh: the check keeps no limit of
# its own there, as it had none before the limits existed.
if [ -n "${dir:-}" ] && [ -f "$dir/run-limits.sh" ]; then . "$dir/run-limits.sh"; fi
[ -f "${BASH_SOURCE[0]%/*}/run-scope.sh" ] && . "${BASH_SOURCE[0]%/*}/run-scope.sh"
# 2. A job that stopped with result 4: outside files that are generated churn are
# dropped (logged), always-fine ones are applied; any other file stops the job.
outside_files() { awk '/CHANGED FILES OUTSIDE/{on=1;next} /^---- flash:/{on=0} on&&/^  /{print $1}' "$1"; }
copy_paths() { # copy_paths <tree> <path>...: the kept worktree's version of each path, a deletion included
  local tree=$1 p
  shift
  for p in "$@"; do
    if [ -d "$tree/$p" ]; then mkdir -p "$p" && cp -R "$tree/$p/." "$p/" || return 1
    elif [ -e "$tree/$p" ]; then mkdir -p "$(dirname "$p")" && cp -f "$tree/$p" "$p" || return 1
    elif git -C "$tree" cat-file -e "HEAD:$p" 2>/dev/null; then rm -f "$p" || return 1 # the job deleted it
    fi
  done
}
apply_safe() { # apply_safe <job> <flash-log>; sets DROPPED and APPLIED, returns 0 when applied
  local log=$2 files tree f ex=() want=() a patch all_churn=1
  DROPPED="" APPLIED=""
  files=$(outside_files "$log")
  tree=$(sed -n 's/.*the worktree is kept: //p' "$log" | tail -n 1)
  [ -n "$files" ] && [ -d "$tree" ] || return 1
  for f in $files; do
    if [[ $f =~ $CHURN_OUTSIDE ]]; then DROPPED+="$f "; ex+=(":(exclude,literal)$f")
    elif [[ $f =~ $SAFE_OUTSIDE ]]; then APPLIED+="$f "; all_churn=0
    else return 1; fi
  done
 # only the job's own paths, once each: allow:, report:, and the always-fine files
  while IFS= read -r a; do
    a=${a%/}
    [ -n "$a" ] || continue
    case " ${want[*]:-} " in *" $a "*) continue ;; esac
    want+=("$a")
  done < <(sed -n 's/^\(allow\|report\): *//p' "$B/$1.md" | sed 's/ *· */\n/g')
  for f in $APPLIED; do
    case " ${want[*]:-} " in *" $f "*) continue ;; esac
    want+=("$f")
  done
  [ ${#want[@]} -gt 0 ] || return 1
  patch=$WORK/run-$1.patch
  if ! ( cd "$tree" && git ls-files --others --exclude-standard -- "${want[@]}" | xargs -r git add -N &&
    git diff --binary HEAD -- "${want[@]}" "${ex[@]}" ':(exclude,glob)tv_test_app/windows/flutter/**' ':(exclude,glob)site/shots/**' \
      ':(exclude,glob)**/run-base*' ':(exclude,glob)docs/briefs/**/run-*.patch' ) > "$patch"; then
    : > "$patch" # a failed diff leaves the copy below to bring the files over
  fi
  if [ ! -s "$patch" ] || ! git apply --3way "$patch" >/dev/null 2>&1; then
    # s6b2's stop: with only generated churn outside, an empty or unappliable patch keeps the job's
    # own files in the kept worktree alone, so they are copied over and the churn is left behind
    [ $all_churn -eq 1 ] || return 1
    copy_paths "$tree" "${want[@]}" || return 1
    note "$1: the patch was empty or did not apply (only generated churn outside its list);" \
      "copied its own paths from the kept worktree: ${want[*]}"
  fi
  git reset -q; git worktree remove --force "$tree" 2>/dev/null
  return 0
}

# 3. New test files must fail on the code as it was.
tests_first() { # tests_first <job>...
  local tests t pkg cmd tmp=$WORK/old-$$ j a ex=() bad=() base=HEAD
  # TF_COMMIT=<sha> (a job committed by hand): its new test files are proved against <sha>^
  for j in "$@"; do
    grep -qE '^tests-first: *exempt +[^ ]' "$B/$j.md" || continue
    for a in $(sed -n 's/^allow: *//p' "$B/$j.md" | tr '·' ' '); do ex+=("$a"); done
  done
  if [ -n "${TF_COMMIT:-}" ]; then base=$TF_COMMIT^; tests=$(git diff --name-only --diff-filter=A "$base" "$TF_COMMIT" -- '*_test.dart')
  else tests=$(git ls-files --others --exclude-standard -- '*_test.dart'); fi
  [ -n "$tests" ] || return 0
  git worktree add --detach -q "$tmp" "$base" 2>/dev/null || { finding "tests-first could not be checked (no temporary folder)"; return 0; }
  ( cd "$tmp" && flutter pub get >/dev/null 2>&1 )
  for t in $tests; do
    pkg=${t%%/test/*}
    mkdir -p "$tmp/$(dirname "$t")"
    if [ -n "${TF_COMMIT:-}" ]; then git show "$TF_COMMIT:$t" > "$tmp/$t"; else cp "$t" "$tmp/$t"; fi
    cmd="dart test"; grep -q 'sdk: flutter' "$pkg/pubspec.yaml" 2>/dev/null && cmd="flutter test"
    if ! ( cd "$tmp/$pkg" && timeout 300 $cmd "${t#"$pkg"/}" >/dev/null 2>&1 ); then
      note "tests-first ok: $t fails on the old code"
    else
      exempt=0
      for a in "${ex[@]}"; do case "$t" in "$a"*) exempt=1 ;; esac; done
      if [ $exempt -eq 1 ]; then note "tests-first: $t passes on the old code, exempt by its brief"
      else bad+=("$t"); finding "tests-first: $t passes on the old code, so it does not prove new behaviour"; fi
    fi
  done
  git worktree remove --force "$tmp" 2>/dev/null
  [ ${#bad[@]} -eq 0 ] || stop "tests-first: ${bad[*]} pass on the old code (write them to fail first, or add 'tests-first: exempt <reason>' to the brief for a pure refactor); nothing of this wave is committed"
}

# 4. The checks, with one self-repair for a failing suite (but never for format or analyze),
# then the guideline checker. tools/check.sh runs in the background, so the STOP file and the
# time limits are seen while it works (a wave whose check took 40 min unseen was a wave-1
# defect); its own limit ends it with a stop naming the limit.
check_once() { # check_once: tools/check.sh with the runner's fail-fast on, watched while it runs
  # watched for the STOP file, RUN_MAX_MIN (check_stop) and RUN_CHECK_MAX_MIN; returns check.sh's own exit code.
  local pid start limit_s=${RUN_CHECK_MAX_MIN:-0} poll_s=${RUN_POLL_S:-1}
  [ "$limit_s" -gt 0 ] && limit_s=$((limit_s * RUN_LIMIT_UNIT_S))
  CHECK_SKIP="${RUN_CHECK_SKIP:-}" CHECK_FAIL_FAST=1 tools/check.sh > "$WORK/run-check.log" 2>&1 &
  pid=$!
  start=$(date +%s)
  while kill -0 "$pid" 2> /dev/null; do
    if [ "$limit_s" -gt 0 ] && [ $(($(date +%s) - start)) -ge "$limit_s" ]; then
      kill_tree "$pid"
      wait "$pid" 2> /dev/null
      stop "CHECK TIMEOUT: the combined check passed RUN_CHECK_MAX_MIN=$RUN_CHECK_MAX_MIN min and was killed" \
        "(see $WORK/run-check.log); nothing of this wave is committed"
    fi
    check_stop # RUN_MAX_MIN or the STOP file: its stop kills this shell's background children
    sleep "$poll_s"
  done
  wait "$pid"
}
checks() {
  unchurn
  declare -F check_scope > /dev/null && check_scope # tools/run-scope.sh
  if ! check_once; then
    # A failed format or analyze check is the tree's own state: no retry can fix it.
    local bad
    bad=$(awk '$1 == "FAIL" && ($2 == "format" || $2 == "analyze") { print $2; exit }' "$WORK/run-check.log")
    if [ -n "$bad" ]; then
      stop "checks failed on the combined tree after $*: ${bad% } cannot be fixed by a retry" \
        "(see $WORK/run-check.log); nothing of this wave is committed"
    fi
    # A temp-folder race in a test (PathNotFoundException) is retried once, and only that.
    if grep -q PathNotFoundException "$WORK/run-check.log"; then
      note "check retry: PathNotFoundException in the failed suite (temp-folder race); running the checks once more"
      cp "$WORK/run-check.log" "$WORK/run-check-first.log"; unchurn
      check_once || stop "checks failed after the PathNotFoundException retry on the combined tree after $*" \
        "(see $WORK/run-check.log); nothing of this wave is committed"
    else
      note "checks failed; fetching packages and trying once more"
      flutter pub get > "$WORK/run-pub.log" 2>&1; unchurn
      check_once || stop "checks failed twice on the combined tree after $*" \
        "(see $WORK/run-check.log); nothing of this wave is committed"
    fi
  fi
  unchurn
  git ls-files --others --exclude-standard | xargs -r git add -N
  tools/review.sh > "$WORK/run-review.log" 2>&1
  [ $? -eq 1 ] && stop "tools/review.sh found a FAIL after $* (see $WORK/run-review.log); nothing of this wave is committed"
  local big=$(awk -v max=$SIZE_STOP '$1=="NOTE"&&$2=="size"&&$4+0>max{print $3" ("$4" lines)"}' "$WORK/run-review.log" | grep '/lib/' | tr '\n' ' ')
  git reset -q
  [ -n "$big" ] && stop "a touched lib file is over $SIZE_STOP lines and must be split: $big; nothing of this wave is committed"
  return 0
}

# Brief header `dart-fix: <packages>`: run `dart fix --apply` in each package before the job's checks (logged).
dart_fix() { # dart_fix <job>...
  local j p pk out
  for j in "$@"; do
    pk=$(sed -n 's/^dart-fix: *//p' "$B/$j.md" | head -n 1 | tr -d '\r' | tr '·,' '  ')
    for p in $pk; do
      p=${p%/}
      [ -f "$p/pubspec.yaml" ] || { finding "$j: dart-fix package $p has no pubspec.yaml; skipped"; continue; }
      out=$( cd "$p" && dart fix --apply 2>&1 ); rc=$?
      printf '%s\n' "$out" >> "$WORK/run-dartfix.log"
      if [ $rc -eq 0 ]; then note "dart fix --apply in $p for $j: $(printf '%s\n' "$out" | grep -E 'Applied|Nothing to fix' | tail -n 1)"
      else finding "$j: dart fix --apply failed in $p (see $WORK/run-dartfix.log); the checks decide"; fi
    done
  done
}
# Brief header `ci-patch: <patch file>`: a patch for .github/ or codemagic.yaml (workers may not edit them).
# After the job's checks pass the runner applies it (git apply --check, then git apply), logs it, and
# tools/commit-job.sh puts the patch file and the files it changes into the job's commit.
ci_patch() { # ci_patch <job>
  local j=$1 pf bad
  pf=$(sed -n 's/^ci-patch: *//p' "$B/$j.md" | head -n 1 | tr -d '\r')
  [ -n "$pf" ] || return 0
  [ -f "$pf" ] || stop "$j: ci-patch $pf does not exist; nothing of this wave is committed"
  committed "$pf" || stop "$j: ci-patch $pf is not committed (commit it with the brief); nothing of this wave is committed"
  bad=$(git apply --numstat "$pf" 2>/dev/null | cut -f3 | grep -Ev '^(\.github/|codemagic\.yaml$)' | tr '\n' ' ')
  [ -z "$bad" ] || stop "$j: ci-patch $pf touches files other than .github/ and codemagic.yaml: $bad; nothing of this wave is committed"
  if git apply --check "$pf" 2>"$WORK/run-cipatch.log"; then
    git apply "$pf" 2>>"$WORK/run-cipatch.log" || stop "$j: git apply of ci-patch $pf failed (see $WORK/run-cipatch.log); nothing of this wave is committed"
    note "ci-patch applied for $j: $pf ($(git apply --numstat "$pf" | cut -f3 | tr '\n' ' '))"
  elif git apply --check -R "$pf" 2>/dev/null; then note "ci-patch for $j already applied: $pf"
  else stop "$j: git apply --check refused ci-patch $pf (see $WORK/run-cipatch.log); nothing of this wave is committed"; fi
}

# The stop report, the run's own time limit and the one-runner lock. The runner calls
# these from its stop, check_stop and start; they read its globals (B, WORK, RUN_MAX_MIN,
# RUN_START_S) and its note, finding and stop helpers.

save_stop() { # save_stop <message>: the log, STOP.md when this stop left one, and the findings
  local paths=("$B/run.log")
  [ -f "$B/STOP.md" ] && paths+=("$B/STOP.md")
  [ -f "$B/run-findings.md" ] && paths+=("$B/run-findings.md") # e.g. "STOP.md was not written"
  save "$1" "${paths[@]}"
}

lint_stop() { # lint_stop: brief_lint failed: STOP.md, the log, exit 1 (a dry run only prints)
  write_stop "brief lint: a brief's report: line is not exactly one bare path (the LINT lines above name it)"
  save_stop "runner: log at a stop"
  exit 1
}

clear_last_stop() { # clear_last_stop: the last stop's STOP.md goes at a new start, its removal committed
  [ -f "$B/STOP.md" ] || return 0
  rm -f "$B/STOP.md"
  note "removed the last stop's STOP.md"
  committed "$B/STOP.md" && save "runner: removal of the last stop's STOP.md" "$B/STOP.md"
}

write_stop() { # write_stop <cause> [flash-log]: <batch>/STOP.md now, while the cause is fresh
  local log=${2:-}
  if [ -n "$log" ] && [ -f "$log" ]; then
    bash tools/run-stop.sh "$B" "$WORK" "$1" "$log" > "$WORK/run-stop.log" 2>&1
  else
    bash tools/run-stop.sh "$B" "$WORK" "$1" > "$WORK/run-stop.log" 2>&1
  fi || finding "STOP.md was not written (see $WORK/run-stop.log); the stop stands anyway"
}

time_check() { # time_check: past RUN_MAX_MIN the run stops itself, so a person can look
  local limit=$((RUN_MAX_MIN * 60)) elapsed
  elapsed=$(($(date +%s) - RUN_START_S))
  [ "$elapsed" -ge "$limit" ] || return 0
  stop "TIMEOUT: the run passed RUN_MAX_MIN=$RUN_MAX_MIN min (counted from the last 'start at' line in run.log); a person should look at $B/run.log before more code is written"
}

lock_remove() { # lock_remove: the lock goes at the exit, and only when it holds this run's pid
  [ "$(cat "$WORK/lock" 2>/dev/null)" = "$$" ] || return 0
  rm -f "$WORK/lock"
}

lock_take() { # lock_take: one runner per batch; a second exits 2, a lock whose pid is gone is replaced
  local pid=""
  [ -f "$WORK/lock" ] && pid=$(cat "$WORK/lock" 2>/dev/null)
  if [ -n "$pid" ] && [ "$pid" != "$$" ] && kill -0 "$pid" 2>/dev/null; then
    echo "RESULT: refused, a run is active (pid $pid)"
    exit 2
  fi
  [ -n "$pid" ] && note "replaced a stale lock (pid $pid is gone)"
  # The traps go in before the lock is written, so a signal in between cannot leave it behind.
  # A signal ends the run (130 on INT, 143 on TERM) with further signals off, as tools/selftest.sh does.
  trap lock_remove EXIT
  trap 'trap "" INT TERM; exit 130' INT
  trap 'trap "" INT TERM; exit 143' TERM
  echo "$$" > "$WORK/lock" || { echo "RESULT: FAILED: cannot write the lock $WORK/lock" >&2; exit 2; }
}
