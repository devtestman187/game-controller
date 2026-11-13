#!/bin/bash
# The entrypoint's pipeline command with SESSION_TAP off and on (M15 opt2).
#
# The entrypoint ends in main, which starts a whole session, so it carries a
# guarded --print-pipeline mode that prints the command and its words as a start
# would and starts nothing. Run from anywhere:
#   streaming/tap/entrypoint_pipeline_test.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
entrypoint="$here/../entrypoint.sh"
runner="/usr/local/bin/tap/tap_runner.py"
failures=0

fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }

# The pipeline command of one run, with the named settings and nothing else in
# the environment, so the session's own defaults decide the rest.
words() { env -i PATH="$PATH" "$@" bash "$entrypoint" --print-pipeline; }

# The command line the session ran before the tap existed, captured from the
# entrypoint on Nov 13, 2026 (gst-launch-1.0 -e, one word per line; the video
# gets (10000 - 96) * 100 / 210 = 4716 kbit/s because FEC adds 110 %).
expected_off() {
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

off="$(words SESSION_TAP=off)"
if [[ "$off" != "$(expected_off)" ]]; then
  fail "SESSION_TAP=off no longer prints the command line the session ran before the tap"
  diff <(printf '%s\n' "$off") <(expected_off) | head -20
fi

mapfile -t on_words < <(words SESSION_TAP=on)
# The runner gets its port first: the automation port (8787 by default) plus
# one, the loopback port PROTOCOL.md gives the tap server.
if [[ "${on_words[0]} ${on_words[1]} ${on_words[2]} ${on_words[3]} ${on_words[4]}" \
  != "python3 $runner --port 8788 --" ]]; then
  fail "SESSION_TAP=on does not start tap_runner.py on the automation port plus one"
fi
on_pipeline=("${on_words[@]:5}")

for word in tee name=t 't.' queue leaky=downstream max-size-buffers=2 max-size-time=0 \
  appsink name=tap drop=true max-buffers=2 sync=false emit-signals=true async=false; do
  has_word "$(printf '%s\n' "${on_pipeline[@]}")" "$word" ||
    fail "SESSION_TAP=on is missing the word '$word'"
done
parsers=0
for word in "${on_pipeline[@]}"; do [[ "$word" == h264parse ]] && parsers=$((parsers + 1)); done
if (( parsers != 2 )); then fail "SESSION_TAP=on has $parsers h264parse, not one per branch"; fi

# The tee comes right after the encoder, so the words before it are the old
# command's own: the encoder's settings did not move.
mapfile -t off_words < <(expected_off)
tee_at=-1
for index in "${!on_pipeline[@]}"; do
  if [[ "${on_pipeline[index]}" == tee ]]; then tee_at=$index; break; fi
done
if (( tee_at < 1 )); then
  fail "SESSION_TAP=on has no tee"
else
  [[ "${on_pipeline[tee_at - 1]}" == '!' ]] || fail "the tee does not follow the encoder's link"
  for (( i = 0; i < tee_at - 1; i++ )); do
    if [[ "${on_pipeline[i]}" != "${off_words[i + 2]}" ]]; then
      fail "word $((i + 1)) changed with the tap on: '${on_pipeline[i]}'"
      break
    fi
  done
fi

# The sound's words are the ones they were in all three SESSION_AUDIO modes.
on_sound="$(printf '%s\n' "${on_pipeline[@]}" | sed -n '/^pulsesrc$/,$p')"
off_sound="$(printf '%s\n' "${off_words[@]:2}" | sed -n '/^pulsesrc$/,$p')"
if [[ "$on_sound" != "$off_sound" ]]; then fail "the joined sound's words changed with the tap on"; fi
separate="$(words SESSION_TAP=on SESSION_AUDIO=separate)"
has_word "$separate" name=ws-audio || fail "SESSION_AUDIO=separate lost its own sink with the tap on"
has_word "$separate" 'meta=TP-Picture,name=TP-Picture' ||
  fail "SESSION_AUDIO=separate lost the picture's producer meta with the tap on"
quiet="$(words SESSION_TAP=on SESSION_AUDIO=off)"
if has_word "$quiet" pulsesrc; then fail "SESSION_AUDIO=off still has a sound path with the tap on"; fi

# A session that gives the tap its own port keeps it.
port="$(words SESSION_TAP=on TAP_PORT=9101)"
has_word "$port" 9101 || fail "TAP_PORT is not passed to the runner"

if (( failures > 0 )); then
  printf '%d check(s) failed\n' "$failures"
  exit 1
fi
printf 'ok: the entrypoint pipeline, tap off and on\n'
