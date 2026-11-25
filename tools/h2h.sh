#!/usr/bin/env bash
# Head-to-head close (m165 t2): two arms of one job (briefs with `apply: no`, same body, `model:` differs) ran and flash.sh kept
# both worktrees. This applies the winner and files the loser, so the batch folder holds exactly one result:
#
#   tools/h2h.sh <batch dir> <winner job> <loser job> [--dry]
#
#   1. the winner: tools/apply-job.sh <batch dir> <winner> (its allow: files and report: path, from its kept tree, logged as a
#      HAND-FIX line like any apply-job use; this is the apply of a job, not a content fix), then one `H2H` line in run.log;
#   2. the loser: `git -C <its tree> diff --binary HEAD` (new files added with add -N first, generated churn left out) saved as
#      <batch dir>/loser-<loser>.patch;
#   3. both kept worktrees are removed and `git worktree prune` runs.
# Nothing is staged or committed. --dry prints the trees and what it would do and changes nothing. Exit 0 done, 1 refused,
# 2 bad use. The trees come from flash-<job>.log ("the worktree is kept: <path>"); APPLY_LOGS=<dir> reads the logs elsewhere.
set -u
tool_dir=$(cd "$(dirname "$0")" && pwd) || exit 2
. "$tool_dir/churn.sh" || exit 2
cd "$tool_dir/.." || exit 2

batch="" win="" lose="" dry=0
for a in "$@"; do
  case "$a" in
    --dry) dry=1 ;;
    -*) echo "h2h: unknown option $a" >&2; exit 2 ;;
    *) if [ -z "$batch" ]; then batch=${a%/}; elif [ -z "$win" ]; then win=${a%.md}; elif [ -z "$lose" ]; then lose=${a%.md}; else echo "h2h: too many arguments" >&2; exit 2; fi ;;
  esac
done
[ -n "$lose" ] || { echo "usage: tools/h2h.sh <batch dir> <winner job> <loser job> [--dry]" >&2; exit 2; }
[ -d "$batch" ] && [ -f "$batch/$win.md" ] && [ -f "$batch/$lose.md" ] || { echo "h2h: no batch folder or brief" >&2; exit 2; }
[ "$win" != "$lose" ] || { echo "h2h: winner and loser are the same job" >&2; exit 2; }
refuse() { echo "h2h: refused: $1" >&2; exit 1; }

logs=${APPLY_LOGS:-$batch}
tree_of() { sed -n 's/.*the worktree is kept: //p' "$logs/flash-$1.log" 2> /dev/null | tail -n 1 | tr -d '\r'; }
wt=$(tree_of "$win"); lt=$(tree_of "$lose")
[ -d "$wt" ] || refuse "the winner's kept worktree is not there ($wt)"
[ -d "$lt" ] || refuse "the loser's kept worktree is not there ($lt)"
patch="$batch/loser-$lose.patch"
echo "h2h: winner $win ($wt), loser $lose ($lt) -> $patch"
[ "$dry" = 1 ] && { echo "h2h: --dry: nothing changed"; exit 0; }

bash tools/apply-job.sh "$batch" "$win" --tree "$wt" || refuse "apply-job.sh refused for $win (nothing else was done)"

git -C "$lt" add -N . > /dev/null 2>&1
files=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '%s\n' "$f" | grep -Eq "$CHURN_REGEX" && continue
  files+=("$f")
done < <(git -C "$lt" diff --name-only HEAD)
if [ ${#files[@]} -gt 0 ]; then git -C "$lt" diff --binary HEAD -- "${files[@]}" > "$patch"; else : > "$patch"; fi
echo "h2h: saved ${#files[@]} files of $lose in $patch"

for t in "$wt" "$lt"; do git worktree remove --force "$t" 2> /dev/null || echo "h2h: couldn't remove $t (a file in use?); later: git worktree remove --force $t"; done
git worktree prune
echo "H2H $win won over $lose: applied by tools/h2h.sh (loser patch: $patch)" >> "$batch/run.log"
exit 0
