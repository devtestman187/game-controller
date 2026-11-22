#!/usr/bin/env bash
# Tests tools/brief-check.sh, the pre-run check of a batch's briefs: a clean batch passes; two
# jobs of one wave that share an allow: path FAIL with rule wave (an equal path and a folder
# holding the other job's file); a NEW file its job's allow: does not cover FAILs with rule
# new-file; an allow: over 20 entries or over 3 packages is a WARN and the batch still passes;
# a changes: item used in a .dart file no job of its wave or an earlier wave allows FAILs,
# naming the job, the item and the file (a later wave's allow is too late; an earlier wave's or
# the same wave's passes); BRIEF_CHECK_REF reads the ref's tree, not the working tree; no
# argument is bad use, exit 2.
#
#   bash tools/tests/brief-check-test.sh
#
# Each case points BRIEF_CHECK_ROOT at one fixture under tools/tests/fixtures/brief-check: a
# tiny batch (waves.txt and one brief per job) plus a tiny lib/ and test/ tree. The ref case
# copies the good fixture into a temp repo and commits it, then adds a hit to its working tree.
# Prints PASS <case> / FAIL <case> (the tool's output indented under a failure) and exits 1 if
# any case failed.
set -u
cd "$(dirname "$0")/../.." || exit 2
fixtures=tools/tests/fixtures/brief-check
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/brief-check-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT

fails=0
cases=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
report() { # report <case> <0 passed | 1 failed>: on a failure, show what the tool printed
  cases=$((cases + 1))
  if [ "$2" = 0 ]; then pass "$1"; else fail "$1"; sed 's/^/    | /' "$out"; fi
}

out="$tmp/out.txt"
rc=0
check() { # check <fixture>: runs the tool on that fixture's batch; sets rc and writes $out
  rc=0
  BRIEF_CHECK_ROOT="$1" BRIEF_CHECK_REF= bash tools/brief-check.sh "$1/batch" > "$out" 2>&1 || rc=$?
}
has() { grep -qF -- "$1" "$out"; } # has <text>: $out has a line holding that text
exact() { grep -qxF -- "$1" "$out"; } # exact <line>: $out has exactly that line
none() { ! grep -q "^$1" "$out"; } # none <prefix>: $out has no line starting with it

# 1. A clean batch: one wave, two jobs, each new file in its own allow:, every changes: hit in
#    a file of the same wave. Nothing to report but the result.
check "$fixtures/good"
if [ "$rc" = 0 ] && exact 'RESULT: ok: 2 job(s), 0 WARN' && none FAIL && none WARN; then r=0; else r=1; fi
report "a clean batch passes with RESULT: ok and no FAIL or WARN line" "$r"

# 2. Two jobs of one wave share an allow: path: once the same path, once w1's folder holding
#    w2's file. Both FAIL, and each line names the pair, the path and the job.
check "$fixtures/wave-overlap"
if [ "$rc" = 1 ] &&
  exact 'FAIL wave w2: w1 and w2 both allow packages/q/lib/same.dart' &&
  exact "FAIL wave w2: w1 allows folder packages/p/lib, which holds w2's packages/p/lib/shared.dart" &&
  exact 'RESULT: FAILED: 2 FAIL, 0 WARN (2 job(s) checked)'; then r=0; else r=1; fi
report "two jobs of one wave sharing an allow: path FAIL with rule wave (equal path and folder)" "$r"

# 3. A do: line creates a file the job's own allow: does not cover: the job could not commit it.
check "$fixtures/missing-new-file"
if [ "$rc" = 1 ] &&
  exact 'FAIL new-file m1: its do: line creates packages/p/lib/extra.dart, which its allow: does not cover' &&
  exact 'RESULT: FAILED: 1 FAIL, 0 WARN (1 job(s) checked)'; then r=0; else r=1; fi
report "a NEW file its job's allow: does not cover FAILs with rule new-file" "$r"

# 4. An allow: of 21 entries in 4 packages: one WARN for each reason, and the batch passes.
check "$fixtures/big-allow"
if [ "$rc" = 0 ] && exact 'WARN allow-size b1: 21 allow: entries (over 20); split the job' &&
  exact 'WARN allow-size b1: 4 packages in its allow: (over 3); split it by package' &&
  exact 'RESULT: ok: 1 job(s), 2 WARN'; then r=0; else r=1; fi
report "an allow: over 20 entries or 3 packages is a WARN (the batch still passes)" "$r"

# 5. A changes: item used in a test file that no job allows: the wave's combined check would fail
#    on it (the identity1 m9_test case). The file in the job's own allow: is not a FAIL.
want='FAIL changes c1: NewWidget is used in controller_app/test/widgets_test.dart, which no job of wave 1 or'
want="$want earlier allows"
check "$fixtures/changes-hit-test-file"
if [ "$rc" = 1 ] && exact "$want" && exact 'RESULT: FAILED: 1 FAIL, 0 WARN (1 job(s) checked)'; then r=0; else r=1; fi
report "a changes: item used in a test file outside every allow: FAILs naming job, item and file" "$r"

# 6. A changes: item used in a file only a later wave's job allows: too late for wave 1's check,
#    so a FAIL; the same item in a file a wave 1 job allows passes, so exactly one FAIL.
want='FAIL changes late: NewThing is used in controller_app/lib/holds.dart, which only holder of wave 2'
want="$want allows, after wave 1"
check "$fixtures/changes-hit-later-wave"
if [ "$rc" = 1 ] && exact "$want" && exact 'RESULT: FAILED: 1 FAIL, 0 WARN (3 job(s) checked)'; then r=0; else r=1; fi
report "a changes: item allowed only by a later wave FAILs; an earlier wave's allow: passes" "$r"

# 7. No argument: bad use, exit 2, and the result line says so.
rc=0
bash tools/brief-check.sh > "$out" 2>&1 || rc=$?
if [ "$rc" = 2 ] && has 'RESULT: BAD INPUT: usage: tools/brief-check.sh <briefs-dir>'; then r=0; else r=1; fi
report "no argument is bad use: exit 2 and a RESULT: BAD INPUT line" "$r"

# 8. BRIEF_CHECK_REF searches the ref's tree: a hit that is only in the working tree is skipped
#    (exit 0, the ref's tree is clean), and the same tree without the ref FAILs on it.
mkdir -p "$tmp/ref"
cp -r "$fixtures/good/." "$tmp/ref/"
git -C "$tmp/ref" init -q
git -C "$tmp/ref" -c user.email=t@example.com -c user.name=t add -A
git -C "$tmp/ref" -c user.email=t@example.com -c user.name=t commit -q -m base
printf 'void main() {\n  SiblingThing();\n}\n' > "$tmp/ref/controller_app/test/ref_hit_test.dart"
refroot="$(cd "$tmp/ref" && pwd)"
want='FAIL changes g1: SiblingThing is used in controller_app/test/ref_hit_test.dart, which no job of wave 1'
want="$want or earlier allows"
rc=0
BRIEF_CHECK_ROOT="$refroot" BRIEF_CHECK_REF=HEAD bash tools/brief-check.sh "$refroot/batch" \
  > "$tmp/ref-out.txt" 2>&1 || rc=$?
ref_rc=$rc
check "$refroot"
if [ "$ref_rc" = 0 ] && grep -qxF 'RESULT: ok: 2 job(s), 0 WARN' "$tmp/ref-out.txt" &&
  [ "$rc" = 1 ] && exact "$want"; then
  r=0
else
  r=1
  sed 's/^/    | ref: /' "$tmp/ref-out.txt"
fi
report "BRIEF_CHECK_REF reads the ref's tree, not the working tree" "$r"

if [ "$fails" -gt 0 ]; then
  echo "RESULT: FAILED: $fails of $cases case(s) failed"
  exit 1
fi
echo "RESULT: ok: $cases case(s) passed"
