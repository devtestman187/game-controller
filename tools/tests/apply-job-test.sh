#!/usr/bin/env bash
# Tests tools/apply-job.sh, the one way to hand-apply a stopped job's kept work: inside the
# brief's allow: and report: a modified file, a new untracked file, a deleted file and the
# report are copied byte for byte (a binary too); a file outside allow: and a generated churn
# file are skipped and named; --only outside allow: refuses and copies nothing; --only inside
# applies just that file and names the rest as skipped; a dirty target refuses until --force;
# --dry changes nothing and logs nothing; the run.log HAND-FIX line is exact; --tree wins over
# the log and APPLY_LOGS chooses the log folder; a tree it cannot find refuses; bad use is
# exit 2.
#
#   bash tools/tests/apply-job-test.sh
#
# A temp git repo holds the tool (copied, with the tools/churn.sh it sources) and the job's
# base files; a worktree of it stands in for the kept tree, a second empty one for the cases
# about finding the tree. The batch folder (a brief and flash-<job>.log) is beside them.
# Prints PASS <case> / FAIL <case> (the tool's output indented under a failure) and exits 1
# if any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/apply-job-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the tool printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

# The temp repo, the batch folder and the two trees.
repo=$tmp/repo
batch=$tmp/batch
tree=$tmp/tree
other=$tmp/tree-empty
mkdir -p "$repo/tools" "$repo/lib" "$repo/reports" "$batch"
cp tools/apply-job.sh tools/churn.sh "$repo/tools/"
printf 'a1\n' > "$repo/lib/a.dart"
printf 'b1\n' > "$repo/lib/b.bin"
printf 'c1\n' > "$repo/lib/c.dart"
printf 'r1\n' > "$repo/reports/j1.md"
git -C "$repo" init -q
git -C "$repo" -c user.email=t@example.com -c user.name=t add -A
git -C "$repo" -c user.email=t@example.com -c user.name=t commit -q -m base
printf '%s\n' 'job: j1' 'allow: lib/a.dart · lib/b.bin · lib/c.dart · lib/new.dart' \
  'report: reports/j1.md' > "$batch/j1.md"
printf -- '---- flash: changes NOT applied here; the worktree is kept: %s\n' "$tree" > "$batch/flash-j1.log"
git -C "$repo" worktree add -q --detach "$tree" HEAD
git -C "$repo" worktree add -q --detach "$other" HEAD
# The job's work in the kept tree: a modified file, a binary, a deletion, a new file, the
# report, and two files it must not bring over (one outside allow:, one generated churn).
printf 'a2\n' > "$tree/lib/a.dart"
printf '\000\001\377bin' > "$tree/lib/b.bin"
rm -f "$tree/lib/c.dart"
printf 'new\n' > "$tree/lib/new.dart"
printf 'r2\n' > "$tree/reports/j1.md"
mkdir -p "$tree/notes" "$tree/site/shots"
printf 'mine\n' > "$tree/notes/x.txt"
printf 'shot\n' > "$tree/site/shots/shot.png"
: > "$batch/run.log"

out="$tmp/out.txt"
rc=0
apply() { # apply <args...>: runs the tool from the temp repo copy; sets rc, writes $out
  rc=0
  bash "$repo/tools/apply-job.sh" "$@" > "$out" 2>&1 || rc=$?
}
apply_logs() { # apply_logs <logs dir> <args...>: the same, with APPLY_LOGS set for the tool
  logs=$1
  shift
  rc=0
  APPLY_LOGS="$logs" bash "$repo/tools/apply-job.sh" "$@" > "$out" 2>&1 || rc=$?
}
reset_repo() { # reset_repo: the repo back to its base commit, between cases
  git -C "$repo" reset -q --hard HEAD
  git -C "$repo" clean -qfd
}
content() { [ -f "$1" ] && cat "$1"; } # content <file>: its bytes, empty when missing
lines() { wc -l < "$1" | tr -d ' \r'; } # lines <file>: how many lines it holds
has() { grep -qF -- "$1" "$out"; } # has <text>: $out holds that text
exact() { grep -qxF -- "$1" "$out"; } # exact <line>: $out has exactly that line

# 1. The whole job inside allow: and the report: applied, the two other files left behind.
apply "$batch" j1
r=1
if [ "$rc" = 0 ] && [ "$(content "$repo/lib/a.dart")" = a2 ] &&
  cmp -s "$tree/lib/b.bin" "$repo/lib/b.bin" &&
  cmp -s "$tree/lib/new.dart" "$repo/lib/new.dart" &&
  [ ! -e "$repo/lib/c.dart" ] &&
  [ "$(content "$repo/reports/j1.md")" = r2 ] &&
  [ ! -e "$repo/notes/x.txt" ] && [ ! -e "$repo/site/shots/shot.png" ] &&
  exact 'applied 5 files:' && exact '  lib/c.dart (deleted)' &&
  exact 'SKIPPED outside allow: notes/x.txt' && exact 'SKIPPED churn: site/shots/shot.png' &&
  has 'next: run tools/review.sh and the job'; then
  r=0
fi
report "changed, new, deleted and report files inside allow: are applied; outside allow: and churn are skipped" "$r"

# 2. The one line docs/flash-digest.md asks for, once, with the applied paths in order.
want='HAND-FIX j1: apply-job.sh applied 5 files: lib/a.dart, lib/b.bin, lib/c.dart, lib/new.dart, reports/j1.md'
if grep -qxF -- "$want" "$batch/run.log" && [ "$(lines "$batch/run.log")" = 1 ]; then
  r=0
else
  r=1
  cat "$batch/run.log" >> "$out" # what was logged instead
fi
report "run.log gets the exact HAND-FIX line, once, with the paths applied" "$r"

# 3. A --only path outside the brief's allow: and report: refuses the run before it copies.
reset_repo
before=$(lines "$batch/run.log")
apply "$batch" j1 --only notes/x.txt
if [ "$rc" = 1 ] && [ "$(content "$repo/lib/a.dart")" = a1 ] && [ ! -e "$repo/lib/new.dart" ] &&
  [ "$(lines "$batch/run.log")" = "$before" ] && has 'is outside j1'; then r=0; else r=1; fi
report "--only outside allow: is refused (exit 1) and nothing is copied or logged" "$r"

# 4. A --only path inside allow: applies just that file; the rest are named as skipped.
apply "$batch" j1 --only lib/a.dart
if [ "$rc" = 0 ] && [ "$(content "$repo/lib/a.dart")" = a2 ] &&
  [ "$(content "$repo/lib/b.bin")" = b1 ] && [ "$(content "$repo/reports/j1.md")" = r1 ] &&
  [ -e "$repo/lib/c.dart" ] && [ ! -e "$repo/lib/new.dart" ] &&
  exact 'applied 1 files:' && exact 'SKIPPED by --only: lib/new.dart' &&
  grep -qxF -- 'HAND-FIX j1: apply-job.sh applied 1 files: lib/a.dart' "$batch/run.log"; then
  r=0
else
  r=1
fi
report "--only inside allow: applies just that file and names the rest as skipped" "$r"

# 5. A target path with uncommitted work here refuses; --force copies over it.
reset_repo
printf 'local\n' > "$repo/lib/a.dart"
before=$(lines "$batch/run.log")
apply "$batch" j1 --only lib/a.dart
rc_dirty=$rc
says_dirty=$(grep -cF 'uncommitted changes' "$out")
kept=$(content "$repo/lib/a.dart")
after_dirty=$(lines "$batch/run.log")
apply "$batch" j1 --only lib/a.dart --force
if [ "$rc_dirty" = 1 ] && [ "$says_dirty" = 1 ] && [ "$kept" = local ] &&
  [ "$after_dirty" = "$before" ] && [ "$rc" = 0 ] && [ "$(content "$repo/lib/a.dart")" = a2 ]; then
  r=0
else
  r=1
fi
report "a dirty target path is refused (nothing copied or logged); --force copies over it" "$r"

# 6. --dry lists what it would do, copies nothing and writes no log line.
reset_repo
before=$(lines "$batch/run.log")
apply "$batch" j1 --dry
if [ "$rc" = 0 ] && [ "$(content "$repo/lib/a.dart")" = a1 ] && [ -e "$repo/lib/c.dart" ] &&
  [ ! -e "$repo/lib/new.dart" ] && [ "$(lines "$batch/run.log")" = "$before" ] &&
  exact 'would apply 5 files:' && exact 'SKIPPED churn: site/shots/shot.png' &&
  has 'dry run: nothing copied' && ! has 'next: run'; then r=0; else r=1; fi
report "--dry lists the files, copies nothing and logs nothing" "$r"

# 7. --tree names the tree itself: the empty one wins over the log's kept path.
apply "$batch" j1 --tree "$other" --dry
if [ "$rc" = 1 ] && has 'nothing to apply' && ! has 'would apply'; then r=0; else r=1; fi
report "--tree names the tree itself, ahead of the log's kept path" "$r"

# 8. APPLY_LOGS reads the kept path from that folder instead of the batch folder.
mkdir -p "$tmp/altlogs"
printf -- '---- flash: the worktree is kept: %s\n' "$other" > "$tmp/altlogs/flash-j1.log"
apply_logs "$tmp/altlogs" "$batch" j1 --dry
if [ "$rc" = 1 ] && has 'nothing to apply'; then r=0; else r=1; fi
report "APPLY_LOGS reads the kept path from that folder instead of the batch folder" "$r"

# 9. No log, or a log without the kept-path line: refused, and the log is named.
mkdir -p "$tmp/nokept"
printf -- '---- flash: result 4\n' > "$tmp/nokept/flash-j1.log"
apply_logs "$tmp/nokept" "$batch" j1
rc_nokept=$rc
says_nokept=$(grep -cF 'no "the worktree is kept:' "$out")
apply_logs "$tmp/nolog" "$batch" j1
if [ "$rc_nokept" = 1 ] && [ "$says_nokept" = 1 ] && [ "$rc" = 1 ] && has 'no flash log at'; then r=0; else r=1; fi
report "a missing log or kept-path line refuses (exit 1), naming the log" "$r"

# 10. Bad use is exit 2: no arguments, an unknown option, a job with no brief.
apply
rc_noargs=$rc
apply "$batch" j1 --bogus
rc_opt=$rc
apply "$batch" no-such-job
if [ "$rc_noargs" = 2 ] && [ "$rc_opt" = 2 ] && [ "$rc" = 2 ] && has 'no brief at'; then r=0; else r=1; fi
report "bad use is exit 2: no arguments, an unknown option, a job with no brief" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
