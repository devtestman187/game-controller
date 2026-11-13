# opt2 phone sitting: six runs, in this order

Gate (owner, Nov 13, 2026): 150 ms or less press-to-screen on the iPhone AND it feels fine to the owner. 150 or less adopts the custom player; otherwise it is dropped and the current WebRTC player stays. Latency work ends after this round either way.

Routine per run: the owner closes every stream tab on the phone and says ready; start ONE run (background); give the owner the URL it prints; the owner opens it in a fresh tab and stays on it until the run ends; then confirm `tools/stream.sh status` shows no session. Run from the repository root (Git Bash). Common part of every line: `--viewer external --seconds 60 --press-seconds 30 --set SESSION_MARKER=on`.

The page is plain http on the LAN; Safari 27.2 offers VideoDecoder there (probe, Nov 13). The player port is the one the phone already reaches (45782 for the first session; the bench prints the exact URL as `open http://<PC address>:45782/?<query> on a phone ...`). The WebSocket for `player=wc` goes through that same port (path `/tap`): no new port, no firewall rule.

| # | Label | Command (add after `bash tools/stream.sh bench`) | URL the phone opens |
|---|---|---|---|
| 1 | current player, run 1 | `--viewer external --seconds 60 --press-seconds 30 --label opt2-cur-1 --set SESSION_MARKER=on --player-query marker=1` | `http://<PC address>:45782/?marker=1` |
| 2 | current player, run 2 | same with `--label opt2-cur-2` | same |
| 3 | custom player, run 1 | `--viewer external --seconds 60 --press-seconds 30 --label opt2-wc-1 --set SESSION_MARKER=on --set SESSION_TAP=on --player-query "marker=1&player=wc"` | `http://<PC address>:45782/?marker=1&player=wc` |
| 4 | custom player, run 2 | same with `--label opt2-wc-2` | same |
| 5 | custom player + sound apart, run 1 | `--viewer external --seconds 60 --press-seconds 30 --label opt2-wcsep-1 --set SESSION_MARKER=on --set SESSION_TAP=on --set SESSION_AUDIO=separate --player-query "marker=1&player=wc"` | same as 3 |
| 6 | custom player + sound apart, run 2 | same with `--label opt2-wcsep-2` | same as 3 |

Full line, run 3 as the example (capture the output so the tables can be read afterwards):

```bash
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label opt2-wc-1 \
  --set SESSION_MARKER=on --set SESSION_TAP=on --player-query "marker=1&player=wc" 2>&1 | tee /tmp/opt2-wc-1.log
```

Notes for reading the runs:
- Sound with `player=wc`: the page keeps only the sound path of the WebRTC connection, and that exists only when the sound is separate (runs 5, 6). In run 3 and 4 (sound joined) the custom player has no sound; that is expected.
- Safari is the question: headless Chrome proved the code path (see opt2-6-proof-report.md) with software decode ("cfg nohint"); on the phone read the "decode config" and the decode-to-draw figure.
- The phone's run-to-run spread on press-to-screen is about 30 ms: judge by the two runs of each case, not one. The gate reads the card's median (and the marker must agree within 25 ms, else say so).
- The first frames can need a keyframe (at most about 1 s); a Safari that rejects `prefer-hardware` retries without it: the fact says which.

Tables to read from a run's log:

```bash
grep -n -A14 -E "^(switches:|Streaming quality|Independent check|Custom player \(wc\))|press>screen|press-to-screen" /tmp/opt2-wc-1.log | head -80
```

Order of reading: the "Independent check" verdict line (agree / DISAGREE by N ms); card press-to-screen median and p95; "Custom player (wc)" (recv -> decode, decode -> draw, drops, backlog, key requests, queue max, decode config); `jbtarget` is not used here. Then ask the owner how it feels.

Headless proof (no phone, Chrome, software decode, game at 41-48 fps), for comparison: current 259 ms card; wc 137, 141, 142, 153 ms; host pipeline time with sound apart 8 ms against 33-37 ms joined. These prove the path, not the phone.

---

# Second sitting (after the Nov 13 faults): four runs

First sitting (Nov 13): runs 1-2 (current player) measured 162 / 176 ms card (marker 159 / 176); runs 3-6 gave no measurement (the `player=wc` page never registered; see docs/briefs/m15/opt2b/CONTEXT.md and the journey notes). Baseline for the gate stays those two figures.

Fixed since: the page died on a 404 (two new files not on the relay's list), the wc batch now registers without the marker, the tap encodes 4:2:0 (avc1.42C02A) so Safari should decode it, decoder errors rebuild and are counted, a tap anywhere starts the sound, page errors show on the overlay and in the session log. Run `bash tools/stream.sh build` first (done after the last fix), then the same routine as above (owner closes all stream tabs and says ready; one run at a time; I give the URL).

| # | Label | Extra part of the command (after `bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --set SESSION_MARKER=on --set SESSION_TAP=on`) | URL |
|---|---|---|---|
| 1 | wc, run 1 | `--label wc2-1 --player-query "marker=1&player=wc"` | `http://<PC address>:45782/?marker=1&player=wc` |
| 2 | wc, run 2 | `--label wc2-2 ...` as 1 | same |
| 3 | wc + sound apart, run 1 | `--label wc2-sep-1 --set SESSION_AUDIO=separate --player-query "marker=1&player=wc"` | same |
| 4 | wc + sound apart, run 2 | `--label wc2-sep-2 ...` as 3 | same |

What the owner does for sound (runs 3-4 only; runs 1-2 have no sound by design): after the page opens, **tap the picture once** (anywhere), with the phone's mute switch off and the volume up. A "tap for sound" button shows if the browser has blocked it. Say whether you hear it; the bench table's `sound` column should read `playing` (`blocked` means no tap reached the page).

If a run still shows "no viewer" after 30 s, the phone's page is showing an error: it is printed on the page's top line and in the session log (`relay: page error ...`). Read it out or screenshot it; do not wait the 180 s. A page that says VideoDecoder is missing, or "the host sends 4:4:4", names its own cause.

Reading the logs: same grep as above. New columns in "Custom player (wc)": errors, rebuilds, error, sound, snd playing. The "Streaming quality" row now has fps, recv, decoded, dropped and freezes for the wc page too. The gate: card median 150 ms or less, marker within 25 ms, feels fine.

Headless proof of the fixed build (plain http on 127.0.0.2, Chrome, software decode): wc 139 ms card (marker 129); wc + sound apart 116 and 125 ms card (marker 102, 103); the table and the row render; sound `playing`. Not Safari.
