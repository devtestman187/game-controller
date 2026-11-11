#!/usr/bin/env bash
# Copies ONE file (under 5 MB) from /work/ in a locked-down WSL distro to a
# file under docs/ in this checkout: a screenshot or log a job wants to keep.
# Documented in docs/dev-tools.md.
#
#   tools/wsl-fetch.sh <distro> </work/path/to/file> <docs/path/to/local-file>
#
# The distro must pass tools/wsl-lockcheck.sh. The local path must be under
# docs/ (no .., not docs/PRD*). Symlinks in the distro are resolved and the
# result must still be under /work/.
set -u
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.." || exit 2
d="${1:-}"; src="${2:-}"; dst="${3:-}"
if [ $# -ne 3 ]; then echo "usage: tools/wsl-fetch.sh <distro> </work/file> <docs/local-file>" >&2; exit 2; fi
if ! [[ "$src" =~ ^/work/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ ]] || [[ "$src" == *..* ]]; then
  echo "wsl-fetch: the source must be a file under /work/ (letters, digits . _ - and /; no ..), got '$src'" >&2
  exit 2
fi
if ! [[ "$dst" =~ ^docs/[A-Za-z0-9._/-]+$ ]] || [[ "$dst" == *..* ]] || [[ "$dst" == docs/PRD* ]] || [[ "$dst" == */ ]]; then
  echo "wsl-fetch: the local file must be under docs/ (no .., not docs/PRD*), got '$dst'" >&2
  exit 2
fi
tools/wsl-lockcheck.sh "$d" || exit 2
size="$(wsl -d "$d" -u root -- bash -s 2> /dev/null << INSIDE | tr -d '\r'
r=\$(realpath $src) && case \$r in /work/*) test -f \$r && stat -c %s \$r ;; esac
INSIDE
)"
if ! [[ "$size" =~ ^[0-9]+$ ]]; then echo "wsl-fetch: $src isn't a regular file under /work/" >&2; exit 2; fi
if [ "$size" -gt 5242880 ]; then echo "wsl-fetch: $src is $size bytes (the limit is 5 MB)" >&2; exit 2; fi
mkdir -p "$(dirname "$dst")" || exit 2
tmp="$dst.fetch-$$"
if wsl -d "$d" -u root -- bash -c "cat $src" > "$tmp" && [ "$(wc -c < "$tmp")" = "$size" ]; then
  mv -f "$tmp" "$dst" && echo "$dst ($size bytes)"
else
  rm -f "$tmp"
  echo "wsl-fetch: copy failed" >&2
  exit 2
fi
