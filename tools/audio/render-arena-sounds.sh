#!/usr/bin/env bash
# Renders the Arena's sounds and music (M14) and encodes them the way README.md
# says: the WAV masters land in tools/audio/final/arena-wav/, beside the scripts
# and out of the repository, and the ten .ogg files land in assets/audio/ next
# to the other cues.
#
#   tools/audio/render-arena-sounds.sh
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
masters="$here/final/arena-wav"
names=(dash bump bump_big coin coin_gold coin_lost coin_appear arena arena_hurry arena_final)

cd "$root"
dart run tools/audio/arena_sounds.dart
dart run tools/audio/arena_music.dart

for name in "${names[@]}"; do
  ffmpeg -y -i "$masters/$name.wav" -map_metadata -1 -c:a libvorbis -q:a 7 -ac 1 -ar 44100 "$root/assets/audio/$name.ogg"
done

# Each file has to match its master to the millisecond.
for name in "${names[@]}"; do
  printf '%-14s %8s s   master %8s s\n' "$name" \
    "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$root/assets/audio/$name.ogg")" \
    "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$masters/$name.wav")"
done
