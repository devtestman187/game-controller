#!/usr/bin/env bash
# The unattended job runner for flash-worker (low-usage mode). It runs a folder
# of briefs in waves, checks and commits each job, has a second cheap worker
# review each job and then the whole run, and stops only when a person or
# Claude is truly needed. The framework is described in docs/flash-framework.md.
#
#   tools/run-jobs.sh <briefs-dir> [--logs <dir>] [--no-review] [--dry-run]
#   tools/run-jobs.sh <briefs-dir> --drop <job>   (never run <job>; appends to dropped.txt)
#   touch <briefs-dir>/STOP   (stops a running runner between steps; never kill it)
#
# <briefs-dir>/waves.txt: one wave per line, job names (brief files without
# .md) separated by spaces; `#` starts a comment. Jobs of one wave run at the
# same time (at most 3) and must share no files.
#
# For each wave:
#   1. start the jobs (tools/flash.sh --brief); a job listed in <briefs-dir>/done.txt
#      (`<job> <sha>`, written after its commit; older batches without a done.txt: a
#      committed report) or in dropped.txt is skipped, so the runner is safe to start again;
#   2. a job that stopped with result 4 (files outside its allow: list): known
#      generated churn (CHURN_OUTSIDE below: library and m13 PNGs, site/shots,
#      run-base, tv plugin files, stray run-*.patch) is dropped, one log line
#      per job; always-fine files (SAFE_OUTSIDE: analysis_options, .gitignore,
#      .gitattributes, pubspec.lock) are applied; any other file is a stop;
#   3. new test files are run against the old code: one that passes there was
#      not written test-first and STOPS the run, unless the job's brief has a
#      line `tests-first: exempt <reason>` (pure refactors, docs) and the test
#      lies under one of its allow: paths;
#   4. tools/check.sh on the combined tree (packages are fetched and the check
#      is tried once more before giving up), then tools/review.sh: any FAIL, or
#      a touched lib file over SIZE_STOP lines, stops the run;
#   5. each job is committed and pushed (tools/commit-job.sh --push);
#   6. a reviewer job per committed job writes <job>-review-report.md. Reviews run
#      in the background while the next wave works (at most 3 flash jobs in all,
#      the review chain counting as one); their report files are committed at the
#      next serial point (after the next wave commit), staging only those files.
# At the end one more worker job reads everything since the run's first commit
# and writes <briefs-dir>/REVIEW.md; Claude reads its Summary and writes one
# fix brief. Progress and stops: <briefs-dir>/run.log (a STOPPED line with no
# later `start at` line needs attention).
# Working files (run-base, run-check.log, run-review.log, run-commit.log, patches,
# markers) live in .dart_tool/run-jobs/<briefs-dir name> (gitignored), never in the
# briefs dir; RUN_WORK overrides. run-base is set once, at the batch's first start
# (also logged in run.log as `run-base <sha>`, so a fresh clone can recover it).
# run.log IS committed (force-added) at every serial point, at a stop and at the
# end, so STOPPED, HAND-FIX and final-check lines survive. A job committed by hand
# after a stop is marked by a `HAND-FIX <job>: <what>` line in run.log (or a file
# <briefs-dir>/<job>-handfixed, or a `Hand-fixed:` line in the commit message);
# on a restart the runner logs a WARN and runs that job's tests-first proof and
# worker review instead of skipping it. Review jobs drop generated churn too.
# The patch taken from a result-4 job's kept folder holds only the brief's allow:
# and report: paths plus the always-fine files (a folder cut from a dirty tree
# also carries stray edits, which made `git apply` fail on a fix job).
# Before the first wave a preflight (tools/flash.sh --preflight, a tiny real worker call) must show the
# worker can run flutter and tools/check.sh; PREFLIGHT_SKIP=1 skips it. A suite that fails with
# PathNotFoundException (temp-folder race) is retried once, logged as "check retry".
# STOP file: <briefs-dir>/STOP is checked before each wave, job start, review and commit; when
# present the runner kills its child processes, logs `STOPPED: stop file` and exits 1; the file
# is removed at the next start. Never revert a job's commits without `--drop <job>` first.
# NO_PUSH=1 in the environment commits without pushing.
# Exit code: 0 done, 1 stopped, 2 bad use.
set -u
unset CHECK_ANALYZE_PKGS # the runner always analyzes the whole workspace (flash.sh scopes the workers' own analyze)
cd "$(dirname "$0")/.." || exit 2
# Files outside a job's allow: list that are applied and committed (always fine).
SAFE_OUTSIDE='^(([^/]+/)*analysis_options\.yaml|\.gitignore|\.gitattributes|([^/]+/)*pubspec\.lock)$'
# Known generated churn outside the list: dropped (never copied), logged per job.
CHURN_OUTSIDE='^(docs/design/([^/]+/)*[^/]+\.png|site/shots/.*|([^/]+/)*run-base[^/]*|([^/]+/)*tv_test_app/windows/flutter/.*|([^/]+/)*generated_plugin[^/]*|docs/briefs/([^/]+/)*run-[^/]*\.patch)$'
SIZE_STOP=380
CHURN=(tv_test_app/windows/flutter/ site/shots/ docs/design/puzzles/ docs/design/m13-placed-look.png docs/design/m13-puzzles.png docs/design/m13-puzzles-night.png)

B="" LOGS="" review=1 dry=0 drop=""
while [ $# -gt 0 ]; do
  case "$1" in
    --logs) LOGS=${2:?}; shift 2 ;;
    --no-review) review=0; shift ;;
    --dry-run) dry=1; shift ;;
    --drop) drop=${2:?}; shift 2 ;;
    -h|--help) sed -n '2,58p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
    *) B=${1%/}; shift ;;
  esac
done
if [ -n "$drop" ] && [ -n "$B" ] && [ -d "$B" ]; then
  echo "$drop" >> "$B/dropped.txt"; echo "dropped $drop: $B/dropped.txt (commit it)"; exit 0
fi
[ -n "$B" ] && [ -f "$B/waves.txt" ] || { echo "Usage: tools/run-jobs.sh <briefs-dir> (it needs <briefs-dir>/waves.txt)" >&2; exit 2; }
LOGS=${LOGS:-$B}
WORK=${RUN_WORK:-.dart_tool/run-jobs/${B//\//_}}
mkdir -p "$WORK"
mapfile -t WAVES < <(sed 's/#.*//' "$B/waves.txt" | awk 'NF')

note() { echo "$(date '+%F %T') $*" | tee -a "$B/run.log"; }
kill_tree() { local c; for c in $(ps -ef 2>/dev/null | awk -v p="$1" '$3==p{print $2}'); do kill_tree "$c"; done; kill "$1" 2>/dev/null; }
check_stop() { # the STOP file: kill the children, log, exit
  [ -f "$B/STOP" ] || return 0
  local p; for p in $(jobs -p); do kill_tree "$p"; done
  note "STOPPED: stop file"; wait 2>/dev/null; save "runner: log at a stop" "$B/run.log"; exit 1
}
handfixed() { # handfixed <job>: was its commit made by hand after a stop?
  [ -f "$B/$1-handfixed" ] && return 0
  # only the job named right after "HAND-FIX " counts, never a free-text mention of it
  grep -qE "(^|[^A-Za-z0-9_-])HAND-FIX $1:" "$B/run.log" 2>/dev/null && return 0
  git log -1 --format=%B -- "$B/$1-report.md" | grep -qi '^Hand-fixed:'
}
is_done() { # is_done <job>: in done.txt; no done.txt (older batch): report committed at HEAD
  if [ -f "$B/done.txt" ]; then
    grep -q "^$1 " "$B/done.txt" && return 0
    handfixed "$1" && committed "$B/$1-report.md"; return
  fi
  committed "$B/$1-report.md"
}
is_dropped() { grep -qxF "$1" "$B/dropped.txt" 2>/dev/null; }
stop() { note "STOPPED: $*"; wait; flush_reviews; save "runner: log at a stop" "$B/run.log"; exit 1; }
finding() { echo "- $*" >> "$B/run-findings.md"; note "finding: $*"; }
usage() { # usage <brief path>: the job's turns and minutes, from the flash usage log
  awk -F'	' -v b="$1" 'index($10, b){t=$3; m=$4/60} END{if(t) printf "%d turns, %.0f min", t, m}' "${FLASH_USAGE_LOG:-$HOME/.thumbparty/flash-usage.tsv}" 2>/dev/null
}
committed() { git cat-file -e "HEAD:$1" 2>/dev/null; }
unchurn() { git checkout -- "${CHURN[@]}" 2>/dev/null; }
save() { # save <message> <path>...: commit and push just these paths
  local msg=$1; shift
  git reset -q; git add -f -- "$@" 2>/dev/null
  git diff --cached --quiet && return 0
  git commit -q -m "$msg" && { [ -n "${NO_PUSH:-}" ] || git push -q origin "HEAD:refs/heads/$(git rev-parse --abbrev-ref HEAD)"; }
}

if [ $dry -eq 1 ]; then
  n=0
  for wave in "${WAVES[@]}"; do
    n=$((n + 1)); echo "wave $n:"
    for j in $wave; do
      [ -f "$B/$j.md" ] || { echo "  $j: MISSING $B/$j.md"; continue; }
      if is_dropped "$j"; then echo "  $j: skip (dropped)"; elif is_done "$j"; then echo "  $j: skip (committed)"; else echo "  $j: run"; fi
    done
  done
  echo "then: the run's review -> $B/REVIEW.md"; exit 0
fi

# 2. A job that stopped with result 4: outside files that are generated churn are
# dropped (logged), always-fine ones are applied; any other file stops the job.
DROPPED="" APPLIED=""
outside_files() { awk '/CHANGED FILES OUTSIDE/{on=1;next} /^---- flash:/{on=0} on&&/^  /{print $1}' "$1"; }
apply_safe() { # apply_safe <job> <flash-log>; sets DROPPED and APPLIED, returns 0 when applied
  local log=$2 files tree f ex=()
  DROPPED="" APPLIED=""
  files=$(outside_files "$log")
  tree=$(sed -n 's/.*the worktree is kept: //p' "$log" | tail -n 1)
  [ -n "$files" ] && [ -d "$tree" ] || return 1
  for f in $files; do
    if [[ $f =~ $CHURN_OUTSIDE ]]; then DROPPED+="$f "; ex+=(":(exclude,literal)$f")
    elif [[ $f =~ $SAFE_OUTSIDE ]]; then APPLIED+="$f "
    else return 1; fi
  done
 # only the job's own paths: allow:, report:, and the always-fine files
  local want=() a
  while IFS= read -r a; do [ -n "$a" ] && want+=("${a%/}"); done < <(sed -n 's/^\(allow\|report\): *//p' "$B/$1.md" | sed 's/ *· */\n/g')
  for f in $APPLIED; do want+=("$f"); done
  [ ${#want[@]} -gt 0 ] || return 1
  ( cd "$tree" && git ls-files --others --exclude-standard -- "${want[@]}" | xargs -r git add -N &&
    git diff --binary HEAD -- "${want[@]}" "${ex[@]}" ':(exclude,glob)tv_test_app/windows/flutter/**' ':(exclude,glob)site/shots/**' \
      ':(exclude,glob)**/run-base*' ':(exclude,glob)docs/briefs/**/run-*.patch' ) > "$WORK/run-$1.patch" || return 1
  git apply --3way "$WORK/run-$1.patch" >/dev/null 2>&1 || return 1
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

# 4. The checks, with one self-repair, then the guideline checker.
checks() {
  unchurn
  if ! tools/check.sh > "$WORK/run-check.log" 2>&1; then
    # A temp-folder race in a test (PathNotFoundException) is retried once, and only that.
    if grep -q PathNotFoundException "$WORK/run-check.log"; then
      note "check retry: PathNotFoundException in the failed suite (temp-folder race); running the checks once more"
      cp "$WORK/run-check.log" "$WORK/run-check-first.log"; unchurn
      tools/check.sh > "$WORK/run-check.log" 2>&1 || stop "checks failed after the PathNotFoundException retry on the combined tree after $* (see $WORK/run-check.log); nothing of this wave is committed"
    else
      note "checks failed; fetching packages and trying once more"
      flutter pub get > "$WORK/run-pub.log" 2>&1; unchurn
      tools/check.sh > "$WORK/run-check.log" 2>&1 || stop "checks failed twice on the combined tree after $* (see $WORK/run-check.log); nothing of this wave is committed"
    fi
  fi
  unchurn
  git ls-files --others --exclude-standard | xargs -r git add -N
  tools/review.sh > "$WORK/run-review.log" 2>&1
  [ $? -eq 1 ] && stop "tools/review.sh found a FAIL after $* (see $WORK/run-review.log); nothing of this wave is committed"
  local big
  big=$(awk -v max=$SIZE_STOP '$1=="NOTE"&&$2=="size"&&$4+0>max{print $3" ("$4" lines)"}' "$WORK/run-review.log" | grep '/lib/' | tr '\n' ' ')
  git reset -q
  [ -n "$big" ] && stop "a touched lib file is over $SIZE_STOP lines and must be split: $big; nothing of this wave is committed"
  return 0
}

# 6. A second cheap worker reviews one wave (all its jobs together, not one review per job).
RV_NAMES=() RV_RANGES=()   # the jobs (and their commit ranges) the next wave review covers
review_brief() { # review_brief <review-name> <names> <ranges>: the brief for one wave's review
  local j=$1 names=$2 ranges=$3 files="" r briefs="" reports="" n
  for r in $ranges; do files+="$(git diff --name-only "${r%..*}" "${r#*..}") "; done
  files=$(printf '%s\n' $files | sort -u | grep -Ev '^(site/shots/|.*/flutter/generated_)' | tr '\n' ' ')
  for n in $names; do briefs+="$B/$n.md "; reports+="$B/$n-report.md "; done
  sed -e "s|{DIR}|$B|g" -e "s|{JOB}|$j|g" -e "s|{NAMES}|$names|g" -e "s|{BRIEFS}|${briefs% }|g" -e "s|{REPORTS}|${reports% }|g" \
    -e "s|{RANGE}|$ranges|g" -e "s|{FILES}|$files|g" docs/briefs/templates/job-review.md > "$B/$j-review.md"
}
wave_review() { # wave_review <n>: write the review brief of wave <n> from RV_NAMES/RV_RANGES; sets WREV (empty if none)
  WREV=""
  if [ $review -eq 1 ] && [ ${#RV_NAMES[@]} -gt 0 ] && ! committed "$B/wave$1-review-report.md"; then
    review_brief "wave$1" "${RV_NAMES[*]}" "${RV_RANGES[*]}"; WREV="wave$1"
  fi
  RV_NAMES=() RV_RANGES=()
}
# Reviews run in the background while the next wave works (together with that
# wave's jobs at most 3 flash jobs run: see slot_wait). A review's report is
# committed only at a serial point (flush_reviews: after the next wave's commit,
# or the end of the run), staging just the review report files.
review_salvage() { # review_salvage <job> <flash-log>: a review that stopped with result 4 only because of generated churn
  local j=$1 log=$2 files tree f dropped=""
  files=$(outside_files "$log"); tree=$(sed -n 's/.*the worktree is kept: //p' "$log" | tail -n 1)
  [ -n "$files" ] && [ -d "$tree/$B" ] && [ -f "$tree/$B/$j-review-report.md" ] || return 1
  for f in $files; do [[ $f =~ $CHURN_OUTSIDE ]] && dropped+="$f " || return 1; done
  cp "$tree/$B/$j-review-report.md" "$B/$j-review-report.md" || return 1
  git worktree remove --force "$tree" 2>/dev/null
  note "$j-review: dropped generated churn outside its list: $dropped(report kept)"
}
PENDING=()   # jobs whose review was started and whose report is not committed yet
REVPIDS=()   # the background chains' pids
start_reviews() { # start_reviews <job>...: briefs are already committed
  local j
  for j in "$@"; do rm -f "$WORK/run-rev-$j.done"; PENDING+=("$j"); done
  (
    for j in "$@"; do
      tools/flash.sh --brief "$B/$j-review.md" > "$LOGS/flash-$j-review.log" 2>&1
      [ $? -eq 4 ] && review_salvage "$j" "$LOGS/flash-$j-review.log"
      : > "$WORK/run-rev-$j.done"
    done
  ) &
  REVPIDS+=($!)
}
flush_reviews() { # flush_reviews [wait]: commit the reports of reviews that have finished
  local keep=() j p
  if [ "${1:-}" = wait ]; then for p in "${REVPIDS[@]:-}"; do [ -n "$p" ] && wait "$p"; done; REVPIDS=(); fi
  for j in "${PENDING[@]:-}"; do
    [ -n "$j" ] || continue
    [ -f "$WORK/run-rev-$j.done" ] || { keep+=("$j"); continue; }
    rm -f "$WORK/run-rev-$j.done"
    if [ -f "$B/$j-review-report.md" ]; then
      save "review of $j (worker)" "$B/$j-review-report.md"; note "reviewed $j: $(grep -c '^- \*\*' "$B/$j-review-report.md") finding(s)"
    else
      finding "the review of $j wrote no report (see $LOGS/flash-$j-review.log)"
    fi
  done
  PENDING=("${keep[@]:-}")
}
slot_wait() { # at most 3 flash jobs at once, counting the background review chain as one
  while [ "$(jobs -rp | wc -l)" -ge 3 ]; do sleep 5; done
}

handfix_recheck() { # handfix_recheck <job>: the proof and review a hand commit skipped; once per job
  local j=$1 c
  [ -f "$WORK/rechecked-$j" ] && return 0
  grep -q "^$j .* proof\$" "$B/done.txt" 2>/dev/null && return 0 # also survives a fresh clone
  c=$(git log -1 --format=%H -- "$B/$j-report.md")
  note "WARN: $j was committed by hand ($(git rev-parse --short "$c")); a plain restart would skip its tests-first proof and worker review, so both run now"
  TF_COMMIT=$c tests_first "$j"
  # its worker review joins the wave's review (one per wave, not one per hand-fixed job)
  if [ $review -eq 1 ] && ! committed "$B/$j-review-report.md"; then RV_NAMES+=("$j"); RV_RANGES+=("$c^..$c"); fi
  : > "$WORK/rechecked-$j"
  # the marker in done.txt: a restart (or a fresh clone) does not repeat the proof and the review
  echo "$j $c proof" >> "$B/done.txt"; save "runner: proof and review of hand-fixed $j done" "$B/done.txt"
  note "hand-fixed $j: tests-first proof and worker review done (marked in done.txt)"
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

branch=$(git rev-parse --abbrev-ref HEAD)
note "start at $(git rev-parse --short HEAD) on $branch"
[ -f "$B/STOP" ] && { rm -f "$B/STOP"; note "removed the old stop file"; }
if [ ! -s "$WORK/run-base" ]; then # once, at the batch's first start; recovered from run.log on a fresh clone
  sed -n 's/.* run-base \([0-9a-f]\{7,40\}\)$//p' "$B/run.log" 2>/dev/null | head -n 1 > "$WORK/run-base"
  [ -s "$WORK/run-base" ] || { [ -s "$B/run-base" ] && cp "$B/run-base" "$WORK/run-base" || git rev-parse HEAD > "$WORK/run-base"; }
  note "run-base $(cat "$WORK/run-base")"
fi
[ -f .dart_tool/package_config.json ] || { note "fetching packages (new folder)"; flutter pub get > "$WORK/run-pub.log" 2>&1; }
for r in "$B"/*-review-report.md; do # reports of an earlier run that stopped before it could commit them
  [ -f "$r" ] && ! committed "$r" && { save "review report left by an earlier run: $(basename "$r")" "$r"; note "committed the left-over $(basename "$r")"; }
done

# Preflight: a worker that cannot run flutter and tools/check.sh would run blind (bugs10 job 1),
# so one tiny real worker call proves it before any job starts. PREFLIGHT_SKIP=1 skips it.
if [ -z "${PREFLIGHT_SKIP:-}" ]; then
  if tools/flash.sh --preflight > "$WORK/run-preflight.log" 2>&1; then note "preflight ok: the worker ran flutter --version and tools/check.sh --list"
  else stop "preflight failed: the worker cannot run flutter or tools/check.sh in its sandbox, so no job would run tests (see $WORK/run-preflight.log); nothing was started"; fi
fi

wn=0
for wave in "${WAVES[@]}"; do
  wn=$((wn + 1))
  check_stop
  [ "$(wc -w <<< "$wave")" -le 3 ] || stop "a wave has more than 3 jobs: $wave"
  started=() pids=() resumed=()
  for j in $wave; do
    check_stop
    is_dropped "$j" && { note "skip $j (dropped)"; continue; }
    [ -f "$B/$j.md" ] || stop "no brief $B/$j.md"
    committed "$B/$j.md" || stop "the brief $B/$j.md is not committed (job folders are cut from the last commit)"
    if is_done "$j"; then
      if committed "$B/$j-report.md" && handfixed "$j"; then handfix_recheck "$j"; fi
      note "skip $j (already done)"; continue
    fi
    if [ -f "$B/$j-report.md" ]; then note "resume $j (applied by hand, not committed yet)"; resumed+=("$j"); continue; fi
    slot_wait
    [ ${#started[@]} -gt 0 ] && { sleep 25; check_stop; }
    note "start $j"
    tools/flash.sh --brief "$B/$j.md" > "$LOGS/flash-$j.log" 2>&1 &
    pids+=($!) started+=("$j")
  done
  if [ ${#started[@]} -eq 0 ] && [ ${#resumed[@]} -eq 0 ]; then
    # nothing ran; a hand-fixed job rechecked above still gets its worker review (one for the wave)
    wave_review "$wn"
    if [ -n "$WREV" ]; then
      save "runner: log and review brief for hand-fixed jobs of wave $wn" "$B/run.log" "$B/done.txt" "$B/$WREV-review.md"
      check_stop; start_reviews "$WREV"
    fi
    continue
  fi
  ok=("${resumed[@]}") failed=() extra=()
  for i in "${!started[@]}"; do
    j=${started[$i]}
    while kill -0 "${pids[$i]}" 2>/dev/null; do check_stop; sleep 5; done # STOP is seen mid-wave
    wait "${pids[$i]}"; rc=$?
    note "$j finished: result $rc ($(usage "$B/$j.md"))"
    if [ $rc -eq 4 ] && apply_safe "$j" "$LOGS/flash-$j.log"; then
      [ -n "$DROPPED" ] && note "$j: dropped generated churn outside its list: $DROPPED"
      [ -n "$APPLIED" ] && note "$j: applied always-fine files outside its list: $APPLIED"
      extra+=($APPLIED); rc=0
    fi
    if [ $rc -eq 0 ] && [ -f "$B/$j-report.md" ]; then ok+=("$j"); else failed+=("$j:$rc"); fi
  done
  if [ ${#ok[@]} -gt 0 ]; then
    unchurn
    dart_fix "${ok[@]}"
    tests_first "${ok[@]}"
    checks "${ok[*]}"
    for j in "${ok[@]}"; do ci_patch "$j"; done
    reviewed=()
    wave_from=$(git rev-parse HEAD)
    for j in "${ok[@]}"; do
      head -n 40 "$B/$j-report.md" | grep -q '^## Summary' || finding "$j's report has no Summary block in its first 40 lines"
      check_stop
      tools/commit-job.sh "$B/$j.md" $([ -n "${NO_PUSH:-}" ] || echo --push) >> "$WORK/run-commit.log" 2>&1 || stop "commit of $j refused (see $WORK/run-commit.log)"
      note "committed $j: $(git log --oneline -1)"
      echo "$j $(git rev-parse HEAD)" >> "$B/done.txt"
    done
    # one worker review per wave, over all the jobs committed in it (and any hand-fixed job rechecked in it)
    RV_NAMES+=("${ok[@]}"); RV_RANGES+=("$wave_from..$(git rev-parse HEAD)")
    wave_review "$wn"; [ -n "$WREV" ] && reviewed+=("$WREV")
    [ ${#extra[@]} -gt 0 ] && save "files outside the jobs' lists, applied by the runner (always-fine list): ${ok[*]}" "${extra[@]}"
    paths=("$B/run.log" "$B/done.txt"); [ -f "$B/run-findings.md" ] && paths+=("$B/run-findings.md")
    for j in "${reviewed[@]}"; do paths+=("$B/$j-review.md"); done
    save "runner: log and review briefs after ${ok[*]}" "${paths[@]}"
    flush_reviews
    check_stop
    [ ${#reviewed[@]} -gt 0 ] && start_reviews "${reviewed[@]}"
  fi
  [ ${#failed[@]} -gt 0 ] && stop "jobs that failed or need applying by hand: ${failed[*]} (their logs: $LOGS/flash-<job>.log)"
done

flush_reviews wait
check_stop
if [ $review -eq 1 ] && ! committed "$B/REVIEW.md"; then
  base=$(cat "$WORK/run-base")
  files=$(git diff --name-only "$base" HEAD | grep -Ev '^(site/shots/|.*/flutter/generated_|docs/briefs/)' | tr '\n' ' ')
  sed -e "s|{DIR}|$B|g" -e "s|{RANGE}|$base..$(git rev-parse HEAD)|g" -e "s|{FILES}|$files|g" \
    docs/briefs/templates/run-review.md > "$B/run-review.md"
  save "runner: the brief for the run's review" "$B/run-review.md" "$B/run.log"
  note "start the run's review"
  tools/flash.sh --brief "$B/run-review.md" > "$LOGS/flash-run-review.log" 2>&1
  if [ -f "$B/REVIEW.md" ]; then unchurn; save "the run's review (worker)" "$B/REVIEW.md"; else finding "the run's review wrote no REVIEW.md (see $LOGS/flash-run-review.log)"; fi
fi
note "DONE: every job is committed. Claude reads the Summary of $B/REVIEW.md, verifies its findings and writes one fix brief"
paths=("$B/run.log"); [ -f "$B/run-findings.md" ] && paths+=("$B/run-findings.md")
save "runner: log at the end of the run" "${paths[@]}"
