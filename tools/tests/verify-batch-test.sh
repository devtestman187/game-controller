#!/usr/bin/env bash
# Tests tools/verify-batch.sh on a temp repository: a good batch passes (tracker rows read from
# JSON files, untracked churn ignored); each check fails alone when its input is wrong (foreign commit
# identity, failed or missing full-check line, a dirty non-churn file, a tracker status that differs
# from the claim, a missing REPORT.md, a STATUS block that does not name the tip); the tip that edits STATUS.md may name
# its parent; no tracker input is a SKIP, not a FAIL; bad arguments exit 2.
#
#   bash tools/tests/verify-batch-test.sh
# Prints PASS <case> / FAIL <case> and exits 1 if any case failed.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/verify-batch-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0
out="$tmp/out.txt"
r="$tmp/repo"
mkdir -p "$r/docs/briefs/m1/b1" "$r/docs/design" "$tmp/rows"
git -C "$r" init -q
export GIT_AUTHOR_NAME=devtestman187 GIT_COMMITTER_NAME=devtestman187
export GIT_AUTHOR_EMAIL=347253452+devtestman187@users.noreply.github.com
export GIT_COMMITTER_EMAIL=347253452+devtestman187@users.noreply.github.com
git -C "$r" commit -q --allow-empty -m base
base="$(git -C "$r" rev-parse HEAD)"
echo "x" > "$r/a.txt"; git -C "$r" add a.txt; git -C "$r" commit -q -m work
work="$(git -C "$r" rev-parse --short=8 HEAD)"
echo "2026-11-24 10:00:00 full check: All checks passed (13 suites, 5 s, uncached)" > "$r/docs/briefs/m1/b1/run.log"
echo "# Report" > "$r/docs/briefs/m1/b1/REPORT.md"
printf '**Resume here (b1, Nov 24):** done at %s.\n\nother\n' "$work" > "$r/docs/briefs/m1/STATUS.md"
git -C "$r" add docs; git -C "$r" commit -q -m wrap
tip="$(git -C "$r" rev-parse HEAD)"
echo '{"id":"B-1","status":"Fixed"}' > "$tmp/rows/B-1.json"
echo churn > "$r/docs/design/shot.png" # untracked churn

rc=0
v() { # v <range> [args]
  local rg="$1"; shift
  bash "$root/tools/verify-batch.sh" docs/briefs/m1/b1 "$rg" --repo "$r" "$@" > "$out" 2>&1; rc=$?
}
expect() { # expect <case> <rc> <text>
  if [ "$rc" = "$2" ] && grep -qF -- "$3" "$out"; then echo "PASS $1"; else echo "FAIL $1 (rc $rc, want $2 and: $3)"; sed 's/^/    | /' "$out"; fails=$((fails + 1)); fi
}

v "$base..$tip" --tracker-dir "$tmp/rows" --claim B-1=Fixed
expect good 0 "RESULT: PASS"
expect good-tracker 0 "OK tracker: 1 rows match"
expect good-report 0 "OK report:"
expect good-status 0 "OK status: block names $work"
v "$base..$tip" --tracker-dir "$tmp/rows" --claim B-1=New
expect tracker-mismatch 1 "FAIL tracker: mismatch: B-1(row: Fixed, claimed: New)"
v "$base..$tip"
expect no-tracker-skip 0 "SKIP tracker"
echo y > "$r/real.txt"
v "$base..$tip" --no-tracker
expect dirty-tree 1 "FAIL tree: not churn: real.txt"
rm "$r/real.txt"
v "$base..$tip" --no-tracker
expect musts-skip 0 "SKIP musts"
printf -- '- **must** a.dart:1 bad -> fix it
2. must: b.dart:2 other
3. **must** c.dart:3 done (fixed in w2)
- **should** d
' > "$r/docs/briefs/m1/b1/REVIEW.md"
v "$base..$tip" --no-tracker
expect musts-open 1 "FAIL musts: 2 open must finding(s)"
expect musts-lines 1 "line(s): 1 2"
# (rc 1 below: the untracked REVIEW.md is a dirty tree; only the musts line matters)
printf -- '- **must** a.dart:1 bad (FIXED)
2. must: b.dart:2 other, answered by owner
- **must** c closed
' > "$r/docs/briefs/m1/b1/REVIEW.md"
v "$base..$tip" --no-tracker
expect musts-closed 1 "OK musts"
rm "$r/docs/briefs/m1/b1/REVIEW.md"
GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_EMAIL=t@t git -C "$r" commit -q --allow-empty -m foreign
bad="$(git -C "$r" rev-parse HEAD)"
v "$base..$bad" --no-tracker
expect identity 1 "FAIL commits: 3 commits, wrong identity on:"
expect status-tip-differs 1 "FAIL status: block for b1 does not name tip"
git -C "$r" reset -q --hard "$tip"
echo "2026-11-24 11:00:00 full check: FAILED (2 suites)" >> "$r/docs/briefs/m1/b1/run.log"
v "$base..$tip" --no-tracker
expect runlog-fail 1 "FAIL runlog: last full check line"
rm "$r/docs/briefs/m1/b1/run.log"
v "$base..$tip" --no-tracker
expect runlog-missing 1 "FAIL runlog: no 'full check:' line"
mv "$r/docs/briefs/m1/b1/REPORT.md" "$tmp/REPORT.md"
v "$base..$tip" --no-tracker
expect report-missing 1 "FAIL report: missing or empty"
bash "$root/tools/verify-batch.sh" > "$out" 2>&1; rc=$?
expect bad-use 2 "usage:"
[ "$fails" = 0 ] || exit 1
