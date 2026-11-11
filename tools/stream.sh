#!/usr/bin/env bash
# The Thumb Party streaming session (M15): build the session image from this
# checkout, run one or two sessions in the locked-down WSL distro, and look at
# them. The image and the player are described in streaming/README.md; it only
# ever runs `wsl -d <distro> ...` and the two helper scripts.
#
#   tools/stream.sh build
#   tools/stream.sh up [--name N] [--port-base P]
#   tools/stream.sh status
#   tools/stream.sh logs [--name N] [--follow]
#   tools/stream.sh url [--name N]
#   tools/stream.sh down [--name N | --all]
#
# The distro must be a locked-down `tp-` one (tools/wsl-lockcheck.sh), because
# nothing here may reach the Windows side.
set -u
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.." || exit 2

# The image tools/stream.sh build makes and up runs.
readonly image="tp-session:latest"
# Container names are this prefix plus the session name.
readonly container_prefix="thumb-party-"
# The controller port the TV app asks for, and the base of a session's block:
# the signalling port is the next one and the player port the one after. The app
# moves to a free port when that one is busy and says so in its ready line, so
# `url` reports what it got rather than what it was asked for.
readonly default_port_base=45780
# How long `up` waits for the session's own ready line before it says so.
readonly ready_wait_s=120
# The label every session container carries, so status and down find them.
readonly session_label="thumb-party.session"

distro="${STREAM_DISTRO:-tp-stream}"
command=""
name="party"
port_base="$default_port_base"
follow="no"
all="no"

say() { printf '%s\n' "$*"; }
fail() { printf 'stream: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
The Thumb Party streaming session (M15).

  tools/stream.sh build                            build the session image from this checkout
  tools/stream.sh up [--name N] [--port-base P]    start a session (default: party, ports from 45780)
  tools/stream.sh status                           what runs, and whether it is ready
  tools/stream.sh logs [--name N] [--follow]       a session's log
  tools/stream.sh url [--name N]                   the player URL and the controller address
  tools/stream.sh down [--name N | --all]          stop a session, or every session

Options:
  --distro <name>   the WSL distro to use (default: tp-stream, or $STREAM_DISTRO);
                    its name must start with "tp-"
  --name <name>     the session's name: its container and the ports it takes
  --port-base <n>   the session's first port; signalling and player take the
                    next two, so two sessions need different bases
  --follow          keep printing the log until interrupted
  --all             every session, for down

Exit codes: 0 ok, 1 the step failed, 2 bad use.
EOF
}

# The distro must be one of the locked-down streaming ones: the helper scripts
# and the flash jobs only ever touch a name starting with tp-.
check_distro() {
  if [[ ! "$distro" =~ ^tp-[a-z0-9-]+$ ]]; then
    printf 'stream: the distro name must start with "tp-", got "%s"\n' "$distro" >&2
    printf 'stream: run "tools/stream.sh --help" for the options\n' >&2
    exit 2
  fi
}

check_name() {
  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    printf 'stream: a session name is lower-case letters, digits and dashes, got "%s"\n' "$name" >&2
    exit 2
  fi
}

check_port_base() {
  if [[ ! "$port_base" =~ ^[0-9]+$ ]] || (( port_base < 1024 || port_base > 65000 )); then
    printf 'stream: the port base must be a number from 1024 to 65000, got "%s"\n' "$port_base" >&2
    exit 2
  fi
}

# Runs one command as root inside the distro.
wsl_run() { wsl -d "$distro" -u root -- bash -lc "$1"; }

container_name() { printf '%s%s' "$container_prefix" "$name"; }

# Copies the checkout into the distro and prints where it is.
sync_repo() {
  local dest
  dest="$(tools/wsl-sync.sh "$distro")" || fail "the copy into $distro failed"
  printf '%s' "$dest"
}

# The value of one setting in a running session's container, read from the
# container's own environment.
container_env() {
  local container="$1" key="$2"
  wsl_run "docker inspect $container" 2>/dev/null \
    | tr ',{}' '\n\n\n' \
    | sed -n "s/^ *\"$key=\([0-9A-Za-z._-]*\)\".*/\1/p" \
    | head -1
}

container_state() {
  local container="$1"
  wsl_run "docker inspect $container" 2>/dev/null | sed -n 's/^ *"Status": "\([a-z]*\)".*/\1/p' | head -1
}

# The session's log, as the container prints it.
container_log() {
  local container="$1" tail_count="${2:-100}"
  wsl_run "docker logs --tail $tail_count $container 2>&1"
}

# Prints the session's ready line once it is there, waiting up to
# ready_wait_s seconds. A container that ended stops the wait at once.
wait_ready() {
  local container="$1" waited=0 line state
  while (( waited < ready_wait_s )); do
    line="$(container_log "$container" 200 | grep -m1 ' ready: ')"
    if [[ -n "$line" ]]; then
      printf '%s\n' "$line"
      return 0
    fi
    state="$(container_state "$container")"
    if [[ "$state" == "exited" ]]; then
      printf 'stream: the session stopped before it was ready; its log:\n' >&2
      container_log "$container" 40 >&2
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  printf 'stream: no ready line after %ss; its log:\n' "$ready_wait_s" >&2
  container_log "$container" 40 >&2
  return 1
}

cmd_build() {
  local dest
  dest="$(sync_repo)"
  say "building $image in $distro (from $dest) …"
  wsl_run "cd $dest && docker build -f streaming/Dockerfile -t $image ." || fail "the image build failed"
  say "built $image"
}

cmd_up() {
  local container controller signal player gpu_flags ready
  check_name
  check_port_base
  container="$(container_name)"
  controller="$port_base"
  signal=$((port_base + 1))
  player=$((port_base + 2))

  if wsl_run "docker inspect $container > /dev/null 2>&1"; then
    fail "a session named $name already runs; stop it first: tools/stream.sh down --name $name"
  fi

  # WSL2's GPU needs these; a real Linux GPU container does not have /dev/dxg
  # and is given only the GPU itself (see streaming/README.md).
  gpu_flags=""
  if wsl_run "test -e /dev/dxg && echo yes" | grep -q yes; then
    gpu_flags="--device /dev/dxg -v /usr/lib/wsl:/usr/lib/wsl:ro -e LD_LIBRARY_PATH=/usr/lib/wsl/lib"
  fi

  # --network host: WebRTC media is UDP straight from the container to the
  # player, and a published port only forwards to the container's bridge
  # network, which a browser on Windows cannot reach (streaming/README.md).
  wsl_run "docker run -d --name $container --label $session_label=$name \
    --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all $gpu_flags --network host \
    -e GALLIUM_DRIVER=d3d12 -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA \
    -e CONTROLLER_PORT=$controller -e SIGNAL_PORT=$signal -e PLAYER_PORT=$player \
    -e SESSION_NAME=$name $image" > /dev/null \
    || fail "the session did not start (docker run failed)"

  say "started $container: signaller $signal, player $player, controller port from $controller"
  if ready="$(wait_ready "$container")"; then
    say "$ready"
    cmd_url
  else
    fail "the session is running but not ready; try tools/stream.sh logs --name $name"
  fi
}

cmd_status() {
  local names container state
  names="$(wsl_run "docker ps -a --filter label=$session_label --format {{.Names}}")" || fail "cannot ask $distro for its containers"
  if [[ -z "$names" ]]; then
    say "no sessions"
    return 0
  fi
  for container in $names; do
    state="$(container_state "$container")"
    printf '%-24s %-10s %s\n' "$container" "$state" "$(container_log "$container" 200 | grep -m1 ' ready: ' || true)"
  done
}

cmd_logs() {
  local container
  check_name
  container="$(container_name)"
  if ! wsl_run "docker inspect $container > /dev/null 2>&1"; then
    fail "no session named $name"
  fi
  if [[ "$follow" == "yes" ]]; then
    wsl_run "docker logs --tail 100 --follow $container"
  else
    container_log "$container" 100
  fi
}

cmd_url() {
  local container controller signal player address
  check_name
  container="$(container_name)"
  signal="$(container_env "$container" SIGNAL_PORT)"
  player="$(container_env "$container" PLAYER_PORT)"
  # The app takes the port it was given or a free one when that is busy; the
  # ready line carries the one it got.
  controller="$(container_log "$container" 200 | grep -m1 -oE 'controller=localhost:[0-9]+' | cut -d: -f2)"
  if [[ -z "$controller" ]]; then
    controller="$(container_env "$container" CONTROLLER_PORT)"
  fi
  if [[ -z "$controller" || -z "$signal" || -z "$player" ]]; then
    fail "no session named $name"
  fi
  address="$(wsl_run "hostname -I" | awk '{print $1}')"
  say "player:     http://localhost:$player/"
  say "controller: localhost:$controller   (other devices on the Wi-Fi use $address:$controller)"
  say "signalling: $address:$signal"
}

cmd_down() {
  local containers container
  if [[ "$all" == "yes" ]]; then
    containers="$(wsl_run "docker ps -a --filter label=$session_label --format {{.Names}}")" || fail "cannot ask $distro for its containers"
    if [[ -z "$containers" ]]; then
      say "no sessions to stop"
      return 0
    fi
  else
    check_name
    containers="$(container_name)"
  fi
  for container in $containers; do
    wsl_run "docker rm -f $container" > /dev/null || fail "could not stop $container"
    say "stopped $container"
  done
}

while (( $# > 0 )); do
  case "$1" in
    build | up | status | logs | url | down)
      command="$1"
      shift
      ;;
    --distro)
      distro="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --name)
      name="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --port-base)
      port_base="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --follow)
      follow="yes"
      shift
      ;;
    --all)
      all="yes"
      shift
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      printf 'stream: unknown option "%s"\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

check_distro

if [[ -z "$command" ]]; then
  printf 'stream: no command given\n' >&2
  usage
  exit 2
fi

case "$command" in
  build) cmd_build ;;
  up) cmd_up ;;
  status) cmd_status ;;
  logs) cmd_logs ;;
  url) cmd_url ;;
  down) cmd_down ;;
esac
