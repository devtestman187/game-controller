# Game sounds

The ten event sounds in `assets/audio` — `hit`, `success`, `error`, `rumble`, `snap`, `wrong`, `tick`, `pickup`, `time_up` and `help` — are the "Bubble Pop" set. They're synthesised by `render.py` (numpy, no samples, CC0) and credited in `assets/CREDITS.md`. m11.3 replaced the Kenney sounds with them.

The extra cues (lobby, countdown, player_joined) aren't used yet; they wait for the look-and-sound milestone.

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
foreach ($n in 'tick','pickup','snap','error','hit','wrong','help','rumble','success','time_up') {
  "{0,-8} {1}" -f $n, (ffprobe -v error -show_entries format=duration -of csv=p=0 "$n.ogg")
}
```

> **Do not use VLC for this, even though it is installed and has a Vorbis
> encoder.** Its transcode pipeline silently drops the last 76–96 ms in either
> direction — measured here, a 100 ms `tick` came out 4 ms long, and decoding a
> 1.62 s file gave 1.54 s. ffmpeg wrote and read every file at its exact length.
