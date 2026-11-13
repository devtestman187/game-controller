#!/bin/bash
# The entrypoint's audio modes: what each SESSION_AUDIO value puts in the
# picture pipeline and in the sound's own pipeline (M15 opt2-5).
#
# The entrypoint ends in main, which starts a whole session, so it carries two
# dry-run modes, --print-pipeline and --print-sound-pipeline, that print the
# command and its words as a start would and start nothing. Run from anywhere:
#   streaming/tap/entrypoint_audio_test.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
entrypoint="$here/../entrypoint.sh"
failures=0

fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }

# One dry run's output, with the named settings and nothing else in the
# environment, so the session's own defaults decide the rest.
dry() {
  local mode="$1"
  shift
  env -i PATH="$PATH" "$@" bash "$entrypoint" "$mode"
}

# The command line the joined sound and picture ran before the sound had its
# own process, captured from the entrypoint on Nov 13, 2026 (gst-launch-1.0 -e,
# one word per line; the video gets (10000 - 96) * 100 / 210 = 4716 kbit/s
# because FEC adds 110 %).
expected_joined() {
  cat <<'WORDS'
gst-launch-1.0
-e
waylanddisplaysrc
render-node=software
!
video/x-raw,width=1920,height=1080,framerate=60/1
!
videoconvert
!
nvautogpuh264enc
bitrate=4716
rate-control=cbr
gop-size=60
b-frames=0
zero-reorder-delay=true
preset=p1
tune=ultra-low-latency
rc-lookahead=0
!
h264parse
config-interval=-1
!
webrtcsink
name=ws
signaller::uri=ws://127.0.0.1:8443
congestion-control=disabled
max-bitrate=4716000
start-bitrate=4716000
do-fec=true
do-retransmission=true
pulsesrc
device=party.monitor
!
queue
!
audioconvert
!
audioresample
!
audio/x-raw,rate=48000,channels=2
!
opusenc
bitrate=96000
!
ws.
WORDS
}

# One of a run's words, as a whole line.
has_word() { printf '%s\n' "$1" | grep -qxF -- "$2"; }

# A dry run's warnings (they carry a time and the word "warning:") without its
# command, so the command line the session would print is read on its own.
warnings_of() { printf '%s\n' "$1" | grep ' warning: ' || true; }
command_of() { printf '%s\n' "$1" | grep -v ' warning: ' || true; }

# The picture pipeline carries no sound path in [separate]: no source, no
# encoder, no second sink and no audio caps.
no_sound_in_picture() {
  local words="$1" word
  for word in pulsesrc opusenc name=ws-audio audio/x-raw,rate=48000,channels=2 'ws.'; do
    if has_word "$words" "$word"; then fail "$2's picture pipeline still has the word '$word'"; fi
  done
  if [[ "$(printf '%s\n' "$words" | grep -cxF webrtcsink)" != 1 ]]; then
    fail "$2's picture pipeline has more than one webrtcsink"
  fi
}

# The joined sound's own words are the ones it always had, byte for byte.
joined="$(dry --print-pipeline SESSION_AUDIO=joined)"
if [[ "$joined" != "$(expected_joined)" ]]; then
  fail "SESSION_AUDIO=joined no longer prints the command line it always ran"
  diff <(printf '%s\n' "$joined") <(expected_joined) | head -20
fi
if [[ "$(dry --print-pipeline)" != "$joined" ]]; then fail "joined is no longer the default"; fi
if [[ -n "$(dry --print-sound-pipeline SESSION_AUDIO=joined)" ]]; then
  fail "joined has a sound pipeline of its own"
fi

# `separate`: the picture pipeline is the picture's alone, and the sound gets a
# command of its own with its own sink and its own producer meta.
separate="$(dry --print-pipeline SESSION_AUDIO=separate)"
no_sound_in_picture "$separate" "SESSION_AUDIO=separate"
has_word "$separate" 'meta=TP-Picture,name=TP-Picture' ||
  fail "SESSION_AUDIO=separate's picture lost its producer meta"
sound="$(dry --print-sound-pipeline SESSION_AUDIO=separate)"
mapfile -t sound_words < <(printf '%s\n' "$sound")
if [[ "${sound_words[0]:-} ${sound_words[1]:-}" != "gst-launch-1.0 -e" ]]; then
  fail "the sound's own pipeline is not a gst-launch with -e"
fi
for word in pulsesrc device=party.monitor queue audioconvert audioresample \
  audio/x-raw,rate=48000,channels=2 opusenc bitrate=96000 webrtcsink \
  name=ws-audio signaller::uri=ws://127.0.0.1:8443 meta=TP-Sound,name=TP-Sound; do
  has_word "$sound" "$word" || fail "the sound's own pipeline is missing the word '$word'"
done

# `off`: no sound anywhere.
quiet="$(dry --print-pipeline SESSION_AUDIO=off)"
if has_word "$quiet" pulsesrc; then fail "SESSION_AUDIO=off still has a sound path"; fi
if [[ -n "$(dry --print-sound-pipeline SESSION_AUDIO=off)" ]]; then
  fail "SESSION_AUDIO=off has a sound pipeline of its own"
fi

# A value the session does not know warns and runs joined, in both dry runs.
invalid="$(dry --print-pipeline SESSION_AUDIO=joined-and-separate)"
case "$(warnings_of "$invalid")" in
  *"warning: SESSION_AUDIO=joined-and-separate is not joined, off or separate; running joined"*) ;;
  *) fail "an unknown SESSION_AUDIO does not warn about falling back to joined" ;;
esac
if [[ "$(command_of "$invalid")" != "$(expected_joined)" ]]; then
  fail "an unknown SESSION_AUDIO does not run the joined pipeline"
fi
if [[ -n "$(command_of "$(dry --print-sound-pipeline SESSION_AUDIO=joined-and-separate)")" ]]; then
  fail "an unknown SESSION_AUDIO started a sound pipeline of its own"
fi

# With the tap on the picture pipeline is the tap runner's, and the sound's own
# command does not change with it.
tapped="$(dry --print-pipeline SESSION_TAP=on SESSION_AUDIO=separate)"
no_sound_in_picture "$tapped" "SESSION_TAP=on SESSION_AUDIO=separate"
if [[ "$tapped" != python3*"--"* ]]; then fail "SESSION_TAP=on no longer runs tap_runner.py"; fi
if [[ "$(dry --print-sound-pipeline SESSION_TAP=on SESSION_AUDIO=separate)" != "$sound" ]]; then
  fail "the tap changes the sound's own pipeline"
fi

if (( failures > 0 )); then
  printf '%d check(s) failed\n' "$failures"
  exit 1
fi
printf 'ok: the entrypoint audio modes\n'
