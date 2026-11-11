#!/usr/bin/env bash
# Checks that a WSL distro is a sandbox flash.sh may hand to the worker:
# the name is tp-<something> and the distro exists, /etc/wsl.conf turns
# interop, appendWindowsPath and automount off, AND that holds right now
# (the Windows drive isn't mounted). Run by tools/flash.sh (wsl: header) and
# tools/wsl-sync.sh; documented in docs/dev-tools.md.
#
#   tools/wsl-lockcheck.sh <distro> [conf-file] [windows-probe-path]
#
# The last two default to /etc/wsl.conf and /mnt/c/Windows inside the distro;
# they exist so the check's failure paths can be tried without unlocking.
# Exit 0 locked down; 2 otherwise (with a message).
set -u
export MSYS_NO_PATHCONV=1
d="${1:-}"
conf="${2:-/etc/wsl.conf}"
probe="${3:-/mnt/c/Windows}"
if ! [[ "$d" =~ ^tp-[a-z0-9-]+$ ]]; then
  echo "wsl: the distro name must match ^tp-[a-z0-9-]+\$ (got '$d')" >&2
  exit 2
fi
if ! wsl -l -q 2> /dev/null | tr -d '\0\r' | grep -qxF -- "$d"; then
  echo "wsl: there is no distro named $d (wsl -l -q)" >&2
  exit 2
fi
out="$(wsl -d "$d" -u root -- bash -s -- "$conf" "$probe" 2>&1 << 'INSIDE' | tr -d '\r'
conf="$1"; probe="$2"
bad=""
[ -r "$conf" ] || { echo "cannot read $conf"; exit 1; }
val() {
  awk -v s="$1" -v k="$2" '{ gsub(/[ \t\r]/, "") }
    /^[#;]/ { next }
    /^\[/ { cur = tolower($0); next }
    { split($0, a, "="); if (cur == "[" s "]" && tolower(a[1]) == k) v = tolower(a[2]) }
    END { print v }' "$conf"
}
[ "$(val interop enabled)" = false ] || bad="$bad interop.enabled-not-false"
[ "$(val interop appendwindowspath)" = false ] || bad="$bad interop.appendWindowsPath-not-false"
[ "$(val automount enabled)" = false ] || bad="$bad automount.enabled-not-false"
[ ! -e "$probe" ] || bad="$bad $probe-is-present"
for p in /mnt/*/Windows; do [ ! -e "$p" ] || bad="$bad $p-is-present"; done
m="$(awk '($3 == "9p" || $3 == "drvfs") && $2 !~ /^\/usr\/lib\/wsl\// { print $2 }' /proc/mounts | tr '\n' ' ')"
[ -z "$m" ] || bad="$bad windows-mounts:$m"
if [ -n "$bad" ]; then echo "NOT LOCKED:$bad"; exit 1; fi
echo LOCKED
INSIDE
)"
if [ "$(printf '%s' "$out" | tail -n 1)" != LOCKED ]; then
  echo "wsl: $d isn't locked down ($(printf '%s' "$out" | tail -n 1)); see docs/dev-tools.md 'A locked-down distro'" >&2
  exit 2
fi
exit 0
