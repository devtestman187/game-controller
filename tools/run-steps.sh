#!/usr/bin/env bash
# Sourced by tools/run-jobs.sh, after it has cd'd to the repo root:
#   . "$dir/run-steps.sh"   (dir: the folder holding run-jobs.sh)
# The steps the runner takes between a job's start and its commit. Not run on its
# own; it reads the runner's globals (B, WORK, CHURN_OUTSIDE, SAFE_OUTSIDE,
# SIZE_STOP) and its note, finding, stop, unchurn and committed helpers.

# 2. A job that stopped with result 4: outside files that are generated churn are
# dropped (logged), always-fine ones are applied; any other file stops the job.
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
