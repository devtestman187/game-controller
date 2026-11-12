#!/bin/bash
# The encoder micro-bench (M15 k1-4), run inside the distro: how long a 1080p60
# frame sits inside NVENC when nothing else in the session can be blamed for the
# wait. It is the session's own encoder settings, one change at a time, on a
# `videotestsrc` (no game, no viewer, no webrtcsink: `fakesink sync=false`, so
# the encoder is never held back by a consumer that cannot keep up):
#
#   videotestsrc is-live=true pattern=ball ! video/x-raw,width=1920,height=1080,
#     framerate=60/1 ! videoconvert [ ! <before> ] ! <encoder and its
#     properties> ! h264parse ! fakesink sync=false
#
# under the session's tracer (`GST_TRACERS=latency(flags=pipeline+element)`,
# streaming/entrypoint.sh `build_pipeline`), and for each variant prints the
# encoder element's mean and p95 element latency, the frames it delivered per
# second and the gst-launch process's CPU. The element latency is the time a
# buffer spent inside the element between its sink pad and its src pad, which is
# the number the session reports as the encode stage (packages/metrics,
# `PipelineWindow.stageOf`): a wait before the encoder shows up in the element
# before it, a wait for NVENC or for the element's own output thread inside it.
#
#   bash streaming/encoder-bench.sh [--seconds S] [--only a,b] [--list]
#     [--props "PROPS"] [--out DIR]
#
# `--props` takes the whole property string from the command line instead of
# the session's (`build_pipeline`); `--list` prints every variant with the
# properties it would run and runs nothing.
#
# Run it on the distro's own GStreamer (the same Ubuntu 24.04 nvcodec plugin the
# session image has): `tools/wsl-sync.sh tp-stream`, then in the distro
# `bash /work/<job>/streaming/encoder-bench.sh`. The real source
# (`waylanddisplaysrc`) needs the app drawing into it, which is the session, so
# this bench has no mode for it: k1-4's session runs confirm it.
set -u

readonly width=1920
readonly height=1080
# The source's rate: the session's 60, unless a pacing probe asks for another
# (`--fps`): a run at half the rate shows whether the encoder's number is its
# own work or the interval it waits for the next frame.
frame_rate=60
# Seconds the pipeline runs before its CPU is read: the plugins load and NVENC
# opens the card in that time, and that is not the encode's cost.
readonly warmup_s=2
# A variant's elements, in the order the session's pipeline has them
# (`build_pipeline`: the caps filter, the converter, the encoder, the parser).
readonly session_encoder="nvautogpuh264enc"
# What the encoder gets in the session at the default ceiling: (10000 - 96) /
# (1 + 110/100), the bitrate left after the sound and FEC (entrypoint.sh).
readonly session_bitrate_kbps=4716
# The session's encoder properties, copied word for word from `build_pipeline`:
# CBR, a keyframe a second, no B-frames and no lookahead, so a frame leaves as
# soon as it is encoded.
session_props="bitrate=$session_bitrate_kbps rate-control=cbr gop-size=$frame_rate b-frames=0 \
zero-reorder-delay=true preset=p1 tune=ultra-low-latency rc-lookahead=0"

seconds=20
out=""
only=""
list_only="no"
after=""
log_file=""

say() { printf '%s\n' "$*"; }
fail() { printf 'encoder-bench: %s\n' "$*" >&2; exit 1; }
refuse() { printf 'encoder-bench: %s\n' "$*" >&2; exit 2; }

usage() {
  cat <<'EOF'
The encoder micro-bench (M15 k1-4), inside the distro.

  --seconds S        how long each variant encodes for (default 20)
  --only a,b         run only the named variants (see --list); default all
  --list             print the variants and their properties, run nothing
  --props "PROPS"    the encoder's properties for the "session" variant and for
                     every variant that starts from it (default: build_pipeline)
  --out DIR          where each variant's tracer log goes (default /work/encoder-bench)
  --fps N            the source's rate (default 60), for a pacing probe: at half
                     the rate a number that doubles is waiting, not encoding (the
                     session's gop-size stays 60, two keyframes a second)
  --after "ELEMENTS" elements between the encoder and the parser, for a probe of
                     what the tracer counts: `--after "identity sleep-time=20000"`
                     makes every pushed frame wait 20 ms downstream
  --log FILE         print the table's row for an existing tracer log (a
                     session's pipeline.log), and run nothing
  --help             this text
EOF
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --seconds) seconds="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --only) only="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --props) session_props="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --out) out="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --fps) frame_rate="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --after) after="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --log) log_file="${2:-}"; shift 2 || { usage; exit 2; } ;;
      --list) list_only="yes"; shift ;;
      --help | -h) usage; exit 0 ;;
      *) refuse "unknown option \"$1\"" ;;
    esac
  done
  [[ "$seconds" =~ ^[0-9]+$ ]] && (( seconds > 0 )) || refuse "the seconds are a whole number above zero, got \"$seconds\""
  [[ "$frame_rate" =~ ^[0-9]+$ ]] && (( frame_rate > 0 )) || refuse "the frame rate is a whole number above zero, got \"$frame_rate\""
}

# The session's properties with [overrides] applied, one `key=value` word each:
# a key the session sets is replaced where it stands, and a key it does not set
# is added at the end. The variant table says what each change is.
session_props_with() {
  local -a words result
  local override key word
  read -r -a words <<< "$session_props"
  for override in $1; do
    key="${override%%=*}"
    result=()
    for word in "${words[@]}"; do
      [[ "${word%%=*}" == "$key" ]] || result+=("$word")
    done
    result+=("$override")
    words=("${result[@]}")
  done
  printf '%s\n' "${words[*]}"
}

# Every variant this bench runs, one per line: its name, the encoder element,
# what stands between the converter and the encoder ("-" for nothing) and the
# encoder's whole property string. The first line is the session's settings, so
# every other line is read against what the session does; the changes are ones
# M15 t1 did not try on the element itself (its runs had a viewer in them and
# could not see 30 ms of it).
variants() {
  printf '%s|%s|%s|%s\n' session "$session_encoder" - "$session_props"
  # A one-buffer leaky queue in front of the encoder: a frame that arrives while
  # the encoder is busy is dropped rather than queued, so this line says how
  # much of the encoder's number is a frame waiting behind an older one.
  printf '%s|%s|%s|%s\n' queue1 "$session_encoder" "queue max-size-buffers=1 leaky=downstream" "$session_props"
  printf '%s|%s|%s|%s\n' preset-p4 "$session_encoder" - "$(session_props_with 'preset=p4')"
  printf '%s|%s|%s|%s\n' tune-low "$session_encoder" - "$(session_props_with 'tune=low-latency')"
  printf '%s|%s|%s|%s\n' tune-hq "$session_encoder" - "$(session_props_with 'tune=high-quality')"
  printf '%s|%s|%s|%s\n' reorder "$session_encoder" - "$(session_props_with 'zero-reorder-delay=false')"
  printf '%s|%s|%s|%s\n' rc-vbr "$session_encoder" - "$(session_props_with 'rate-control=vbr')"
  printf '%s|%s|%s|%s\n' rc-cbrld "$session_encoder" - "$(session_props_with 'rate-control=cbr-ld-hq')"
  printf '%s|%s|%s|%s\n' vbv167 "$session_encoder" - \
    "$(session_props_with 'vbv-buffer-size=167 strict-gop=true')"
  printf '%s|%s|%s|%s\n' cuda "nvcudah264enc" - "$session_props"
  printf '%s|%s|%s|%s\n' nvh264 "nvh264enc" - \
    "bitrate=$session_bitrate_kbps rate-control=cbr gop-size=$frame_rate zerolatency=true"
}

# Whether [name] is one of the table's.
known_variant() {
  local line
  while IFS='|' read -r line _; do
    [[ "$line" == "$1" ]] && return 0
  done < <(variants)
  return 1
}

# Whether this run asked for [name]: no `--only` means every variant.
wanted() {
  local name
  [[ -z "$only" ]] && return 0
  for name in ${only//,/ }; do
    [[ "$name" == "$1" ]] && return 0
  done
  return 1
}

# The CPU the process [pid] has used so far, in 1/100 s: the fields after the
# command name (which may contain spaces) are utime and stime.
proc_cpu_ticks() {
  awk '{ sub(/^.*\) /, ""); print $12 + $13 }' "/proc/$1/stat" 2> /dev/null
}

# The pipeline's words for one variant: [1] the encoder, [2] the elements
# before it, [3] its properties, [4] the elements after it. One word per
# element and per `!`, the way `build_pipeline` gives them to gst-launch; they
# are left in the script's `cmd`, which run_variant starts.
pipeline_cmd() {
  local -a before=() props=() tail=()
  local word
  read -r -a props <<< "$3"
  [[ "$2" != "-" ]] && read -r -a before <<< "$2"
  [[ -n "$4" ]] && read -r -a tail <<< "$4"
  cmd=(gst-launch-1.0 -e
    videotestsrc is-live=true "pattern=ball" '!'
    "video/x-raw,width=$width,height=$height,framerate=$frame_rate/1" '!'
    videoconvert '!')
  for word in "${before[@]}"; do cmd+=("$word"); done
  [[ ${#before[@]} -gt 0 ]] && cmd+=('!')
  cmd+=("$1" "${props[@]}" '!')
  for word in "${tail[@]}"; do cmd+=("$word"); done
  [[ ${#tail[@]} -gt 0 ]] && cmd+=('!')
  cmd+=(h264parse '!' fakesink sync=false)
}

# One variant: [1] its name, [2] the encoder, [3] the elements before it, [4]
# its properties; `--after` adds elements after the encoder to all of them.
# Starts the pipeline, lets it warm up, reads the process's CPU before and after
# [seconds], stops it with INT (so the tracer's records end cleanly) and prints
# the rows below.
run_variant() {
  local name="$1" log="$out/$1.log" pid ticks0 ticks1 start end cpu
  pipeline_cmd "$2" "$3" "$4" "$after"
  GST_TRACERS="latency(flags=pipeline+element)" GST_DEBUG="GST_TRACER:7" GST_DEBUG_NO_COLOR=1 \
    "${cmd[@]}" > "$log" 2>&1 &
  pid=$!
  sleep "$warmup_s"
  ticks0="$(proc_cpu_ticks "$pid")"
  if [[ -z "$ticks0" ]]; then
    say "$(status_row "$name" failed "$(tail -n 1 "$log")")"
    return
  fi
  start="$(date +%s%N)"
  sleep "$seconds"
  ticks1="$(proc_cpu_ticks "$pid")"
  end="$(date +%s%N)"
  kill -INT "$pid" 2> /dev/null
  wait "$pid" 2> /dev/null
  cpu=$(( (ticks1 - ticks0) * 100 * 1000 / ((end - start) / 1000000) ))
  say "$(stats_row "$name" "$2" "$log" "$cpu")"
}

# One row of the table for a failed variant: the name and why, nothing counted.
status_row() {
  printf '%-11s %9s  %s\n' "$1" "$2" "$3"
}

# One row of the table for the tracer log [3] of variant [1] whose encoder is
# [2]; [4] is the process's CPU in % x 100 over the measured window, or empty
# for a log another process wrote. The encoder's records give its mean and p95
# element latency (whole ms, a 1 ms histogram above 200 ms) and the frames per
# second it delivered, timed by the tracer's own stamps so the start-up is left
# out; the other elements' means say where a wait outside the encoder went.
stats_row() {
  awk -v name="$1" -v encoder="$2" -v cpu="$4" '
    function value_after(line, marker,   at, rest) {
      at = index(line, marker)
      if (at == 0) return ""
      rest = substr(line, at + length(marker))
      return rest
    }
    function number_after(line, marker,   rest, end) {
      rest = value_after(line, marker)
      if (rest == "" || rest !~ /^[0-9]+/) return ""
      end = match(rest, /[^0-9]/)
      return end == 0 ? rest : substr(rest, 1, end - 1)
    }
    /element-latency, / {
      element = value_after($0, "element=(string)")
      sub(/,.*/, "", element)
      ns = number_after($0, "time=(guint64)") + 0
      ts = number_after($0, "ts=(guint64)") + 0
      # The tracer prints its own record format at start-up with an element
      # named "%s": that line is a template, not a frame.
      if (element == "" || element == "%s" || ns == 0) next
      total[element] += ns; count[element]++
      if (index(element, encoder) != 1) next
      encoder_element = element
      frames++
      if (frames == 1) first = ts
      last = ts
      hist[int(ns / 1000000)]++
    }
    END {
      if (frames == 0) { printf "%-11s %9s  no frames encoded\n", name, "failed"; exit }
      ms = total[encoder_element] / count[encoder_element] / 1000000
      want = frames * 95 / 100; seen = 0; p95 = 0
      for (bucket = 0; bucket <= 200; bucket++) {
        seen += hist[bucket]
        if (seen >= want) { p95 = bucket; break }
      }
      fps = (last > first) ? (frames - 1) * 1e9 / (last - first) : 0
      others = ""
      for (element in total) {
        if (index(element, encoder) == 1) continue
        others = others sprintf("%s %.1f  ", element, total[element] / count[element] / 1000000)
      }
      printf "%-11s %9.1f %9.1f %9.1f %7s  %s\n", name, ms, p95, fps,
        cpu < 0 ? "-" : sprintf("%.1f", cpu / 100), others
    }
  ' "$3"
}

main() {
  parse_args "$@"
  local name encoder before props
  if [[ -n "$log_file" ]]; then
    [[ -f "$log_file" ]] || fail "no log at $log_file"
    printf '%-11s %9s %9s %9s %7s  %s\n' variant 'enc mean' 'enc p95' 'enc fps' 'cpu %' 'other elements (mean ms)'
    stats_row "$(basename "$log_file" .log)" "$session_encoder" "$log_file" -1
    return
  fi
  if [[ "$list_only" == "yes" ]]; then
    while IFS='|' read -r name encoder before props; do
      printf '%-11s %-16s %-40s %s\n' "$name" "$encoder" "$before" "$props"
    done < <(variants)
    return
  fi
  [[ -n "$only" ]] && for name in ${only//,/ }; do
    known_variant "$name" || refuse "no variant called \"$name\" (--list has them)"
  done
  if [[ -z "$out" ]]; then out="/work/encoder-bench"; fi
  mkdir -p "$out" || fail "cannot make $out"
  printf '%-11s %9s %9s %9s %7s  %s\n' variant 'enc mean' 'enc p95' 'enc fps' 'cpu %' 'other elements (mean ms)'
  while IFS='|' read -r name encoder before props; do
    wanted "$name" || continue
    run_variant "$name" "$encoder" "$before" "$props"
  done < <(variants)
}

main "$@"
