#!/usr/bin/env bash
# Renders the round music (M13 step 15) and encodes it the way README.md says:
# the WAV masters land in tools/audio/final/round-wav/, beside the script and
# out of the repository, and the three .ogg files land in assets/audio/ next to
# the other cues.
#
#   tools/audio/render-round-music.sh
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
masters="$here/final/round-wav"

cd "$root"
dart run tools/audio/round_music.dart

for name in round round_hurry round_final; do
  ffmpeg -y -i "$masters/$name.wav" -map_metadata -1 -c:a libvorbis -q:a 7 -ac 1 -ar 44100 "$root/assets/audio/$name.ogg"
done

# Each file has to match its master to the millisecond.
for name in round round_hurry round_final; do
  printf '%-12s %s s\n' "$name" "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$root/assets/audio/$name.ogg")"
done
