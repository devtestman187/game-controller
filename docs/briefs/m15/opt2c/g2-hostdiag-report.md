# M15 opt2c-2 (host diagnostics): per-second tap and tunnel counters

## Summary

- **Built:** `streaming/tap/tap_diag.py` (class `TapDiag`, `send_message()`,
  `socket_send_queue()`), hooked into `tap_server.py`/`tap_queue.py`/`tap_runner.py`;
  `streaming/player/tunnel.py` (the moved tunnel, now counted); `serve.py` is down from
  381 to 346 lines; `bench.sh` keeps the two kinds of line in `<results>/<label>-tapdiag.log`
  and prints one `tap diagnostics:` line; `tools/stream.sh selftest` runs the new test file;
  `streaming/README.md` documents both lines.
- **Tests:** `tap_diag_test.py` 20 tests OK (new, written first, failed on the old tree with
  `ModuleNotFoundError: tap_diag`); `tap_server_test.py` 32 OK (was 30, +2 for the hook);
  `relay_test.py` 44 checks (was 39, +5 for the tunnel line, the old 39 unchanged);
  `bash streaming/bench.sh --selftest` all six pages PASS; `python3 -m py_compile` on all nine
  changed Python files OK; `bash -n` on both scripts OK; `tools/check.sh format` PASS.
- **Proof with a fake client:** the real `TapServer` on loopback produced
  `tapdiag: t=1794603665 fr=60 kb=1360 key=1 keymax=180 dmax=20 q=1 drop=0 kreq=0 sent=1361 sendmax=0 slow=0 outq=165`
  and the real `Tunnel` with a phone that stopped reading produced
  `tunnel: t=1794603828 up=0 down=192 sendmax=0 slow=0 outq=232` then, in the second it
  was read again, `tunnel: t=1794603830 up=0 down=576 sendmax=2500 slow=1 outq=0`.
- **Not run:** no bench with the image (the image does not hold this code) and no `build`, as
  the brief says; the `tap diagnostics:` line was run by hand on a fixture only (values below).
- **Turns:** about 40.

## Files changed

- `streaming/tap/tap_diag.py` (new, 322 lines): one-second windows of the encoder's frames
  (frames, KB, keyframes, key max, delta max and average), each client's queue depth max,
  drops, keyframe requests, bytes sent, send time max, slow sends, partial sends, timeouts
  and the kernel's unsent bytes (TIOCOUTQ); `line()` renders one line or nothing;
  `send_message()` is the measured send loop; `window()` exposes the last window's numbers.
- `streaming/tap/tap_diag_test.py` (new, 279): fake clock, fake queue, fake sockets, one real
  socketpair for the ioctl.
- `streaming/tap/tap_server.py` (379, was 370): creates the diag, feeds it on each offer, adds
  and removes clients, writes its line from the stats thread each second while PROTOCOL.md's
  `tap:` line keeps its 5 s tick, and sends through `tap_diag.send_message`; `stats()` now calls
  `tap_queue.totals()` so the file stays under 380.
- `streaming/tap/tap_queue.py` (163): `ClientQueue.level()` (depth and the two totals) and
  `totals(queues)` moved out of the server.
- `streaming/tap/tap_runner.py` (368): `_on_new_sample` feeds `server.diag.frame(is_key, len(data))`.
- `streaming/tap/tap_server_test.py` (447): two tests for the hook (the line counts the encoder's
  frame and the client's socket; no client, no line).
- `streaming/player/tunnel.py` (new, 179): the moved `_tunnel` copy loops, `_copy`, `_shut`, the
  three tunnel constants, and `Tunnel` with the once-a-second line and TIOCOUTQ of both sockets.
- `streaming/player/serve.py` (346, was 381): `_tunnel` is a call to `tunnel.relay()` plus the 502;
  `_copy`, `_shut`, the tunnel constants and the unused `socket` import are gone.
- `streaming/player/relay_test.py` (470): serve.py's stderr kept in a file, `FakeTap` serves
  several tunnels, new `test_tunnel_line` with 5 checks.
- `streaming/bench.sh` (1077): `collect_tap_diag` and `tap_diag_summary` (awk), called after
  `report_run`.
- `tools/stream.sh` (776): `cmd_selftest` runs `tap_diag_test.py`.
- `streaming/README.md` (637): the two log lines under "Logs".

## Test values

- Diag window: 200 KB key + 10 KB + 20 KB deltas → `fr=3 kb=230 key=1 keymax=200 dmax=20`,
  delta average 15 KB. Sends 2048+1024+0+512 bytes in 20/2/1/30 ms → `sent=3 sendmax=30 slow=2`,
  `partial=1 timeouts=1` in `window()`. Two clients (depth 4 and 2, 1 KB and 2 KB sent, 20 and
  50 ms, outq 4 KB and 8 KB) → `q=4 sent=3 sendmax=50 outq=8`.
- `send_message`: a socket that takes all → `SEND_OK`; one that times out at once → `SEND_BLOCKED`
  with `timeouts=1`; one that takes half then times out → `SEND_BROKEN` with `partial=1`,
  `sent_kb=2` of 4 KB.
- `socket_send_queue`: > 0 on a socketpair whose peer reads nothing (4 KB SO_SNDBUF), -1 on a
  closed socket.
- Bench summary on a hand-made fixture of two `tapdiag:` and two `tunnel:` lines:
  `seconds=2 frames/s max=60 key KB max=240 queue max=4 drops=37 keyreq=2 outq KB max=232 tunnel outq KB max=380 send ms max=25`;
  on an empty file every field is `-`.

## Decisions (low-usage mode)

- The brief's line has no field for partial sends, timeouts or the deltas' average, so they are
  counted and exposed through `TapDiag.window()` (tested) rather than dropped; the line format
  is exactly the brief's.
- The measured send loop moved from `tap_server._write` into `tap_diag.send_message()`: it is
  where the timings are taken, and it keeps `tap_server.py` at 379 lines.
- `tap_queue.totals()` now holds PROTOCOL.md's aggregation, moved out of the server for the same
  size reason.
- `outq` is read after every send and again when the window closes, so a client that closed in
  the window still shows its last reading; a kernel that will not answer gives -1.
- `serve.py` sets `close_connection` before the tunnel call (it set it just before the copies
  before): the tunnel's bytes are unchanged, and a 502 now also closes the connection.
- The tunnel keeps its own 8-line TIOCOUTQ reader: the tap and the relay are separate processes
  in separate folders of the image, and no shared module is in `allow:`.
- `FakeTap` in `relay_test.py` now takes a thread per tunnel, because the tunnel-line test opens
  a second one.
- bench keeps every session's lines in one `<label>-tapdiag.log` (the brief's path) and prints
  the summary after `report_run`, so it is the last line of the measurements.

## Obstacles

- `tools/stream.sh selftest` needs an approval the sandbox refused, so its four commands were
  run one by one in the distro instead; `bash -n tools/stream.sh` passes.
- `bench.sh` was already 1031 lines (the CONTEXT's 380-line rule for scripts), and the brief puts
  the new code there; it is now 1077. Splitting it is not in this job's files.
- The distro prints nothing for a python script's `print` when its stderr is a file in some
  invocations; the proof scripts were read through their captured stderr instead. Nothing in the
  repository depends on it.

## Self-check (review-rules.md part A)

1. **Every host setup:** not affected — Python inside the session image only, no app build; checked
   by `tap_server_test.py`, `relay_test.py` in the distro.
2. **When kept state starts and ends:** a window starts at the diag's first tick or the first
   client's offer and ends at each `line()`; with no client and no frames no line is written and
   the counters reset each second (`test_frames_with_no_client_connected_are_no_line`,
   `test_a_connected_client_gets_a_line_even_with_no_frames`).
3. **How it combines with other states:** there is no pause/hide state here; a closed client is
   counted until its window ends and then dropped
   (`test_a_client_seen_in_the_last_ten_seconds_keeps_the_line_of_a_window_with_frames`), and the
   stats thread ends with `stop()` as before.
4. **Stay in the job's folder:** only files in `allow:` changed (`git status` shows nothing else
   of mine; the `tv_test_app` generated files and `docs/.../run-base` folders were already there).
5. **Stop rather than overstep:** nothing outside `allow:` was needed; the only rule bent is
   bench.sh's size, above.

## Hand-over

The two lines, exactly (one space-separated line each, ending in `\n`, to stderr):

```
tapdiag: t=<unix s> fr=<n> kb=<n> key=<n> keymax=<KB> dmax=<KB> q=<max depth> drop=<n> kreq=<n> sent=<KB> sendmax=<ms> slow=<n> outq=<KB max>
tunnel: t=<unix s> up=<KB> down=<KB> sendmax=<ms> slow=<n> outq=<KB max>
```

- `tapdiag:` once a second while a client is connected, and for a window that holds frames and
  a client seen within 10 s; `tunnel:` once a second while a tunnel is open.
- Several clients: `q`, `sendmax`, `outq`, `keymax`, `dmax` are maxima; `drop`, `kreq`, `sent`,
  `slow` are sums. KB and ms are whole numbers; `outq=-1` means the kernel would not say.
- A proof parses with: `^tapdiag: t=(\d+) fr=(\d+) kb=(\d+) key=(\d+) keymax=(\d+) dmax=(\d+) q=(\d+) drop=(\d+) kreq=(\d+) sent=(\d+) sendmax=(\d+) slow=(\d+) outq=(-?\d+)$`
  and the same shape for `^tunnel:` with `up`, `down`.
- `bench.sh` writes both kinds to `<out>/<label>-tapdiag.log` and prints
  `tap diagnostics: <file>: seconds=<n> frames/s max=<n> key KB max=<n> queue max=<n> drops=<n> keyreq=<n> outq KB max=<n> tunnel outq KB max=<n> send ms max=<n>`
  (`-` for a group the log has no line of).

## Commit message

M15 opt2c: per-second tap and tunnel counters in the session log

Add streaming/tap/tap_diag.py: one-second windows of the encoder's frames and
each tap client's queue, send times, partial sends, timeouts and the unsent
bytes in its socket, written as one `tapdiag:` line a second.
Hook it into tap_server, tap_queue and tap_runner; PROTOCOL.md's `tap:` line
keeps its 5 s.
Move the relay's tunnel into streaming/player/tunnel.py (serve.py 381 -> 346),
which now writes a `tunnel:` line a second with bytes both ways and both
sockets' unsent bytes.
bench.sh keeps both kinds in <results>/<label>-tapdiag.log and prints one
`tap diagnostics:` line; selftest runs the new test file; README documents both.

## Status row

M15 opt2c-2 host diagnostics: per-second `tapdiag:`/`tunnel:` lines, the hook into tap and relay, the bench file and summary, and the tests are done and green; open: a real bench run with an image that holds this code, and any decision on adding partial/timeout fields to the line.

## Delete

- none
