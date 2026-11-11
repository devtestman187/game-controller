#!/usr/bin/env bash
# Copies this checkout (the job folder, when run by a flash job) into a
# locked-down WSL distro, with no Windows mount involved: a tar stream goes
# through `wsl ... tar -x`. Copies tracked files and untracked files that
# git doesn't ignore: no .git, no build outputs, no kenney-audio/. Files
# already in the destination are overwritten, not removed. Prints the
# destination. Documented in docs/dev-tools.md.
#
#   tools/wsl-sync.sh <distro> [dest]      # dest: /work/<folder name> by default
#
# The distro must pass tools/wsl-lockcheck.sh. dest must be under /work/.
set -u
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.." || exit 2
d="${1:-}"
dest="${2:-/work/$(basename "$(pwd)")}"
dest="${dest%/}"
if [ -z "$d" ] || [ $# -gt 2 ]; then echo "usage: tools/wsl-sync.sh <distro> [dest under /work/]" >&2; exit 2; fi
if ! [[ "$dest" =~ ^/work/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ ]] || [[ "$dest" == *..* ]]; then
  echo "wsl-sync: dest must be a path under /work/ (letters, digits . _ - and /; no ..), got '$dest'" >&2
  exit 2
fi
tools/wsl-lockcheck.sh "$d" || exit 2
git ls-files -z --cached --others --exclude-standard -- . ':(exclude)kenney-audio' \
    ':(exclude,glob)**/build/**' ':(exclude,glob)**/.dart_tool/**' |
  tar --null --ignore-failed-read -T - -cf - --owner=0 --group=0 --numeric-owner 2> /dev/null |
  wsl -d "$d" -u root -- bash -c "mkdir -p $dest && tar -x --no-same-owner -C $dest" || {
    echo "wsl-sync: copy failed" >&2
    exit 2
  }
echo "$dest"
