# Game sounds

The ten event sounds in `assets/audio` — `hit`, `success`, `error`, `rumble`, `snap`, `wrong`, `tick`, `pickup`, `time_up` and `help` — are the "Bubble Pop" set. They're synthesised by `render.py` (numpy, no samples, CC0) and credited in `assets/CREDITS.md`. m11.3 replaced the Kenney sounds with them.

The three cues beside them come from the same set and are played by the host screens since M13 step 7: `lobby` (19.20 s, a seamless loop under the game picker and the join screen), `countdown` (4.42 s: beeps at 0, 1 and 2 s, then the "go" chord at 3 s) and `player_joined` (1.02 s, a phone joining the host). They are listed in `assets/CREDITS.md` like the event sounds.

## How these were encoded

Ogg Vorbis, quality 7, mono 44.1 kHz, from the PCM masters in
`tools/audio/final/palette-b-bubble-pop-wav/` (`render.py` writes them next to
itself; they are not in the repository), with ffmpeg 9.0.2 (Gyan full build).
Every file was decoded back and checked against its master: exact length,
25–41 dB SNR.

Re-encode after editing a master:

```powershell
# from the repository root
$masters = "tools\audio\final\palette-b-bubble-pop-wav"
foreach ($f in Get-ChildItem "$masters\*.wav") {
  ffmpeg -y -i $f.FullName -map_metadata -1 -c:a libvorbis -q:a 7 -ac 1 -ar 44100 ("assets\audio\" + $f.BaseName + ".ogg")
}
```

Check durations afterwards: each should match its WAV master to the millisecond (`ffprobe` the `.wav` the same way):

```powershell
cd assets\audio
foreach ($n in 'tick','pickup','snap','error','hit','wrong','help','rumble','success','time_up','lobby','countdown','player_joined') {
  "{0,-8} {1}" -f $n, (ffprobe -v error -show_entries format=duration -of csv=p=0 "$n.ogg")
}
```

> **Do not use VLC for this, even though it is installed and has a Vorbis
> encoder.** Its transcode pipeline silently drops the last 76–96 ms in either
> direction — measured here, a 100 ms `tick` came out 4 ms long, and decoding a
> 1.62 s file gave 1.54 s. ffmpeg wrote and read every file at its exact length.

## The Arena's sounds and music (M14)

The Bumper Round's seven one-shots — `dash`, `bump`, `bump_big`, `coin`, `coin_gold`, `coin_lost` and `coin_appear` — and its music — `arena`, `arena_hurry` and `arena_final` — are made by two Dart renderers, because the PC that made them has no numpy:

- `arena_sounds.dart` builds each one-shot from the kit's instruments, masters it with `render.py`'s event pass (high-pass, RMS to the cue's own loudness in the script's table, soft-knee peak limit at −3 dB, 4 ms fades) and seeds it, so the same WAV comes out every run.
- `arena_music.dart` plays one 16-bar piece in G major at three tempos — 128, 147.2 and 166.4 BPM, a whole number of samples per sixteenth — folds two seconds of ring-out back over the loop's start and masters it as `finish_loop` does, to RMS −23 dB and a peak under −3 dB. The run fails if a loop is not 16 bars or peaks above −3 dB.

Both write their WAV masters to `tools/audio/final/arena-wav/` (gitignored, as `render.py`'s are) and print a table: each file's length, RMS and peak, and for each loop the size of the jump between its last and first sample against the mean sample-to-sample step.

Render and encode again, from the repository root (Git Bash, ffmpeg and ffprobe on the PATH):

```bash
tools/audio/render-arena-sounds.sh
```

It runs both renderers, then encodes every master with the same ffmpeg line as above and prints each file's length beside its master's, so a short encode shows up as a mismatch (VLC would make one).
