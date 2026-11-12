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
# This is the ceiling the video keeps: webrtcsink runs its own bitrate control
# and sets the encoder's bitrate itself, so the number goes to the element as
# well as to the encoder. What a viewer receives is this plus FEC and the sound,
# and FEC is the larger part of it: a 1080p Arena round carried 11.6 Mbit/s at
# 10 Mbit/s set (M15 t1) and 7.2 Mbit/s with `SESSION_FEC=false`, because the
# encoder sends what the picture needs up to the ceiling, not the ceiling.
bitrate_kbps="${SESSION_BITRATE_KBPS:-10000}"
bitrate_bps=$((bitrate_kbps * 1000))
# A keyframe a second, so a player that joins or reconnects sees a picture at
# once and a lost packet costs at most one second. -1 is no periodic keyframe at
# all, only the ones a receiver asks for (PLI/FIR, which webrtcsink forwards).
# The default stays one a second: M15 t1 measured that removing them made the
# receiver's buffer worse rather than better (262 ms against 127-170, see
# streaming/README.md).
gop_frames="${SESSION_GOP_FRAMES:-${frame_rate}}"
# The encoder's VBV/HRD buffer in kbits, which bounds how far one frame may run
# over the bitrate (0 = NVENC's own default, a second's worth). One frame's
# worth, bitrate / frame rate, made every frame cost about the same and looked
# like the best of M15 t1's tuning: two runs had stream_total 144-145 ms against
# the baseline's 161-205, press-to-screen 213-223 ms against 230-266, and the
# receiver's jitter buffer 110 ms against 127-170. Three more runs with it on by
# default came out at 145-182 and 220-250, so the gain is inside this PC's
# run-to-run noise (44 ms) and it stays a switch, off by default.
vbv_kbits="${SESSION_VBV_KBITS:-0}"
# Forward error correction and retransmission, both on: a home Wi-Fi drops the
# odd packet, and a retransmitted frame costs less than a concealed one. M15 t1
# measured no lower delay with them off, and turning FEC off only saves the
# bandwidth it adds (7.2 Mbit/s without it against 11.6 with it, the same Arena
# round), so both stay on and the pair is a switch for a network that needs the
# bandwidth instead.
do_fec="${SESSION_FEC:-true}"
do_retransmission="${SESSION_RETRANSMISSION:-true}"
# Whether the player page plays the picture and the sound on two media elements
# instead of one, so Chrome's audio/video sync does not hold the picture back.
# Off: M15 t1 measured it *worse* (42 delivered fps against 53, press 246 ms
# against 230, see streaming/README.md), so one element stays.
split_tracks="${SESSION_SPLIT_TRACKS:-false}"
# nvh264enc is broken on this driver (M15 wsl2 probe); the auto and cuda
# elements both work. The image carries gst-plugins-rs and NVENC only.
encoder="${SESSION_ENCODER:-nvautogpuh264enc}"
# Opus at 96 kbit/s carries the game's music and effects with room to spare.
audio_bitrate_bps="${SESSION_AUDIO_BITRATE_BPS:-96000}"

# The ports inside the session. tools/stream.sh gives each session its own.
# The controller port is pinned (THUMBPARTY_PORT, job a2), so the app listens
# on exactly this one and fails loudly instead of moving to a free port.
controller_port="${CONTROLLER_PORT:-45780}"
signal_port="${SIGNAL_PORT:-8443}"
player_port="${PLAYER_PORT:-8080}"
# The host's automation interface (M15 a2), which the sampler and the player's
# relay reach inside the container; tools/stream.sh gives each session its own
# so two sessions don't fight for one port.
automation_port="${AUTOMATION_PORT:-8787}"

# The token every automation call carries (M15 a2 requires one when the bind
# isn't loopback). A session makes its own unless the launch gives it one.
automation_token="${AUTOMATION_TOKEN:-}"

# How many sessions this machine runs at once, for the resource table's
# grouping (M15 c2). tools/stream.sh bench sets it; a session started by hand
# is 1, and two started by hand are two sessions that each say 1.
sessions_at_once="${SESSIONS_AT_ONCE:-1}"

# How often the sampler reads the container's counters (M15 c2), in seconds.
sampler_interval_s="${SAMPLER_INTERVAL_S:-3}"

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

# Whether a TCP port is listening in this container. The app is pinned to its
# controller port (THUMBPARTY_PORT), so waiting for the pinned port is enough;
# /proc/net/tcp lists every socket with its port in hex, in state 0A when it
# listens, so the image needs no `ss` or `netstat` for this.
port_listening() {
  local port="$1" entry
  local hex
  hex="$(printf '%04X' "$port")"
  for entry in /proc/net/tcp /proc/net/tcp6; do
    [[ -r "$entry" ]] || continue
    if awk -v want=":$hex" '$4 == "0A" && index($2, want) == length($2) - length(want) + 1 { found = 1 }
      END { exit !found }' "$entry"; then
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

# The player page and its relay: one Python server that serves the page and
# passes its measurements to the app with the session's token (M15 c2).
start_player() {
  mkdir -p "$run_dir/player"
  cp -r "$player_src/." "$run_dir/player/"
  # The page learns the signalling port and the two player settings from this
  # file, so the same page works for every session and for a player that is not
  # on this machine. `splitTracks` plays the picture and the sound on separate
  # media elements (M15 t1 experiment 1): off unless SESSION_SPLIT_TRACKS says
  # on, because it measured no gain on this pipeline (streaming/README.md).
  printf 'window.THUMB_PARTY = { signalingPort: %s, splitTracks: %s };\n' \
    "$signal_port" "$split_tracks" > "$run_dir/player/config.js"
  start_logged "$player_log" \
    python3 "$run_dir/player/serve.py" --port "$player_port" --directory "$run_dir/player" \
      --automation-port "$automation_port" --token "$automation_token" --state "$run_dir"
}

# The session's own token, made once and readable by this container only, so a
# script (tools/stream.sh bench) can drive the same session the player does.
make_token() {
  if [[ -n "$automation_token" ]]; then
    return 0
  fi
  automation_token="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
}

# The sampler: the container's CPU, memory, GPU and encoder numbers, and the
# pipeline's stages, sent to the host every few seconds (M15 c2).
start_sampler() {
  start_logged "$run_dir/sampler.log" \
    stream-sampler --automation-url "http://127.0.0.1:$automation_port" --token "$automation_token" \
      --pipeline-log "$pipe_log" --out "$run_dir/pipeline.json" \
      --interval-s "$sampler_interval_s" --sessions "$sessions_at_once" --encoder "$encoder"
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
    if (( vbv_kbits > 0 )); then
      cmd+=("vbv-buffer-size=$vbv_kbits" strict-gop=true)
    fi
  else
    cmd+=("$encoder" "bitrate=$bitrate_kbps")
  fi
  cmd+=(
    '!' h264parse config-interval=-1
    '!' webrtcsink name=ws "signaller::uri=ws://127.0.0.1:$signal_port"
    video-caps=video/x-h264 audio-caps=audio/x-opus congestion-control=disabled
    "max-bitrate=$bitrate_bps" "start-bitrate=$bitrate_bps"
    "do-fec=$do_fec" "do-retransmission=$do_retransmission"
    pulsesrc device=party.monitor '!' queue '!' audioconvert '!' audioresample '!'
    audio/x-raw,rate=48000,channels=2 '!' opusenc "bitrate=$audio_bitrate_bps" '!' 'ws.'
  )
  # The latency tracer writes one record per element per frame into the
  # pipeline's log, which the sampler reads (M15 c2): how long a buffer spent
  # in the compositor, the converter and the encoder, and in webrtcsink.
  GST_TRACERS="latency(flags=pipeline+element)" GST_DEBUG="GST_TRACER:7" GST_DEBUG_NO_COLOR=1 \
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

# The app, as a client of the session's own compositor and with the automation
# interface on (M15 a2): the sampler and the player's relay reach it on the
# session's own automation port, the controller port is pinned, and the
# first-run stats question is answered so a session with nobody at the screen
# has a clear home screen.
start_game() {
  local socket="$1"
  (
    cd "$app_dir" || exit 1
    WAYLAND_DISPLAY="$socket" GDK_BACKEND=wayland \
    THUMB_PARTY_WINDOW_WIDTH="$width" THUMB_PARTY_WINDOW_HEIGHT="$height" \
    THUMBPARTY_AUTOMATION=1 \
    THUMBPARTY_AUTOMATION_BIND=0.0.0.0 \
    THUMBPARTY_AUTOMATION_PORT="$automation_port" \
    THUMBPARTY_AUTOMATION_TOKEN="$automation_token" \
    THUMBPARTY_PORT="$controller_port" \
    THUMBPARTY_STATS_CONSENT=no \
      exec ./tvtest
  ) > "$app_log" 2>&1 &
  game_pid=$!
  child_pids+=("$game_pid")
}

# Waits until the app listens on its pinned controller port, up to the number
# of seconds given.
wait_for_app_port() {
  local deadline=$((SECONDS + $1))
  while (( SECONDS < deadline )); do
    if port_listening "$controller_port"; then
      return 0
    fi
    kill -0 "$game_pid" 2>/dev/null || return 1
    sleep 0.5
  done
  return 1
}

# The automation interface's status, as the app answers it, or nothing.
automation_status() {
  curl -s --max-time 2 -H "x-automation-token: $automation_token" \
    "http://127.0.0.1:$automation_port/automation/v1/status" 2>/dev/null
}

# Waits until the app's automation interface says the host is ready to be
# played on, which is what a viewer's session starts from.
wait_for_host_ready() {
  local deadline=$((SECONDS + $1)) status
  while (( SECONDS < deadline )); do
    status="$(automation_status)"
    if [[ "$status" == *'"ready":true'* ]]; then
      return 0
    fi
    kill -0 "$game_pid" 2>/dev/null || return 1
    sleep 0.5
  done
  return 1
}

# The session is ready when the app listens for phones, its automation
# interface answers ready, and the pipeline is PLAYING, which is when
# webrtcsink has registered with the signalling server (and so has a picture
# to send).
wait_ready() {
  local producer
  wait_for_app_port "$ready_timeout_s" || {
    say "error: the app is not listening on $controller_port after ${ready_timeout_s}s, see $app_log"
    say "$(tail -n 20 "$app_log" 2>/dev/null)"
    return 1
  }
  wait_for_host_ready "$ready_timeout_s" || {
    say "error: the app's automation interface did not answer ready after ${ready_timeout_s}s, see $app_log"
    say "$(tail -n 20 "$app_log" 2>/dev/null)"
    return 1
  }
  producer="$(wait_for_line "$signal_log" 'registered as a producer' "$ready_timeout_s")" || {
    say "error: the pipeline did not register with the signalling server within ${ready_timeout_s}s, see $pipe_log"
    say "$(tail -n 20 "$pipe_log" 2>/dev/null)"
    return 1
  }
  say "ready: session=$session_name player=http://localhost:$player_port/ controller=localhost:$controller_port automation=127.0.0.1:$automation_port ${width}x${height}@${frame_rate} ${bitrate_kbps}kbit/s ${gop_frames}f gop"
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
  make_token
  # The token file is how a script outside this container drives the session
  # (tools/stream.sh bench reads it with docker exec); umask 077 keeps it 0600.
  printf '%s\n' "$automation_token" > "$run_dir/automation.token"
  start_sound || true
  start_signalling
  start_player
  build_pipeline
  start_sampler
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
