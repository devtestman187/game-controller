#!/usr/bin/env bash
# The Thumb Party streaming session (M15): build the session image from this
# checkout, run one or two sessions in the locked-down WSL distro, and look at
# them. The image and the player are described in streaming/README.md; it only
# ever runs `wsl -d <distro> ...` and the two helper scripts.
#
#   tools/stream.sh build
#   tools/stream.sh up [--name N] [--port-base P]
#   tools/stream.sh bench [--sessions N] [--seconds S] [--game arena|shape_race]
#                          [--viewer chrome|external] [--viewer-cpus L]
#                          [--session-cpus L]
#   tools/stream.sh stats [--results DIR]
#   tools/stream.sh status
#   tools/stream.sh keep-alive [--stop]
#   tools/stream.sh logs [--name N] [--follow]
#   tools/stream.sh url [--name N]
#   tools/stream.sh down [--name N | --all]
#   tools/stream.sh selftest
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
# The keep-alive (M15 t1): WSL stops a distro a few seconds after the last
# Windows process attached to it ends, which kills every session running in it.
# A detached `wsl ... sleep infinity` keeps it up; its pid lives in this file
# under the user's temp folder, so `status` and `down` find it again and only
# that one process is ever ended. STREAM_KEEPALIVE_FILE lets a test use its own.
readonly keepalive_file="${STREAM_KEEPALIVE_FILE:-${TEMP:-${TMPDIR:-/tmp}}/tp-stream-keepalive.pid}"

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
# How long a bench's press phase runs after the round, in seconds (M15 fix5), or
# empty to leave it to the bench: it gives an external viewer 30 s, since a
# person is there to press, and any other run none.
press_seconds=""
# Who watches the session a bench measures (M15 g1): a headless Chrome on this
# machine, or a person's own browser on the home network, whose URL the bench
# prints.
viewer="chrome"
# The cores a bench pins the viewer and the session to, or empty for none: a
# viewer on its own cores has the CPU to decode with (M15 g1).
viewer_cpus=""
session_cpus=""
# Extra session settings for an experiment (M15 t1): each `--set KEY=VALUE`
# reaches the container's `docker run` as one `-e`, so a tuning change needs no
# rebuild. The image's entrypoint reads them (streaming/README.md).
declare -a settings=()
# The player page's own switches for a bench (M15 fix7), as the query string the
# viewer opens (`audio=separate&lowdelay=1`): one URL works for the headless
# Chrome and for the owner's phone, so a page switch is measured the same way.
player_query=""
# Whether `keep-alive` was asked to end the keep-alive instead of showing it.
keep_alive_stop="no"
# Where the fetched summaries live, under docs/ so they stay with the reports.
# A bench writes its own folder under bench_results_root, named for the minute
# it starts, so runs never overwrite each other; stats reads the newest of those
# and falls back to the job folder that came before (M15 fix5).
readonly results_root="docs/briefs/m15/c2/results"
readonly bench_results_root="docs/briefs/m15/bench-results"
# The longest press phase a bench may be given, in seconds.
readonly press_max_s=600
# The folder a command reads or writes; empty means the rule above picks it.
results=""

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
  tools/stream.sh keep-alive [--stop]              the detached process that keeps the distro
                                                   (and its sessions) up; --stop ends it
  tools/stream.sh logs [--name N] [--follow]       a session's log
  tools/stream.sh url [--name N]                   the player URL and the controller address
  tools/stream.sh down [--name N | --all]          stop a session, or every session
  tools/stream.sh selftest                         the player relay's own tests, in the distro

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
  --press-seconds <n>  after the round, show the latency card and time the presses
                    for n seconds on the same session and viewer (0 is none; the
                    default is 30 with --viewer external, 0 otherwise)
  --viewer <kind>   chrome (default): a headless Chrome on this machine watches;
                    external: no browser is opened, the bench prints the player
                    URL and waits for a real viewer (a phone, tablet or TV on
                    the home network) to register before it measures; a phone run
                    ends with a press phase
  --viewer-cpus L   the cores the viewer's Chrome runs on (taskset's list, e.g. 8-15);
                    with --viewer chrome only, since a device you open is pinned there
  --session-cpus L  the cores the session container runs on (docker --cpuset-cpus)
  --label <name>    the run's name: its containers and its results folder
  --keep            leave the sessions running afterwards
  --set K=V         one more setting for the session container (streaming/README.md);
                    a bench experiment needs this rather than an image rebuild
  --player-query <q>  a player page switch, as key=value pairs joined by & (letters,
                    digits and = & _ . , - only): appended to the URL the viewer
                    opens and to the one printed for --viewer external, so a phone
                    opens the same switches the headless Chrome does
  --results <dir>   the folder of summaries: for stats it is what to read (default
                    the newest run under docs/briefs/m15/bench-results, else
                    docs/briefs/m15/c2/results), for bench where to write them
                    (default docs/briefs/m15/bench-results/<start time>)

The bench copies this checkout into the distro, starts the sessions there,
plays through a headless Chrome viewer (or, with --viewer external, through a
browser a person opens on the home network), fetches each session's summary into
<results>/<label>/ and runs the report over it. It ends by printing the folder
and the stats command that reads it again.

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

# Every `--set` is one environment setting for a session container: an upper-case
# name, then a value with no spaces, so it reaches `docker run` as one word. A
# list setting keeps its `=` and `,` (SESSION_PLAYER_OPTIONS=a=1,b=x, M15 fix7).
check_settings() {
  local setting
  for setting in "${settings[@]}"; do
    if [[ ! "$setting" =~ ^[A-Z][A-Z0-9_]*=[A-Za-z0-9._=,-]+$ ]]; then
      printf 'stream: a setting is KEY=VALUE (upper-case name, a plain value), got "%s"\n' "$setting" >&2
      exit 2
    fi
  done
}

# The player query a bench puts on the viewer's URL (M15 fix7): `key=value` pairs
# joined by `&`, in the characters a query uses and nothing that needs quoting,
# so the same string reaches Chrome's command line and the URL a person types.
check_player_query() {
  if [[ -z "$player_query" ]]; then
    return 0
  fi
  if [[ ! "$player_query" =~ ^[A-Za-z0-9=_.,\&-]+$ ]]; then
    printf 'stream: the player query is key=value pairs joined by & (letters, digits and = & _ . , -), got "%s"\n' \
      "$player_query" >&2
    exit 2
  fi
}

# The press phase's length for a bench: empty leaves it to the bench, anything
# else is a whole number of seconds up to press_max_s (M15 fix5).
check_press_seconds() {
  if [[ -z "$press_seconds" ]]; then
    return 0
  fi
  if [[ ! "$press_seconds" =~ ^[0-9]+$ ]] || (( press_seconds > press_max_s )); then
    printf 'stream: --press-seconds is a whole number of seconds 0 to %s, got "%s"\n' "$press_max_s" "$press_seconds" >&2
    exit 2
  fi
}

# Who watches a bench: a headless Chrome here, or a person's own browser on the
# home network (M15 g1). Anything else is refused before a session starts.
check_viewer() {
  if [[ "$viewer" != "chrome" && "$viewer" != "external" ]]; then
    printf 'stream: --viewer is chrome or external, got "%s"\n' "$viewer" >&2
    exit 2
  fi
  # Only the Chrome the bench starts can be pinned from here: a device a person
  # opens is pinned on that device, so the pair is refused rather than ignored
  # (M15 g1 review).
  if [[ "$viewer" != "chrome" && -n "$viewer_cpus" ]]; then
    printf 'stream: --viewer-cpus needs --viewer chrome: a viewer you open yourself is pinned on that device\n' >&2
    exit 2
  fi
}

# A core list as taskset and docker take one ("3", "0-7", "0-3,8-11"), or empty.
check_cpus() {
  local option="$1" cpus="$2"
  if [[ -n "$cpus" && ! "$cpus" =~ ^[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$ ]]; then
    printf 'stream: %s is a core list like 0-7 or 8-15, got "%s"\n' "$option" "$cpus" >&2
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

# The keep-alive's pid, when the process the pid file names still is it. The
# command line has to be the keep-alive's `sleep infinity`: a pid Windows has
# reused for something else must never be killed. `ps` is old in some Git Bash
# installs, so the command line comes from /proc when ps prints nothing.
keepalive_pid() {
  local pid args
  [[ -r "$keepalive_file" ]] || return 1
  pid="$(tr -cd '0-9' < "$keepalive_file")"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2> /dev/null || return 1
  args="$(ps -p "$pid" -o args= 2> /dev/null)"
  if [[ -z "$args" ]]; then
    args="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2> /dev/null)"
  fi
  [[ "$args" == *"sleep infinity"* ]] || return 1
  printf '%s' "$pid"
}

# Leaves one detached `wsl ... sleep infinity` attached to the distro, so WSL
# keeps it up after this script ends. Starts nothing when one already runs.
start_keepalive() {
  local pid
  if pid="$(keepalive_pid)"; then
    return 0
  fi
  nohup wsl -d "$distro" -u root -- sleep infinity > /dev/null 2>&1 &
  printf '%s\n' "$!" > "$keepalive_file"
  say "keep-alive: started (pid $!)"
}

# Ends the keep-alive this session started, and nothing else.
stop_keepalive() {
  local pid
  if pid="$(keepalive_pid)"; then
    kill -TERM "$pid" 2> /dev/null || true
    say "keep-alive: stopped (pid $pid)"
  fi
  rm -f "$keepalive_file"
}

# One line saying what the keep-alive is doing, for `status` and `keep-alive`.
keepalive_state() {
  local pid
  if pid="$(keepalive_pid)"; then
    printf 'keep-alive: running (pid %s)\n' "$pid"
  elif [[ -e "$keepalive_file" ]]; then
    printf 'keep-alive: not running (a stale pid file: %s)\n' "$keepalive_file"
  else
    printf 'keep-alive: not running\n'
  fi
}

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
  local container controller signal player automation gpu_flags ready extra=""
  check_name
  check_port_base
  check_settings
  container="$(container_name)"
  for setting in "${settings[@]}"; do extra="$extra -e $setting"; done
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
    -e AUTOMATION_PORT=$automation -e SESSION_NAME=$name $extra $image" > /dev/null \
    || fail "the session did not start (docker run failed)"

  # Once the session is up: without an attached Windows process the distro ends
  # a few seconds after this script does, and the session with it. Nothing that
  # failed before this point leaves a keep-alive holding the distro up (M15 g1).
  start_keepalive
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
  keepalive_state
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

# What a person opens, and from where. WSL is in mirrored networking mode (the
# owner's .wslconfig, Nov 11 2026), so the distro's own addresses are this PC's
# LAN address and another device on the home network reaches the session there;
# a browser on this PC uses localhost, where the media does not flow (README).
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
  # The picture only flows to another device (M15 g1): a browser on this same
  # PC opens the page and its numbers but gets no media, at either address, so
  # the LAN address is the one to use, from a phone, tablet or TV.
  say "player:     http://$address:$player/   watch here, from a phone, tablet or TV on the home network"
  say "            (http://localhost:$player/ on this PC has the page but no picture or sound)"
  say "controller: $address:$controller   from a phone on the home network (localhost:$controller on this PC)"
  say "signalling: $address:$signal"
  say "automation: 127.0.0.1:$automation in $distro (the token is /run/thumb-party/automation.token)"
}

# The keep-alive on its own: whether it runs, and --stop to end it. It never
# needs the distro to answer, so it works while the distro is asleep.
cmd_keep_alive() {
  if [[ "$keep_alive_stop" == "yes" ]]; then
    stop_keepalive
  fi
  keepalive_state
}

# Runs the analytics report over a folder of summaries on this machine: the
# report is Dart and the checkout's workspace is already resolved.
print_report() {
  dart run packages/metrics/bin/report.dart "$1"
}

# The switches line a bench wrote into its results folder (M15 fix7), fetched
# beside the summaries: what was on when the numbers were taken. A run from
# before the line existed has no file, and the report says nothing about it.
fetch_switches() {
  local remote="$1" target="$2"
  if wsl_run "test -f $remote/switches.txt"; then
    tools/wsl-fetch.sh "$distro" "$remote/switches.txt" "$target/switches.txt" > /dev/null \
      || fail "could not copy switches.txt out of $distro"
  fi
}

# Prints that line if the folder has it, or one label folder inside it (a bench
# leaves the run folder with the label folder inside, M15 fix7).
print_switches() {
  local folder="$1" file
  file="$folder/switches.txt"
  if [[ ! -f "$file" ]]; then
    file="$(ls -1 "$folder"/*/switches.txt 2> /dev/null | head -1)"
  fi
  if [[ -n "$file" && -f "$file" ]]; then
    say "$(cat "$file")"
  fi
}

# One benchmark (M15 c2): the sessions run inside the distro, the summaries
# come back into docs/, and the Streaming report is printed here.
cmd_bench() {
  local dest remote files file extra="" setting target
  if [[ ! "$label" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    fail "the label is lower-case letters, digits and dashes, got \"$label\""
  fi
  check_settings
  check_player_query
  check_viewer
  check_cpus "--viewer-cpus" "$viewer_cpus"
  check_cpus "--session-cpus" "$session_cpus"
  check_press_seconds
  # A run's own folder, named for the minute it starts: the label folder goes
  # inside it, and a later run never lands on an earlier one's summaries (M15
  # fix5). `--results` still says exactly where.
  if [[ -z "$results" ]]; then results="$bench_results_root/$(date +%Y%m%d-%H%M%S)"; fi
  target="$results/$label"
  for setting in "${settings[@]}"; do extra="$extra --set $setting"; done
  if [[ -n "$player_query" ]]; then extra="$extra --player-query '$player_query'"; fi
  if [[ -n "$press_seconds" ]]; then extra="$extra --press-seconds $press_seconds"; fi
  if [[ "$probe" == "yes" ]]; then extra="$extra --probe"; fi
  if [[ "$keep" == "yes" ]]; then extra="$extra --keep"; fi
  if [[ "$viewer" == "external" ]]; then extra="$extra --viewer external"; fi
  if [[ -n "$viewer_cpus" ]]; then extra="$extra --viewer-cpus $viewer_cpus"; fi
  if [[ -n "$session_cpus" ]]; then extra="$extra --session-cpus $session_cpus"; fi
  if ! wsl_run "docker image inspect $image > /dev/null 2>&1"; then
    fail "the image $image isn't in $distro yet: run tools/stream.sh build"
  fi
  dest="$(sync_repo)" || fail "the copy into $distro failed"
  remote="/work/stream-bench/$label"
  say "benching $sessions session(s) for ${seconds}s in $distro …"
  wsl_run "bash $dest/streaming/bench.sh --sessions $sessions --seconds $seconds --game $game \
    --size $size --players $players --label $label --out $remote$extra" \
    || fail "the benchmark failed"
  files="$(wsl_run "ls $remote/summaries 2>/dev/null" | tr -d '\r')"
  if [[ -z "$files" ]]; then
    fail "the benchmark left no summaries in $remote"
  fi
  for file in $files; do
    tools/wsl-fetch.sh "$distro" "$remote/summaries/$file" "$target/$file" \
      || fail "could not copy $file out of $distro"
  done
  say "summaries copied to $target"
  fetch_switches "$remote" "$target"
  # A bench that leaves its sessions running leaves the distro needing the
  # keep-alive too.
  if [[ "$keep" == "yes" ]]; then
    start_keepalive
  fi
  print_report "$target"
  print_switches "$target"
  say "results: $target"
  say "report again with: bash tools/stream.sh stats --results $target"
}

# The player relay's own tests (M15 g1) and the player page's (M15 fix8): the
# relay's script beside the code it checks, and the page's tests run by the
# headless Chrome, both where they run, in the distro. The relay's starts
# serve.py on free loopback ports and asks it the page's calls; the page's is
# bench.sh's own --selftest, so one command checks the page's scripts.
cmd_selftest() {
  local dest
  dest="$(sync_repo)" || fail "the copy into $distro failed"
  say "testing the player relay in $distro …"
  wsl_run "cd $dest && timeout 120 python3 streaming/player/relay_test.py" || fail "the relay's tests failed"
  say "testing the player page in $distro …"
  wsl_run "cd $dest && timeout 120 bash streaming/bench.sh --selftest" || fail "the player page's tests failed"
}

# The newest bench run under docs/, or nothing: a run's folder is named for the
# minute it started, so sorting the names puts the last run last (M15 fix5).
newest_results() {
  local name
  if [[ -d "$bench_results_root" ]]; then
    name="$(ls -1 "$bench_results_root" 2> /dev/null | sort | tail -1)"
  fi
  if [[ -n "${name:-}" ]]; then
    printf '%s/%s' "$bench_results_root" "$name"
  fi
}

cmd_stats() {
  if [[ -z "$results" ]]; then
    results="$(newest_results)"
    if [[ -z "$results" ]]; then results="$results_root"; fi
  fi
  if [[ ! -d "$results" ]]; then
    fail "no results at $results; run tools/stream.sh bench first"
  fi
  print_report "$results"
  print_switches "$results"
}

cmd_down() {
  local containers container
  if [[ "$all" == "yes" ]]; then
    containers="$(wsl_run "docker ps -a --filter label=$session_label --format {{.Names}}")" || fail "cannot ask $distro for its containers"
    if [[ -z "$containers" ]]; then
      say "no sessions to stop"
      stop_keepalive
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
  # The last session's end ends the keep-alive: nothing is left to hold the
  # distro up for, and a distro nobody uses should be allowed to sleep.
  if [[ -z "$(wsl_run "docker ps --filter label=$session_label --format {{.Names}}")" ]]; then
    stop_keepalive
  fi
}

while (( $# > 0 )); do
  case "$1" in
    build | up | bench | stats | status | keep-alive | logs | url | down | selftest)
      command="$1"
      shift
      ;;
    --set)
      settings+=("${2:-}")
      shift 2 || { printf 'stream: --set needs KEY=VALUE\n' >&2; usage; exit 2; }
      ;;
    --player-query)
      player_query="${2:-}"
      shift 2 || { printf 'stream: --player-query needs key=value pairs\n' >&2; usage; exit 2; }
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
    --press-seconds)
      press_seconds="${2:-}"
      shift 2 || { printf 'stream: --press-seconds needs a number of seconds\n' >&2; usage; exit 2; }
      ;;
    --viewer)
      viewer="${2:-}"
      shift 2 || { printf 'stream: --viewer needs chrome or external\n' >&2; usage; exit 2; }
      ;;
    --viewer-cpus)
      viewer_cpus="${2:-}"
      shift 2 || { printf 'stream: %s needs a core list\n' "$1" >&2; usage; exit 2; }
      ;;
    --session-cpus)
      session_cpus="${2:-}"
      shift 2 || { printf 'stream: %s needs a core list\n' "$1" >&2; usage; exit 2; }
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
    --stop)
      keep_alive_stop="yes"
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
  keep-alive) cmd_keep_alive ;;
  logs) cmd_logs ;;
  url) cmd_url ;;
  down) cmd_down ;;
  selftest) cmd_selftest ;;
esac
