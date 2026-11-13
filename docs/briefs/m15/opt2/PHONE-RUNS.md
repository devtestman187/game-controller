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
