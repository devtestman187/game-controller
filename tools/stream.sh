#!/usr/bin/env bash
# The Thumb Party streaming session (M15): build the session image from this
# checkout, run one or two sessions in the locked-down WSL distro, and look at
# them. The image and the player are described in streaming/README.md; it only
# ever runs `wsl -d <distro> ...` and the two helper scripts.
#
#   tools/stream.sh build
#   tools/stream.sh up [--name N] [--port-base P]
#   tools/stream.sh bench [--sessions N] [--seconds S] [--game arena|shape_race]
#   tools/stream.sh stats [--results DIR]
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
# The controller port a session starts from, and the base of its block of
# four: signalling, player and automation take the next three. The app is
# pinned to its controller port (job a2), so `url` reads that one back.
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
# The benchmark's settings (M15 c2): how many sessions run at once, for how
# long, which game, at what size, and where the summaries land.
sessions=1
seconds=60
game="arena"
size="1920x1080"
players=1
label="bench"
probe="no"
keep="no"
# Where the fetched summaries live, under docs/ so they stay with the reports.
readonly results_root="docs/briefs/m15/c2/results"
results="$results_root"

say() { printf '%s\n' "$*"; }
fail() { printf 'stream: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
The Thumb Party streaming session (M15).

  tools/stream.sh build                            build the session image from this checkout
  tools/stream.sh up [--name N] [--port-base P]    start a session (default: party, ports from 45780)
  tools/stream.sh bench [options]                  play a round through a session, a viewer and the
                                                   stats ingest, and print the Streaming report
  tools/stream.sh stats [--results DIR]            the Streaming report for the summaries a bench fetched
  tools/stream.sh status                           what runs, and whether it is ready
  tools/stream.sh logs [--name N] [--follow]       a session's log
  tools/stream.sh url [--name N]                   the player URL and the controller address
  tools/stream.sh down [--name N | --all]          stop a session, or every session

Options:
  --distro <name>   the WSL distro to use (default: tp-stream, or $STREAM_DISTRO);
                    its name must start with "tp-"
  --name <name>     the session's name: its container and the ports it takes
  --port-base <n>   the session's first port; signalling, player and automation
                    take the next three, so two sessions need different bases
  --follow          keep printing the log until interrupted
  --all             every session, for down

Bench options:
  --sessions <n>    sessions at once (default 1)
  --seconds <n>     how long the round runs (default 60)
  --game <name>     arena (a bumper round) or shape_race (default arena)
  --size <WxH>      the screen and encoder size (default 1920x1080)
  --players <n>     simulated players a session (default 1)
  --probe           show the latency card and time presses instead of a round:
                    press-to-screen is measured this way, as its own series
  --label <name>    the run's name: its containers and its results folder
  --keep            leave the sessions running afterwards
  --results <dir>   for stats: the folder of summaries (default docs/briefs/m15/c2/results)

The bench copies this checkout into the distro, starts the sessions there,
plays through a headless Chrome viewer, fetches each session's summary into
docs/briefs/m15/c2/results/<label>/ and runs the report over it.

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
  local container controller signal player automation gpu_flags ready
  check_name
  check_port_base
  container="$(container_name)"
  controller="$port_base"
  signal=$((port_base + 1))
  player=$((port_base + 2))
  automation=$((port_base + 3))

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
    -e AUTOMATION_PORT=$automation -e SESSION_NAME=$name $image" > /dev/null \
    || fail "the session did not start (docker run failed)"

  say "started $container: signaller $signal, player $player, controller $controller, automation $automation"
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
  local container controller signal player automation address
  check_name
  container="$(container_name)"
  signal="$(container_env "$container" SIGNAL_PORT)"
  player="$(container_env "$container" PLAYER_PORT)"
  automation="$(container_env "$container" AUTOMATION_PORT)"
  # The app is pinned to the controller port it was given; the ready line
  # carries the one it got.
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
  say "automation: 127.0.0.1:$automation in $distro (the token is /run/thumb-party/automation.token)"
}

# Runs the analytics report over a folder of summaries on this machine: the
# report is Dart and the checkout's workspace is already resolved.
print_report() {
  dart run packages/metrics/bin/report.dart "$1"
}

# One benchmark (M15 c2): the sessions run inside the distro, the summaries
# come back into docs/, and the Streaming report is printed here.
cmd_bench() {
  local dest remote files file extra=""
  if [[ ! "$label" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    fail "the label is lower-case letters, digits and dashes, got \"$label\""
  fi
  if ! wsl_run "docker image inspect $image > /dev/null 2>&1"; then
    fail "the image $image isn't in $distro yet: run tools/stream.sh build"
  fi
  dest="$(sync_repo)" || fail "the copy into $distro failed"
  remote="/work/stream-bench/$label"
  if [[ "$probe" == "yes" ]]; then extra="$extra --probe"; fi
  if [[ "$keep" == "yes" ]]; then extra="$extra --keep"; fi
  say "benching $sessions session(s) for ${seconds}s in $distro …"
  wsl_run "bash $dest/streaming/bench.sh --sessions $sessions --seconds $seconds --game $game \
    --size $size --players $players --label $label --out $remote$extra" \
    || fail "the benchmark failed"
  files="$(wsl_run "ls $remote/summaries 2>/dev/null" | tr -d '\r')"
  if [[ -z "$files" ]]; then
    fail "the benchmark left no summaries in $remote"
  fi
  for file in $files; do
    tools/wsl-fetch.sh "$distro" "$remote/summaries/$file" "$results_root/$label/$file" \
      || fail "could not copy $file out of $distro"
  done
  say "summaries copied to $results_root/$label"
  print_report "$results_root/$label"
}

cmd_stats() {
  if [[ ! -d "$results" ]]; then
    fail "no results at $results; run tools/stream.sh bench first"
  fi
  print_report "$results"
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
    build | up | bench | stats | status | logs | url | down)
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
    --sessions)
      sessions="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --seconds)
      seconds="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --game)
      game="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --size)
      size="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --players)
      players="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --label)
      label="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --results)
      results="${2:-}"
      shift 2 || { printf 'stream: %s needs a value\n' "$1" >&2; usage; exit 2; }
      ;;
    --probe)
      probe="yes"
      shift
      ;;
    --keep)
      keep="yes"
      shift
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
  bench) cmd_bench ;;
  stats) cmd_stats ;;
  status) cmd_status ;;
  logs) cmd_logs ;;
  url) cmd_url ;;
  down) cmd_down ;;
esac
