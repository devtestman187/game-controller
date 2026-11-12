#!/bin/bash
# One streaming benchmark (M15 c2), run inside the locked-down distro: it
# starts N session containers, opens a viewer in headless Chrome on each,
# plays a round for the seconds asked, collects every session's summary
# (which now carries the stream record) and stops everything. tools/stream.sh
# bench copies this checkout in, runs this script and fetches the summaries.
#
#   bash streaming/bench.sh [--sessions N] [--seconds S] [--game arena|shape_race]
#     [--size 1920x1080] [--probe] [--players N] [--port-base P] [--label L]
#     [--out /work/dir] [--keep] [--set KEY=VALUE] [--press-seconds N]
#     [--viewer chrome|external] [--viewer-cpus L] [--session-cpus L]
#
# `--set` gives the session containers one more environment setting, which is
# how a tuning experiment runs without building the image again (M15 t1).
#
# `--probe` shows the latency test card instead of a round and times presses
# against the card's flips: press-to-screen is measured there, as its own
# series, because the card covers the picture (so the round's bitrate would not
# be the game's).
#
# `--viewer external` opens no browser (M15 g1): it prints the player's LAN
# address, waits for a real viewer to register, then measures against that
# viewer, so a phone, tablet or TV on the home network is the one being timed.
# A run with a press phase (M15 fix5) plays the round and then shows the latency
# card on the same session and the same viewer for `--press-seconds`, so one
# phone run gives the round's numbers and a measured press-to-screen; it is the
# default for `--viewer external`, where a person is there to press anyway.
# `--viewer-cpus` and `--session-cpus` pin the viewer's Chrome and the session
# container to different cores, so a run can say how much of the viewer's
# jitter buffer is its own CPU being shared with the session (M15 g1).
# `--viewer-cpus` needs `--viewer chrome`: a viewer a person opens is pinned on
# that device, not from here, so the pair is refused.
#
# It needs docker, curl and python3 (for reading the summaries' JSON), which
# the session image's host has; nothing here reaches outside the distro.
set -u

readonly image="tp-session:latest"
readonly container_prefix="thumb-party-"
readonly session_label="thumb-party.session"
readonly chrome_default="/opt/chrome-headless-shell/chrome-headless-shell-linux64/chrome-headless-shell"
# How long a session gets to print its ready line, in seconds: the app and the
# pipeline both start from cold, and the image's first frame takes a while.
readonly ready_timeout_s=120
# How long a session gets after its last frame to send a last batch, in
# seconds: the player's batch is 3 s, so one and a bit.
readonly settle_s=4
# How long an external viewer has to open the page and register, in seconds:
# a person has to find the address, type it and let the picture start.
readonly viewer_timeout_s=180
# How often the wait for that viewer says it is still waiting, in seconds.
readonly viewer_report_s=10
# The press phase's default length after a round, in seconds, and the longest a
# run may ask for (M15 fix5): an external viewer is there to press, so the same
# run measures press-to-screen; ten minutes is the whole bench's patience.
readonly press_default_s=30
readonly press_max_s=600

label="bench"
sessions=1
seconds=60
game="arena"
mode=""
width=1920
height=1080
players=1
port_base=45780
probe="no"
keep="no"
out=""
# How long the press phase runs after the round, in seconds (M15 fix5): empty
# until the arguments are read, so a run can tell "not given" from "0".
press_seconds=""
# Who watches the session (M15 g1): a headless Chrome here, or a person's own
# browser on the home network, whose URL this run prints and whose
# registration it waits for.
viewer="chrome"
# The cores a run pins the viewer and the session to, or empty for no pinning.
viewer_cpus=""
session_cpus=""
chrome="$chrome_default"
# Extra settings for the session containers, each one word of `-e KEY=VALUE`.
declare -a settings=()

# The viewer browsers this run started; the simulated players of each session
# are kept in the output folder, one id a line.
declare -a viewer_pids=()

say() { printf '%s\n' "$*"; }
fail() { printf 'bench: %s\n' "$*" >&2; exit 1; }
# Bad use: nothing ran, and the answer is the same as the outer tool's for the
# pair both refuse (M15 fix3 review).
refuse() { printf 'bench: %s\n' "$*" >&2; exit 2; }

usage() {
  cat <<'EOF'
One streaming benchmark (M15 c2), inside the distro.

  --sessions N     how many sessions run at once (default 1)
  --seconds S      how long the round (or the probe) runs (default 60)
  --game G         arena (bumper round) or shape_race (default arena)
  --probe          show the latency card and time presses instead of a round
  --press-seconds N  after the round, show the latency card and time the presses
                   for N seconds on the same session and viewer (0 is none; the
                   default is 30 with --viewer external and 0 otherwise)
  --size WxH       the screen and encoder size (default 1920x1080)
  --players N      simulated players per session (default 1)
  --port-base P    the first session's controller port; each session takes a
                   block of ten, signalling/player/automation are the next three
  --label L        the run's name: the containers and the output folder's name
  --out DIR        where the results go (default /work/stream-bench/L)
  --keep           leave the sessions running when the run ends
  --set K=V        one more setting for the session containers, repeated
  --viewer K       chrome (default) opens a headless Chrome; external opens
                   nothing, prints the LAN address and waits for a real viewer
  --viewer-cpus L  the cores the viewer's Chrome runs on, as taskset takes them
                   (with --viewer chrome only: a device you open is pinned there)
  --session-cpus L the cores the session containers run on (docker --cpuset-cpus)
  --help           this text
EOF
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --sessions) sessions="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --seconds) seconds="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --game) game="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --size) width="${2%x*}"; height="${2#*x}"; shift 2 || { usage; exit 2; } ;;
      --players) players="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --port-base) port_base="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --label) label="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --out) out="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --set) settings+=("${2:-}"); shift 2 || { usage; exit 2; } ;;
      --press-seconds) press_seconds="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --viewer) viewer="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --viewer-cpus) viewer_cpus="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --session-cpus) session_cpus="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --probe) probe="yes"; shift ;;
      --keep) keep="yes"; shift ;;
      --help | -h) usage; exit 0 ;;
      *) printf 'bench: unknown option "%s"\n' "$1" >&2; usage; exit 2 ;;
    esac
  done
}

check_args() {
  [[ "$label" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "the label is lower-case letters, digits and dashes"
  local setting
  for setting in "${settings[@]}"; do
    [[ "$setting" =~ ^[A-Z][A-Z0-9_]*=[A-Za-z0-9._-]+$ ]] \
      || fail "a setting is KEY=VALUE (upper-case name, a plain value), got \"$setting\""
  done
  [[ "$sessions" =~ ^[0-9]+$ ]] && (( sessions >= 1 && sessions <= 4 )) || fail "--sessions is 1 to 4"
  [[ "$seconds" =~ ^[0-9]+$ ]] && (( seconds >= 5 )) || fail "--seconds is 5 or more"
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || fail "--size is like 1920x1080"
  [[ "$players" =~ ^[0-9]+$ ]] && (( players >= 1 )) || fail "--players is 1 or more"
  [[ "$game" == "arena" || "$game" == "shape_race" ]] || fail "--game is arena or shape_race"
  [[ "$viewer" == "chrome" || "$viewer" == "external" ]] || fail "--viewer is chrome or external"
  check_press_seconds
  check_cpus "--viewer-cpus" "$viewer_cpus"
  check_cpus "--session-cpus" "$session_cpus"
  # Only the Chrome this script starts can be pinned from here; a viewer a person
  # opens is pinned on that device, and `--viewer-cpus` beside it would be read
  # and do nothing (M15 g1 review).
  [[ "$viewer" == "chrome" || -z "$viewer_cpus" ]] \
    || refuse "--viewer-cpus needs --viewer chrome: a viewer you open yourself is pinned on that device"
  if [[ "$game" == "arena" ]]; then mode="bumper"; fi
  out="${out:-/work/stream-bench/$label}"
}

# The press phase's length: a whole number of seconds up to [press_max_s]. Not
# given, an external viewer gets [press_default_s] after the round — the person
# watching is there to press, and the card covers the picture, so its presses
# cannot share the round's window — and any other run gets none (M15 fix5).
check_press_seconds() {
  if [[ -z "$press_seconds" ]]; then
    press_seconds=0
    if [[ "$viewer" == "external" && "$probe" == "no" ]]; then press_seconds="$press_default_s"; fi
  fi
  [[ "$press_seconds" =~ ^[0-9]+$ ]] && (( press_seconds <= press_max_s )) \
    || fail "--press-seconds is a whole number of seconds 0 to $press_max_s"
}

# A core list as taskset and docker take one: "3", "0-7", "0-3,8-11", or empty.
check_cpus() {
  local option="$1" cpus="$2"
  if [[ -n "$cpus" && ! "$cpus" =~ ^[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$ ]]; then
    fail "$option is a core list like 0-7 or 8-15, got \"$cpus\""
  fi
}

# --- per-session settings ---------------------------------------------------
name_of() { printf '%s%d' "$label" "$1"; }
controller_of() { printf '%s' "$((port_base + $1 * 10))"; }
signal_of() { printf '%s' "$((port_base + $1 * 10 + 1))"; }
player_of() { printf '%s' "$((port_base + $1 * 10 + 2))"; }
automation_of() { printf '%s' "$((port_base + $1 * 10 + 3))"; }
container_of() { printf '%s%s' "$container_prefix" "$(name_of "$1")"; }
automation_url() { printf 'http://127.0.0.1:%s' "$(automation_of "$1")"; }
relay_url() { printf 'http://127.0.0.1:%s' "$(player_of "$1")"; }

# This machine's LAN address, as the next device on the home network sees it
# (mirrored networking, streaming/README.md): a viewer's own browser must use
# this one, because this PC's loopback gets the page but no media (M15 g1).
lan_address() { hostname -I | awk '{print $1}'; }

# One automation call, with the session's token, answering the body's text.
aut() {
  local index="$1" method="$2" path="$3" body="${4:-}" token
  token="$(cat "$out/token-$index" 2>/dev/null)"
  if [[ -n "$body" ]]; then
    curl -s --max-time 10 -X "$method" -H "x-automation-token: $token" \
      -H 'content-type: application/json' -d "$body" "$(automation_url "$index")/automation/v1$path"
  else
    curl -s --max-time 10 -X "$method" -H "x-automation-token: $token" \
      "$(automation_url "$index")/automation/v1$path"
  fi
}

# The first number after "name": in a JSON text, or nothing.
json_number() { printf '%s' "$1" | grep -o "\"$2\": *[0-9]*" | head -1 | grep -o '[0-9]*$'; }

# The first string after "name": in a JSON text, or nothing.
json_text() { printf '%s' "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | sed 's/.*: *"//; s/"$//'; }

# --- the run ----------------------------------------------------------------
gpu_flags() {
  if [[ -e /dev/dxg ]]; then
    printf '%s' "--device /dev/dxg -v /usr/lib/wsl:/usr/lib/wsl:ro -e LD_LIBRARY_PATH=/usr/lib/wsl/lib"
  fi
}

start_session() {
  local index="$1" container extra="" setting cpuset=""
  container="$(container_of "$index")"
  for setting in "${settings[@]}"; do extra="$extra -e $setting"; done
  if [[ -n "$session_cpus" ]]; then cpuset="--cpuset-cpus $session_cpus"; fi
  docker rm -f "$container" > /dev/null 2>&1 || true
  # --network host: the media is UDP to the viewer, and the benchmark talks to
  # the automation port from this same machine (streaming/README.md).
  docker run -d --name "$container" --label "$session_label=$(name_of "$index")" \
    --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all $(gpu_flags) --network host $cpuset \
    -e GALLIUM_DRIVER=d3d12 -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA \
    -e CONTROLLER_PORT="$(controller_of "$index")" -e SIGNAL_PORT="$(signal_of "$index")" \
    -e PLAYER_PORT="$(player_of "$index")" -e AUTOMATION_PORT="$(automation_of "$index")" \
    -e SESSION_NAME="$(name_of "$index")" -e SESSIONS_AT_ONCE="$sessions" \
    -e SESSION_WIDTH="$width" -e SESSION_HEIGHT="$height" $extra \
    "$image" > /dev/null || fail "session $index did not start"
}

# Waits for a session's ready line, answering how many seconds it took.
wait_ready() {
  local container waited=0
  container="$(container_of "$1")"
  while (( waited < ready_timeout_s )); do
    if docker logs "$container" 2>&1 | grep -q ' ready: '; then
      printf '%s' "$waited"
      return 0
    fi
    if [[ "$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)" == "exited" ]]; then
      docker logs --tail 30 "$container" >&2
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  docker logs --tail 30 "$container" >&2
  return 1
}

# The session's own token, from the file its entrypoint wrote (0600, in the
# container's run directory).
read_token() {
  docker exec "$(container_of "$1")" cat /run/thumb-party/automation.token > "$out/token-$1" \
    || fail "session $1 has no automation token"
}

start_viewer() {
  local index="$1" pinned=()
  if [[ -n "$viewer_cpus" ]]; then pinned=(taskset -c "$viewer_cpus"); fi
  # A viewer on its own cores shows what the session can do when the viewer's
  # decoding is not competing with it (M15 g1).
  "${pinned[@]}" "$chrome" --no-sandbox --disable-gpu --mute-audio \
    --autoplay-policy=no-user-gesture-required \
    --user-data-dir="$out/chrome-$index-profile" \
    "http://127.0.0.1:$(player_of "$index")/" > "$out/chrome-$index.log" 2>&1 &
  viewer_pids+=("$!")
}

# Waits until a session's page says it plays, up to [timeout] seconds.
wait_playing() {
  local index="$1" timeout="$2" waited=0 state
  while (( waited < timeout )); do
    state="$(curl -s --max-time 2 "$(relay_url "$index")/player")"
    if [[ "$state" == *'"state": "playing"'* ]]; then
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done
  printf 'bench: session %s never played: %s\n' "$index" "$state" >&2
  return 1
}

# The address a person opens on their own device, one a session (M15 g1): the
# LAN one, because this PC's loopback gets the page but no picture or sound.
print_viewer_url() {
  local index address
  address="$(lan_address)"
  for (( index = 0; index < sessions; index++ )); do
    say "$(name_of "$index"): open http://$address:$(player_of "$index")/ on a phone, tablet or TV on the home network"
  done
  say "the session is playing; waiting up to ${viewer_timeout_s}s for a viewer, a line every ${viewer_report_s}s"
}

# Whether a stats answer holds a viewer with receive data: a received bitrate
# gauge, or a stage only a decoded picture produces. A page that connected and
# stayed black sends neither (M15 fix5).
has_receive_data() {
  local text="$1"
  [[ "$text" == *'"bitrateReceivedKbps"'* ]] || [[ "$text" == *'"stream_display"'* ]] \
    || [[ "$text" == *'"stream_decode"'* ]]
}

# Waits until a session's stats name a viewer with receive data, which is what a
# page sends once it plays (M15 g1): the real device is then the one being timed.
# A page that connected and showed no picture also registers a row, with the
# host's stages only, so it must not satisfy this wait (M15 fix5). It says so
# every [viewer_report_s] seconds, and gives up after [viewer_timeout_s].
wait_viewer() {
  local index="$1" waited=0 since_report=0 body
  while (( waited < viewer_timeout_s )); do
    body="$(aut "$index" GET /stats/session)"
    if has_receive_data "$body"; then
      say "$(name_of "$index"): a viewer registered after ${waited}s"
      return 0
    fi
    if (( since_report == 0 )); then
      say "$(name_of "$index"): still no viewer after ${waited}s"
    fi
    sleep 2
    waited=$((waited + 2))
    since_report=$(((since_report + 2) % viewer_report_s))
  done
  printf 'bench: session %s had no viewer in %ss\n' "$index" "$viewer_timeout_s" >&2
  return 1
}

add_players() {
  local index="$1" count="$2" added=0 body id
  : > "$out/player-$index"
  while (( added < count )); do
    body="$(aut "$index" POST /players '{}')"
    id="$(json_text "$body" id)"
    if [[ -z "$id" ]]; then
      printf 'bench: session %s added no player: %s\n' "$index" "$body" >&2
      return 1
    fi
    printf '%s\n' "$id" >> "$out/player-$index"
    added=$((added + 1))
  done
}

# Starts the round and waits until the app says it is on the game screen, then
# checks it is still there a few seconds later. A start that arrives while the
# session is still warming up is lost (the app is still on its home screen a
# minute later), and one that is replaced by a repeat can leave the status
# saying home: either shows up as no round, which is sent again. A round that
# came up restarts at worst, and the window is measured from after this.
start_round() {
  local index="$1" body="$2" tries=0 waited status
  while (( tries < 4 )); do
    aut "$index" POST /game/start "$body" > /dev/null
    waited=0
    while (( waited < 15 )); do
      status="$(aut "$index" GET /status)"
      if [[ "$status" == *'"screen":"game"'* ]]; then
        sleep 3
        status="$(aut "$index" GET /status)"
        if [[ "$status" == *'"screen":"game"'* ]]; then
          return 0
        fi
        break
      fi
      sleep 1
      waited=$((waited + 1))
    done
    tries=$((tries + 1))
  done
  printf 'bench: session %s never showed a round: %s\n' "$index" "$status" >&2
  return 1
}

# Shows the latency card (the probe run) or starts the round (the round run).
start_activity() {
  local index="$1" body
  if [[ "$probe" == "yes" ]]; then
    aut "$index" POST /probe/flash '{"on": true}' > /dev/null
    sleep 1
    return 0
  fi
  body="{\"game\": \"$game\""
  if [[ -n "$mode" ]]; then
    body="$body, \"mode\": \"$mode\""
  fi
  start_round "$index" "$body}"
}

# One press the player times (the probe run): the card flips on `probe/press`,
# and the press's host time goes to the page, which finds the first flip after
# it in the picture. Presses follow an observed flip, so the press's own flip
# is the next change and the card's 500 ms cadence does not get in the way.
press_loop() {
  local index="$1" player="$2" until_s=$((SECONDS + $3))
  local relay seen=0 flips ident press press_ms
  relay="$(relay_url "$index")"
  while (( SECONDS < until_s )); do
    flips="$(curl -s --max-time 2 "$relay/flips?since=$seen")"
    ident="$(printf '%s' "$flips" | grep -o '"id": [0-9]*' | head -1 | grep -o '[0-9]*$')"
    if [[ -z "$ident" ]]; then
      sleep 0.1
      continue
    fi
    seen="$ident"
    press="$(aut "$index" POST /probe/press "{\"player\": \"$player\"}")"
    press_ms="$(json_number "$press" hostMs)"
    if [[ -z "$press_ms" ]]; then
      printf 'bench: session %s refused a press: %s\n' "$index" "$press" >&2
      # Kept for the line a press phase that measured nothing prints: the loop
      # runs in its own process, so the count cannot be a variable here.
      printf '%s\n' "$press" >> "$out/refused-$index"
      sleep 1
      continue
    fi
    curl -s --max-time 2 -X POST -H 'content-type: application/json' \
      -d "{\"hostMs\": $press_ms}" "$relay/presses" > /dev/null
    # One press per flip, and time for the press's own flip to be seen.
    sleep 0.4
  done
}

# The probe window: one press loop a session for the seconds given, all running
# together.
run_probe_window() {
  local window_s="$1" index pids=()
  for (( index = 0; index < sessions; index++ )); do
    press_loop "$index" "$(head -1 "$out/player-$index")" "$window_s" &
    pids+=("$!")
  done
  if (( ${#pids[@]} > 0 )); then
    wait "${pids[@]}"
  fi
}

# One session's stats answer, written to [file]: the session's summary is inside
# it, and so is every viewer's record. `collect_session` keeps it as the run's
# evidence, and a press phase keeps the round's own copy before the card goes up.
fetch_session() {
  printf '%s' "$(aut "$1" GET /stats/session)" > "$2"
}

# After the round: the session's summary with its stream record, and the logs
# that say where each number came from. The summary file is what the report
# reads, so a run's evidence is one JSON per session.
collect_session() {
  local index="$1" container name
  container="$(container_of "$index")"
  name="$(name_of "$index")"
  if [[ "$probe" == "no" ]]; then
    aut "$index" POST /game/stop '{}' > /dev/null
  fi
  # The player's last batch is up to one interval away; wait for one more.
  sleep "$settle_s"
  fetch_session "$index" "$out/session-$index.json"
  if ! python3 - "$out/session-$index.json" "$out/summaries/$name.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
session = doc.get("session") if isinstance(doc, dict) else None
if not isinstance(session, dict):
    sys.exit(1)
json.dump(session, open(sys.argv[2], "w", encoding="utf-8"), indent=1)
PY
  then
    printf 'bench: session %s has no summary yet, see %s\n' "$index" "$out/session-$index.json" >&2
  fi
  docker cp "$container:/run/thumb-party/pipeline.json" "$out/pipeline-$name.json" > /dev/null 2>&1 || true
  docker cp "$container:/run/thumb-party/sampler.log" "$out/sampler-$name.log" > /dev/null 2>&1 || true
  docker cp "$container:/run/thumb-party/app.log" "$out/app-$name.log" > /dev/null 2>&1 || true
  docker logs "$container" > "$out/container-$name.log" 2>&1 || true
}

# The press phase (M15 fix5): the round's own numbers are kept first, then the
# latency card goes up over the same session and the same viewer for
# [press_seconds], so one phone run gives a round and a measured press-to-screen.
# The game keeps running throughout: the host drops a viewer's batch when no
# session is live, so the round is stopped only after the presses.
start_press_phase() {
  local index
  for (( index = 0; index < sessions; index++ )); do
    fetch_session "$index" "$out/session-$index-round.json"
    aut "$index" POST /probe/flash '{"on": true}' > /dev/null
  done
  # The card covers the picture: one second for the change to reach the viewer,
  # then the presses start from a card the page already sees.
  sleep 1
  say "measuring ${press_seconds}s of presses"
  run_probe_window "$press_seconds"
}

# One line per session whose press phase measured nothing (M15 fix5): the run
# says what it saw rather than ending silently. A press the session refused, or
# a flip the page never found in the picture, leaves no press stage behind.
check_presses() {
  local index name flips refused
  for (( index = 0; index < sessions; index++ )); do
    name="$(name_of "$index")"
    if grep -q '"press_to_screen"' "$out/summaries/$name.json" 2>/dev/null; then
      continue
    fi
    flips="$(curl -s --max-time 2 "$(relay_url "$index")/flips?since=0" | grep -c '"id"')"
    refused="$(wc -l < "$out/refused-$index" 2>/dev/null || echo 0)"
    say "$name: no press_to_screen after the press phase: the relay saw $flips flip(s), $refused press(es) refused"
  done
}

# Stops every session this run started and every viewer it opened.
stop_all() {
  local index
  for index in "${!viewer_pids[@]}"; do
    kill -TERM "${viewer_pids[index]}" 2>/dev/null || true
  done
  if [[ "$keep" == "yes" ]]; then
    say "kept: $(for (( i = 0; i < sessions; i++ )); do printf '%s ' "$(container_of "$i")"; done)"
    return 0
  fi
  for (( i = 0; i < sessions; i++ )); do
    docker rm -f "$(container_of "$i")" > /dev/null 2>&1 || true
  done
}

# The bitrate the session was told to keep, from the ready line it printed (the
# entrypoint's defaults included): the number the received bitrate is checked
# against (M15 t1).
bitrate_ceiling() {
  docker logs "$(container_of "$1")" 2>&1 | grep -m1 -o ' [0-9]*kbit/s' | grep -o '[0-9]*' | head -1
}

# The received bitrate a viewer counted, in kbit/s, or nothing: the mean of the
# first viewer's `bitrateReceivedKbps` gauge. The file may be a session's summary
# or the stats answer that carries it, whose keys share one line.
received_kbps() {
  python3 - "$1" <<'PY' 2> /dev/null
import json, sys

try:
    doc = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError):
    sys.exit(0)
if isinstance(doc, dict) and isinstance(doc.get("session"), dict):
    doc = doc["session"]
stream = doc.get("stream") if isinstance(doc, dict) else None
viewers = stream.get("viewers") if isinstance(stream, dict) else None
for viewer in viewers or []:
    gauge = (viewer.get("gauges") or {}).get("bitrateReceivedKbps")
    if gauge and gauge.get("mean") is not None:
        print("%.0f" % gauge["mean"])
        break
PY
}

# The game's own drawing, from a session's resource readings (M15 k1): its frame
# rate, the mean frame interval, what a frame's build and raster cost and the
# share of frames over one 60 Hz frame, or nothing when the sampler read none.
# The file may be a session's summary or the stats answer that carries it.
game_frames() {
  python3 - "$1" <<'PY' 2> /dev/null
import json, sys

try:
    doc = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError):
    sys.exit(0)
if isinstance(doc, dict) and isinstance(doc.get("session"), dict):
    doc = doc["session"]
stream = doc.get("stream") if isinstance(doc, dict) else None
host = stream.get("host") if isinstance(stream, dict) else None
gauges = host.get("gauges") if isinstance(host, dict) else None

def mean(name):
    gauge = (gauges or {}).get(name)
    return gauge.get("mean") if isinstance(gauge, dict) else None

fps = mean("gameFps")
frame = mean("gameFrameMs")
build = mean("frameBuildMs")
raster = mean("frameRasterMs")
slow = mean("slowFramePct")
if fps is None and frame is None:
    sys.exit(0)
parts = []
if fps is not None:
    parts.append("%.1f fps" % fps)
if frame is not None:
    parts.append("%.1f ms/frame" % frame)
if build is not None and raster is not None:
    parts.append("build %.1f + raster %.1f ms" % (build, raster))
if slow is not None:
    parts.append("%.0f%% slow" % slow)
print("game " + ", ".join(parts))
PY
}

# Each viewer that reported numbers, as "kind/platform" (M15 g1): who was timed,
# with the host's cleaned strings and no user agent kept. A row that holds only
# the host's own stages is left out, as the report leaves it out (M15 fix5). The
# file may be a session's summary or the stats answer that carries it.
viewer_kinds() {
  python3 - "$1" <<'PY' 2> /dev/null
import json, sys

# The stages only the host writes: its pipeline and the press's way through it
# (M15 fix5, k1), which a page copies into its batch.
HOST_STAGES = {"stream_capture", "stream_encode", "stream_send", "stream_total",
               "host_tick", "host_build", "host_raster"}

def receive_data(viewer):
    if viewer.get("gauges") or viewer.get("counters"):
        return True
    return any(stage.get("name") not in HOST_STAGES for stage in viewer.get("stages") or [])

try:
    doc = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError):
    sys.exit(0)
if isinstance(doc, dict) and isinstance(doc.get("session"), dict):
    doc = doc["session"]
stream = doc.get("stream") if isinstance(doc, dict) else None
viewers = stream.get("viewers") if isinstance(stream, dict) else None
for viewer in viewers or []:
    if receive_data(viewer):
        print("%s/%s" % (viewer.get("kind") or "?", viewer.get("platform") or "?"))
PY
}

# Prints what the run produced, so the log of a benchmark says its numbers: the
# viewers that reported numbers and who they were, the bitrate the session kept
# against the ceiling it was given, the game's own frame stats (M15 k1) and where
# the evidence is. In a run with a press phase the bitrate comes from the round's
# own snapshot: the card's nearly still picture would dilute it (M15 fix5).
report_run() {
  local index name summary counted ceiling received who frames
  for (( index = 0; index < sessions; index++ )); do
    name="$(name_of "$index")"
    summary="$out/summaries/$name.json"
    if [[ ! -f "$summary" ]]; then
      say "$name: no summary"
      continue
    fi
    if [[ -f "$out/session-$index-round.json" ]]; then summary="$out/session-$index-round.json"; fi
    ceiling="$(bitrate_ceiling "$index")"
    received="$(received_kbps "$summary")"
    who="$(viewer_kinds "$summary" | paste -sd, -)"
    counted="$(viewer_kinds "$summary" | grep -c . || true)"
    frames="$(game_frames "$summary")"
    say "$name: $counted viewer(s) ${who:-(none)}, ${received:--} kbit/s received against the ${ceiling:--} kbit/s ceiling, summary $(wc -c < "$summary") bytes${frames:+, $frames}"
  done
  say "results in $out"
}

main() {
  parse_args "$@"
  check_args
  mkdir -p "$out/summaries"
  # Whatever ends the run — the window, a failure, Ctrl-C — the sessions and
  # their viewers are stopped, so a repeat run starts from nothing.
  trap stop_all EXIT
  command -v docker > /dev/null || fail "docker is not here"
  if [[ "$viewer" == "chrome" ]]; then
    command -v "$chrome" > /dev/null || fail "no headless Chrome at $chrome"
  fi

  local index ready started_s
  started_s=$SECONDS
  for (( index = 0; index < sessions; index++ )); do
    start_session "$index"
  done
  for (( index = 0; index < sessions; index++ )); do
    ready="$(wait_ready "$index")" || fail "session $index was not ready in ${ready_timeout_s}s"
    read_token "$index"
    say "$(name_of "$index"): ready after ${ready}s"
    if [[ "$viewer" == "chrome" ]]; then start_viewer "$index"; fi
  done
  # The viewer is in place before anything is measured: a headless Chrome that
  # has started playing, or a person's own device that has registered. Only a
  # session that is playing accepts a viewer's batch (the host drops one that
  # arrives on the home screen), so the external viewer waits here, after the
  # round or the card has started.
  if [[ "$viewer" == "chrome" ]]; then
    for (( index = 0; index < sessions; index++ )); do
      wait_playing "$index" 60 || fail "the viewer of session $index did not play"
    done
  fi
  for (( index = 0; index < sessions; index++ )); do
    add_players "$index" "$players" || fail "session $index has no player"
    start_activity "$index" || fail "session $index did not start its round"
  done
  if [[ "$viewer" == "external" ]]; then
    print_viewer_url
    for (( index = 0; index < sessions; index++ )); do
      wait_viewer "$index" || fail "session $index had no viewer"
    done
  fi

  # The measured window: a round of play, or the card and its presses. Both
  # sessions are measured together, so "sessions at once" is what they saw.
  say "measuring ${seconds}s on $sessions session(s), ${width}x${height}, $game$( [[ "$probe" == "yes" ]] && printf ' (probe)' || true)"
  if [[ "$probe" == "yes" ]]; then
    run_probe_window "$seconds"
  else
    sleep "$seconds"
  fi
  say "the window ended after $((SECONDS - started_s))s"

  # A round run with a press phase measures the presses after it, on the same
  # session and viewer, before anything is stopped (M15 fix5).
  if (( press_seconds > 0 )); then
    start_press_phase
  fi
  for (( index = 0; index < sessions; index++ )); do
    collect_session "$index"
  done
  if (( press_seconds > 0 )); then
    check_presses
  fi
  report_run
  stop_all
}

main "$@"

