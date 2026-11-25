#!/usr/bin/env bash
# tune4 K3: tools/proc-sweep.sh on a fake process table (PROC_SWEEP_LIST): it lists this worktree's orphaned or old
# flutter_tester/dart/bash/python processes, never another worktree's (a sibling ...-m15 or ...-m16-jobs), reports only
# by default, and --kill touches only orphaned flutter_tester and dart.
#
#   bash tools/tests/proc-sweep-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
loc=$(pwd)
bsl=$(printf '\134')
root=$(pwd -W 2> /dev/null || pwd); root=${root//$bsl//}
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/proc-sweep-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0 cases=0
report() { cases=$((cases + 1)); if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails + 1)); sed 's/^/    | /' "$tmp/out.txt"; fi; }
now=$(date +%s)
bs=${root//\//$bsl}
cat > "$tmp/table" <<EOT
4 1 $((now - 99999)) explorer c:/windows/explorer.exe
500 4 $((now - 5)) bash $root/tools/run-jobs.sh docs/briefs/m16/tune4
101 999 $((now - 600)) flutter_tester $root/packages/party_host/test/a_test.dart
102 999 $((now - 600)) dart ${root}-jobs/flash-x/run.dart
103 999 $((now - 600)) dart ${root%16}15/packages/x/test.dart
104 500 $((now - 9000)) bash $root/tools/old-batch.sh
105 999 $((now - 600)) dart $bs\packages\protocol\test\p_test.dart
106 999 $((now - 600)) python $root/tools/thing.py
107 500 $((now - 5)) dart $root/fresh-child.dart
108 999 $((now - 600)) notepad $root/readme.md
EOT
export PROC_SWEEP_LIST="$tmp/table"
bash tools/proc-sweep.sh > "$tmp/out.txt" 2>&1 < /dev/null
if grep -q '^ORPHAN 101 flutter_tester' "$tmp/out.txt" && grep -q '^ORPHAN 105 dart' "$tmp/out.txt" && grep -q '^ORPHAN 106 python' "$tmp/out.txt" &&
  ! grep -q ' 102 \| 103 \| 104 \| 107 \| 108 ' "$tmp/out.txt" && grep -q 'proc-sweep: 3 process(es) listed (2 orphaned' "$tmp/out.txt"; then r=0; else r=1; fi
report "report-only: this worktree's orphans listed (backslash paths too), sibling worktrees, live children and other programs are not" "$r"
bash tools/proc-sweep.sh --since $((now - 3000)) > "$tmp/out.txt" 2>&1 < /dev/null
if grep -q '^OLD 104 bash' "$tmp/out.txt" && ! grep -q ' 107 ' "$tmp/out.txt" && grep -q '4 process(es)' "$tmp/out.txt"; then r=0; else r=1; fi
report "--since lists a live process started before that time (OLD), not a newer one" "$r"
PROC_SWEEP_KILL_CMD="echo KILLCMD" bash tools/proc-sweep.sh --kill > "$tmp/out.txt" 2>&1 < /dev/null
if [ "$(grep -c "^KILLCMD" "$tmp/out.txt")" = 2 ] && grep -q 'killed 101' "$tmp/out.txt" && grep -q 'killed 105' "$tmp/out.txt" && ! grep -q 'killed 106' "$tmp/out.txt"; then r=0; else r=1; fi
report "--kill kills only the orphaned flutter_tester and dart (101, 105), never the python (106)" "$r"
if [ "$fails" -gt 0 ]; then echo "RESULT: FAILED: $fails of $cases case(s) failed"; exit 1; fi
echo "RESULT: ok: $cases case(s) passed"
