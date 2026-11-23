#!/usr/bin/env bash
# Tests tools/sync-agents.sh: every .claude/agents/thumb-*.md is copied to --dest with a copy note
# right after its frontmatter and the body unchanged; --check exits 0 when in sync and 1 (naming
# the file) after a copy is edited; an unknown option exits 2.
#
#   bash tools/tests/sync-agents-test.sh
set -u
cd "$(dirname "$0")/../.." || exit 2
tmp="$(mktemp -d "${TMPDIR:-${TEMP:-/tmp}}/sync-agents-test-XXXXXX")" || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0
ok() { echo "PASS $1"; }
no() { echo "FAIL $1"; fails=$((fails + 1)); }

bash tools/sync-agents.sh --dest "$tmp/a" > "$tmp/out" 2>&1 || no copy-exit
n_src=$(ls .claude/agents/thumb-*.md | wc -l)
n_dst=$(ls "$tmp/a"/thumb-*.md 2> /dev/null | wc -l)
[ "$n_src" -gt 0 ] && [ "$n_src" = "$n_dst" ] && ok copies-all || no "copies-all ($n_src vs $n_dst)"
f=.claude/agents/thumb-wait.md
if grep -q 'User-level copy of .*thumb-wait.md' "$tmp/a/thumb-wait.md" \
  && diff <(grep -v 'User-level copy of' "$tmp/a/thumb-wait.md" | sed '/^$/d') <(sed '/^$/d' "$f") > /dev/null; then
  ok note-and-body
else
  no note-and-body
fi
note_line=$(grep -n 'User-level copy of' "$tmp/a/thumb-wait.md" | cut -d: -f1)
second_fm=$(grep -n '^---' "$tmp/a/thumb-wait.md" | sed -n 2p | cut -d: -f1)
[ -n "$note_line" ] && [ "$note_line" = $((second_fm + 2)) ] && ok note-after-frontmatter || no note-after-frontmatter
bash tools/sync-agents.sh --dest "$tmp/a" --check > "$tmp/out" 2>&1 && ok check-in-sync || no check-in-sync
echo extra >> "$tmp/a/thumb-wait.md"
bash tools/sync-agents.sh --dest "$tmp/a" --check > "$tmp/out" 2>&1
[ $? = 1 ] && grep -q 'differs: thumb-wait.md' "$tmp/out" && ok check-differs || no check-differs
bash tools/sync-agents.sh --bogus > /dev/null 2>&1
[ $? = 2 ] && ok bad-option || no bad-option
[ "$fails" = 0 ] || exit 1
