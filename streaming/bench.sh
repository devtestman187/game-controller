#!/bin/bash
# One streaming benchmark (M15 c2), run inside the locked-down distro: it
# starts N session containers, opens a viewer in headless Chrome on each,
# plays a round for the seconds asked, collects every session's summary
# (which now carries the stream record) and stops everything. tools/stream.sh
# bench copies this checkout in, runs this script and fetches the summaries.
#
#   bash streaming/bench.sh [--sessions N] [--seconds S] [--game arena|shape_race]
#     [--size 1920x1080] [--probe] [--players N] [--port-base P] [--label L]
#     [--out /work/dir] [--keep]
#
# `--probe` shows the latency test card instead of a round and times presses
# against the card's flips: press-to-screen is measured there, as its own
# series, because the card covers the picture (so the round's bitrate would not
# be the game's).
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
chrome="$chrome_default"

# The viewer browsers this run started; the simulated players of each session
# are kept in the output folder, one id a line.
declare -a viewer_pids=()

say() { printf '%s\n' "$*"; }
fail() { printf 'bench: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
One streaming benchmark (M15 c2), inside the distro.

  --sessions N     how many sessions run at once (default 1)
  --seconds S      how long the round (or the probe) runs (default 60)
  --game G         arena (bumper round) or shape_race (default arena)
  --probe          show the latency card and time presses instead of a round
  --size WxH       the screen and encoder size (default 1920x1080)
  --players N      simulated players per session (default 1)
  --port-base P    the first session's controller port; each session takes a
                   block of ten, signalling/player/automation are the next three
  --label L        the run's name: the containers and the output folder's name
  --out DIR        where the results go (default /work/stream-bench/L)
  --keep           leave the sessions running when the run ends
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
      --probe) probe="yes"; shift ;;
      --keep) keep="yes"; shift ;;
      --help | -h) usage; exit 0 ;;
      *) printf 'bench: unknown option "%s"\n' "$1" >&2; usage; exit 2 ;;
    esac
  done
}

check_args() {
  [[ "$label" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "the label is lower-case letters, digits and dashes"
  [[ "$sessions" =~ ^[0-9]+$ ]] && (( sessions >= 1 && sessions <= 4 )) || fail "--sessions is 1 to 4"
  [[ "$seconds" =~ ^[0-9]+$ ]] && (( seconds >= 5 )) || fail "--seconds is 5 or more"
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || fail "--size is like 1920x1080"
  [[ "$players" =~ ^[0-9]+$ ]] && (( players >= 1 )) || fail "--players is 1 or more"
  [[ "$game" == "arena" || "$game" == "shape_race" ]] || fail "--game is arena or shape_race"
  if [[ "$game" == "arena" ]]; then mode="bumper"; fi
  out="${out:-/work/stream-bench/$label}"
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
  local index="$1" container
  container="$(container_of "$index")"
  docker rm -f "$container" > /dev/null 2>&1 || true
  # --network host: the media is UDP to the viewer, and the benchmark talks to
  # the automation port from this same machine (streaming/README.md).
  docker run -d --name "$container" --label "$session_label=$(name_of "$index")" \
    --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all $(gpu_flags) --network host \
    -e GALLIUM_DRIVER=d3d12 -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA \
    -e CONTROLLER_PORT="$(controller_of "$index")" -e SIGNAL_PORT="$(signal_of "$index")" \
    -e PLAYER_PORT="$(player_of "$index")" -e AUTOMATION_PORT="$(automation_of "$index")" \
    -e SESSION_NAME="$(name_of "$index")" -e SESSIONS_AT_ONCE="$sessions" \
    -e SESSION_WIDTH="$width" -e SESSION_HEIGHT="$height" \
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
  local index="$1"
  "$chrome" --no-sandbox --disable-gpu --mute-audio \
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
      sleep 1
      continue
    fi
    curl -s --max-time 2 -X POST -H 'content-type: application/json' \
      -d "{\"hostMs\": $press_ms}" "$relay/presses" > /dev/null
    # One press per flip, and time for the press's own flip to be seen.
    sleep 0.4
  done
}

# The probe window: one press loop a session, all running together.
run_probe_window() {
  local index pids=()
  for (( index = 0; index < sessions; index++ )); do
    press_loop "$index" "$(head -1 "$out/player-$index")" "$seconds" &
    pids+=("$!")
  done
  if (( ${#pids[@]} > 0 )); then
    wait "${pids[@]}"
  fi
}

# After the round: the session's summary with its stream record, and the logs
# that say where each number came from. The summary file is what the report
# reads, so a run's evidence is one JSON per session.
collect_session() {
  local index="$1" container name body
  container="$(container_of "$index")"
  name="$(name_of "$index")"
  if [[ "$probe" == "no" ]]; then
    aut "$index" POST /game/stop '{}' > /dev/null
  fi
  # The player's last batch is up to one interval away; wait for one more.
  sleep "$settle_s"
  body="$(aut "$index" GET /stats/session)"
  printf '%s' "$body" > "$out/session-$index.json"
  if ! python3 - "$out/session-$index.json" "$out/summaries/$name.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
session = doc.get("session") if isinstance(doc, dict) else None
if not isinstance(session, dict):
    sys.exit(1)
json.dump(session, open(sys.argv[2], "w", encoding="utf-8"), indent=1)
PY
  then
    printf 'bench: session %s has no summary yet: %s\n' "$index" "$body" >&2
  fi
  docker cp "$container:/run/thumb-party/pipeline.json" "$out/pipeline-$name.json" > /dev/null 2>&1 || true
  docker cp "$container:/run/thumb-party/sampler.log" "$out/sampler-$name.log" > /dev/null 2>&1 || true
  docker cp "$container:/run/thumb-party/app.log" "$out/app-$name.log" > /dev/null 2>&1 || true
  docker logs "$container" > "$out/container-$name.log" 2>&1 || true
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

# Prints what the run produced, so the log of a benchmark says its numbers.
report_run() {
  local index name summary
  for (( index = 0; index < sessions; index++ )); do
    name="$(name_of "$index")"
    summary="$out/summaries/$name.json"
    if [[ -f "$summary" ]]; then
      say "$name: $(grep -c '"kind": "browser"' "$summary") viewer(s), summary $(wc -c < "$summary") bytes"
    else
      say "$name: no summary"
    fi
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
  command -v "$chrome" > /dev/null || fail "no headless Chrome at $chrome"

  local index ready started_s
  started_s=$SECONDS
  for (( index = 0; index < sessions; index++ )); do
    start_session "$index"
  done
  for (( index = 0; index < sessions; index++ )); do
    ready="$(wait_ready "$index")" || fail "session $index was not ready in ${ready_timeout_s}s"
    read_token "$index"
    say "$(name_of "$index"): ready after ${ready}s"
    start_viewer "$index"
  done
  for (( index = 0; index < sessions; index++ )); do
    wait_playing "$index" 60 || fail "the viewer of session $index did not play"
  done
  for (( index = 0; index < sessions; index++ )); do
    add_players "$index" "$players" || fail "session $index has no player"
    start_activity "$index" || fail "session $index did not start its round"
  done

  # The measured window: a round of play, or the card and its presses. Both
  # sessions are measured together, so "sessions at once" is what they saw.
  say "measuring ${seconds}s on $sessions session(s), ${width}x${height}, $game$( [[ "$probe" == "yes" ]] && printf ' (probe)' || true)"
  if [[ "$probe" == "yes" ]]; then
    run_probe_window
  else
    sleep "$seconds"
  fi
  say "the window ended after $((SECONDS - started_s))s"

  for (( index = 0; index < sessions; index++ )); do
    collect_session "$index"
  done
  report_run
  stop_all
}

main "$@"

