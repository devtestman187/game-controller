#!/bin/bash
# One Thumb Party streaming session inside a container (M15): a virtual screen
# that is itself the video source (gst-wayland-display), the TV app drawing into
# it, a PulseAudio null sink carrying the game's sound, NVENC encoding video and
# Opus audio into webrtcsink, the signalling server and a static web server for
# the player.
#
# Every setting has a default and takes an environment variable, so one image
# runs any number of sessions side by side; tools/stream.sh sets the ports per
# session. The design and the measurements behind this pipeline are in
# docs/design/streaming-custom.md and docs/briefs/m15/capture-probe-report.md.
#
# It writes one `ready: ...` line to its log when the game window is up, the
# pipeline is PLAYING and a player can connect; tools/stream.sh up waits for it.
set -u

# --- settings ---------------------------------------------------------------
# The window the app opens with and the size the encoder works in.
width="${SESSION_WIDTH:-1920}"
height="${SESSION_HEIGHT:-1080}"
frame_rate="${SESSION_FRAME_RATE:-60}"
# 10 Mbit/s is the starting point the design names for 1080p60 at low delay.
bitrate_kbps="${SESSION_BITRATE_KBPS:-10000}"
# A keyframe a second, so a player that joins or reconnects sees a picture at
# once and a lost packet costs at most one second.
gop_frames="${SESSION_GOP_FRAMES:-${frame_rate}}"
# nvh264enc is broken on this driver (M15 wsl2 probe); the auto and cuda
# elements both work. The image carries gst-plugins-rs and NVENC only.
encoder="${SESSION_ENCODER:-nvautogpuh264enc}"
# Opus at 96 kbit/s carries the game's music and effects with room to spare.
audio_bitrate_bps="${SESSION_AUDIO_BITRATE_BPS:-96000}"

# The ports inside the session. tools/stream.sh gives each session its own.
# The app has the last word on the controller port: it tries this one and takes
# any free port when it is busy, and wait_ready reports the one it got.
controller_port="${CONTROLLER_PORT:-45780}"
signal_port="${SIGNAL_PORT:-8443}"
player_port="${PLAYER_PORT:-8080}"

# How long to wait for a picture and a registered producer before giving up.
ready_timeout_s="${READY_TIMEOUT_S:-90}"

# The name this session reports to the signalling server and the player.
session_name="${SESSION_NAME:-Thumb Party TV}"

# --- paths ------------------------------------------------------------------
readonly run_dir="/run/thumb-party"
readonly app_dir="/app"
readonly player_src="/usr/share/thumb-party/player"
readonly xdg_dir="$run_dir/xdg"
readonly pulse_socket="$run_dir/pulse/native"
readonly signal_log="$run_dir/signalling.log"
readonly player_log="$run_dir/player.log"
readonly pipe_log="$run_dir/pipeline.log"
readonly app_log="$run_dir/app.log"

# Process ids of everything this session starts, oldest first.
declare -a child_pids=()
# The pipeline's, kept apart so the wait for its socket can see it die.
pipeline_pid=0
# The TV app's, kept apart so its listening port can be found.
game_pid=0

# --- helpers ----------------------------------------------------------------
say() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*"; }

# Starts "$@" in the background with its output in the log named first,
# remembers its pid in last_pid and adds it to the ones stop_all ends.
start_logged() {
  local log="$1"
  shift
  "$@" > "$log" 2>&1 &
  last_pid=$!
  child_pids+=("$last_pid")
}

# The Rust parts of the session write colour codes into their logs even when
# nothing is a terminal, and they land inside the words being looked for.
plain_log() { sed -E 's/\x1b\[[0-9;]*m//g' "$1" 2>/dev/null; }

# Waits for a line of the file named first that matches the pattern second, up
# to the number of seconds third. Prints that line and returns 0, or returns 1
# when the time is up.
wait_for_line() {
  local file="$1" pattern="$2" timeout_s="$3"
  local deadline=$((SECONDS + timeout_s)) line
  while (( SECONDS < deadline )); do
    if [[ -f "$file" ]] && line="$(plain_log "$file" | grep -m1 -E "$pattern")"; then
      printf '%s' "$line"
      return 0
    fi
    sleep 1
  done
  return 1
}

# Which TCP port a process listens on. The TV app asks for 45780 and takes any
# free port when that is busy (packages/connection web_socket_listener.dart), so
# a second session on one host ends up somewhere else and only the app knows
# where. Its own sockets are the ones in /proc/<pid>/fd; /proc/net/tcp lists
# every socket with its port in hex, in state 0A when it listens, so the image
# needs no `ss` or `netstat` for this.
app_listen_port() {
  local pid="$1" inodes entry port
  inodes="$(ls -l "/proc/$pid/fd" 2>/dev/null | sed -n 's/.*socket:\[\([0-9]*\)\].*/ \1 /p' | tr -d '\n')"
  [[ -n "$inodes" ]] || return 1
  for entry in /proc/net/tcp /proc/net/tcp6; do
    [[ -r "$entry" ]] || continue
    port="$(awk -v found="$inodes" '$4 == "0A" && index(found, " " $10 " ") {
      split($2, addr, ":"); printf "%d\n", "0x" addr[2]; exit
    }' "$entry")"
    if [[ -n "$port" ]]; then
      printf '%s\n' "$port"
      return 0
    fi
  done
  return 1
}

# Stops everything this session started, newest first, then waits for it.
stop_all() {
  local pid
  for (( i = ${#child_pids[@]} - 1; i >= 0; i-- )); do
    pid="${child_pids[i]}"
    kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in "${child_pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done
  child_pids=()
}

# --- the session's parts ----------------------------------------------------
# A user PulseAudio with one null sink: the game plays into it because
# /etc/asound.conf sends ALSA there, and the pipeline records its monitor.
start_sound() {
  mkdir -p "$run_dir/pulse"
  start_logged "$run_dir/sound.log" \
    pulseaudio --daemonize=no --disallow-exit --exit-idle-time=-1 -n \
      --load="module-native-protocol-unix auth-anonymous=1 socket=$pulse_socket" \
      --load="module-null-sink sink_name=party channels=2 sink_properties=device.description=Party" \
      --load="module-always-sink"
  local deadline=$((SECONDS + 10))
  while (( SECONDS < deadline )); do
    [[ -S "$pulse_socket" ]] && return 0
    sleep 0.2
  done
  say "error: PulseAudio did not come up, the stream will carry no sound"
  return 1
}

# The signalling server the player and webrtcsink both connect to.
start_signalling() {
  start_logged "$signal_log" gst-webrtc-signalling-server --host 0.0.0.0 --port "$signal_port"
}

# The static web server for the player page.
start_player() {
  mkdir -p "$run_dir/player"
  cp -r "$player_src/." "$run_dir/player/"
  # The page learns the signalling port from this file, so the same page works
  # for every session and for a player that is not on this machine.
  printf 'window.THUMB_PARTY = { signalingPort: %s };\n' "$signal_port" > "$run_dir/player/config.js"
  start_logged "$player_log" python3 -m http.server "$player_port" --bind 0.0.0.0 --directory "$run_dir/player"
}

# The compositor and encoder. `waylanddisplaysrc` needs render-node=software on
# WSL's EGL (no DRM node, no dmabuf: capture probe section 3.2); NVENC gets the
# low-delay settings the design pins, and the bitrate is set through CBR
# because the probe saw the element ignore a bare `bitrate`.
build_pipeline() {
  # One argument per word of the pipeline: gst-launch reads each of these as one
  # token, the way the capture probe ran it.
  local -a cmd=(
    gst-launch-1.0 -e
    waylanddisplaysrc render-node=software '!'
    "video/x-raw,width=$width,height=$height,framerate=$frame_rate/1" '!'
    videoconvert '!'
  )
  if [[ "$encoder" == nv* ]]; then
    # `bitrate` is kbit/s; CBR holds it and ignores `max-bitrate`. No B-frames
    # and no lookahead, so a frame leaves as soon as it is encoded.
    cmd+=("$encoder" "bitrate=$bitrate_kbps" rate-control=cbr
      "gop-size=$gop_frames" b-frames=0 zero-reorder-delay=true preset=p1 tune=ultra-low-latency rc-lookahead=0)
  else
    cmd+=("$encoder" "bitrate=$bitrate_kbps")
  fi
  cmd+=(
    '!' h264parse config-interval=-1
    '!' webrtcsink name=ws "signaller::uri=ws://127.0.0.1:$signal_port"
    video-caps=video/x-h264 audio-caps=audio/x-opus congestion-control=disabled
    pulsesrc device=party.monitor '!' queue '!' audioconvert '!' audioresample '!'
    audio/x-raw,rate=48000,channels=2 '!' opusenc "bitrate=$audio_bitrate_bps" '!' 'ws.'
  )
  "${cmd[@]}" > "$pipe_log" 2>&1 &
  pipeline_pid=$!
  child_pids+=("$pipeline_pid")
}

# `waylanddisplaysrc` picks the socket name itself, so the app reads it back
# from the log rather than guessing. A pipeline that ended without printing it
# fails at once instead of at the end of the wait.
wait_for_wayland_socket() {
  local deadline=$((SECONDS + 20)) line
  while (( SECONDS < deadline )); do
    line="$(plain_log "$pipe_log" | grep -m1 -oE 'socket_name="?[A-Za-z0-9._-]+')"
    if [[ -n "$line" ]]; then
      printf '%s' "${line#*socket_name=}" | tr -d '"'
      return 0
    fi
    kill -0 "$pipeline_pid" 2>/dev/null || return 1
    sleep 0.2
  done
  return 1
}

# The app, as a client of the session's own compositor.
start_game() {
  local socket="$1"
  (
    cd "$app_dir" || exit 1
    WAYLAND_DISPLAY="$socket" GDK_BACKEND=wayland \
    THUMB_PARTY_WINDOW_WIDTH="$width" THUMB_PARTY_WINDOW_HEIGHT="$height" \
      exec ./tvtest
  ) > "$app_log" 2>&1 &
  game_pid=$!
  child_pids+=("$game_pid")
}

# Waits until the app listens and takes its port for the ready line, up to the
# number of seconds given.
wait_for_app_port() {
  local deadline=$((SECONDS + $1)) port
  while (( SECONDS < deadline )); do
    if port="$(app_listen_port "$game_pid")"; then
      controller_port="$port"
      return 0
    fi
    kill -0 "$game_pid" 2>/dev/null || return 1
    sleep 0.5
  done
  return 1
}

# The session is ready when the app listens for phones and the pipeline is
# PLAYING, which is when webrtcsink has registered with the signalling server
# (and so has a picture to send).
wait_ready() {
  local producer
  wait_for_app_port "$ready_timeout_s" || {
    say "error: the app is not listening after ${ready_timeout_s}s, see $app_log"
    say "$(tail -n 20 "$app_log" 2>/dev/null)"
    return 1
  }
  producer="$(wait_for_line "$signal_log" 'registered as a producer' "$ready_timeout_s")" || {
    say "error: the pipeline did not register with the signalling server within ${ready_timeout_s}s, see $pipe_log"
    say "$(tail -n 20 "$pipe_log" 2>/dev/null)"
    return 1
  }
  say "ready: session=$session_name player=http://localhost:$player_port/ controller=localhost:$controller_port ${width}x${height}@${frame_rate} ${bitrate_kbps}kbit/s"
  say "pipeline registered: $producer"
}

main() {
  umask 077
  mkdir -p "$run_dir/pulse" "$xdg_dir"
  chmod 700 "$xdg_dir"
  export XDG_RUNTIME_DIR="$xdg_dir"
  export PULSE_SERVER="unix:$pulse_socket"
  export GST_REGISTRY="$run_dir/registry.bin"
  # `waylanddisplaysrc` and the compositor draw through Mesa's D3D12 layer in
  # WSL2; a real Linux GPU ignores these.
  export GALLIUM_DRIVER="${GALLIUM_DRIVER:-d3d12}"
  export MESA_D3D12_DEFAULT_ADAPTER_NAME="${MESA_D3D12_DEFAULT_ADAPTER_NAME:-NVIDIA}"

  trap 'say "stopping"; stop_all; exit 143' TERM INT

  say "starting a session: ${width}x${height}@${frame_rate} ${bitrate_kbps}kbit/s $encoder, controller port $controller_port"
  start_sound || true
  start_signalling
  start_player
  build_pipeline
  local socket
  socket="$(wait_for_wayland_socket)" || {
    say "error: the virtual screen did not come up, see $pipe_log"
    say "$(tail -n 20 "$pipe_log")"
    stop_all
    exit 1
  }
  say "virtual screen up on $socket"
  start_game "$socket"
  wait_ready || {
    stop_all
    exit 1
  }

  # Anything ending ends the session: the game quitting, the pipeline failing,
  # a stop from outside. `wait -n` returns when the first child exits.
  local status=0
  wait -n || status=$?
  say "a part of the session ended (status $status), stopping the rest"
  stop_all
  exit "$status"
}

main "$@"
