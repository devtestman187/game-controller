#!/usr/bin/env bash
# Copies this repo's fixed Thumb Party agents (.claude/agents/thumb-*.md) to the user-level agents
# folder (~/.claude/agents), so a session started outside the worktree (for example in the E-drive
# AI folder) finds them. The repo file is the source; run this after editing one. Each copy gets a
# comment line after its frontmatter naming its source. Agent definitions load at session start:
# a running session may need a new session to see a changed agent.
#
#   tools/sync-agents.sh [--dest <dir>] [--check]
#
# --check copies nothing and exits 1 when a copy is missing or differs from its source.
# Exit 0 done (or all in sync with --check), 1 out of sync (--check), 2 bad use.
set -u
cd "$(dirname "$0")/.." || exit 2
dest="${HOME}/.claude/agents"
check=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) dest="${2:-}"; shift 2 || exit 2 ;;
    --check) check=1; shift ;;
    *) echo "usage: tools/sync-agents.sh [--dest <dir>] [--check]" >&2; exit 2 ;;
  esac
done
[ -n "$dest" ] || exit 2
src_label="$(basename "$(pwd)")"

render() { # render <source>: the source with the copy note after the closing frontmatter line
  awk -v note="<!-- User-level copy of ${src_label}/$1 (tools/sync-agents.sh). Thumb Party only: the worktree comes in the prompt. The repo file is the source; edit it and re-run the script. -->" '
    { print }
    /^---[[:space:]]*$/ { n++; if (n == 2) { print ""; print note } }
  ' "$1"
}

stale=0
mkdir -p "$dest" 2> /dev/null || [ "$check" = 1 ] || exit 2
for f in .claude/agents/thumb-*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  if [ "$check" = 1 ]; then
    if ! render "$f" | cmp -s - "$dest/$name"; then echo "differs: $name"; stale=1; fi
  else
    render "$f" > "$dest/$name" && echo "copied: $name"
  fi
done
exit "$stale"
