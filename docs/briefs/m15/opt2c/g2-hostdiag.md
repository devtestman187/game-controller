job: M15 opt2c-2 (host diagnostics): per-second tap counters on the host and in the relay tunnel, written to the session log and the bench results
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/opt2c/CONTEXT.md (whole, first) · streaming/tap/tap_server.py · tap_queue.py · tap_runner.py (_on_new_sample) · tap_server_test.py (helpers only) · streaming/player/serve.py (_tunnel, _copy, _shut, page_files) · streaming/player/relay_test.py (the tunnel tests) · streaming/bench.sh (how a run's session log and results folder are written; grep for "tap:" and pipeline.log) · tools/stream.sh (cmd_selftest)
decide: low-usage mode: never stop for a question; safest choice, list each under "Decisions"; stop only if truly impossible ("Blocked").

Goal: after a collapsed run the logs must show where the backlog started: encoder output, the tap queue, the tap server's socket, or the tunnel's phone-side socket. Measuring only; no behaviour change.

Design:
1. Tests first (new streaming/tap/tap_diag_test.py, added to cmd_selftest in tools/stream.sh; fake clock and fake sockets where needed). New streaming/tap/tap_diag.py: class TapDiag, thread-safe, cheap on the pipeline thread. Per one-second window it keeps: encoder frames and bytes, key frames and their count/max bytes, delta frames avg/max bytes; per client: queue depth max, frames dropped in the window, key requests in the window, bytes sent, send() call time max and count over 10 ms, partial sends, timeouts, and the bytes still unsent in the kernel send buffer of the client socket (Linux `fcntl.ioctl(sock, termios.TIOCOUTQ, ...)`; -1 where unavailable). `line()` renders ONE log line per second only while a client is connected (or the window had frames and a client was seen in the last 10 s):
   `tapdiag: t=<unix s> fr=<n> kb=<n> key=<n> keymax=<KB> dmax=<KB> q=<max depth> drop=<n> kreq=<n> sent=<KB> sendmax=<ms> slow=<n> outq=<KB max>`
   (several clients: values summed or max'd as the names imply; document which).
2. Hook it in: tap_runner._on_new_sample feeds the encoder side (O(1) work); tap_server's `_write`/`_write_queued`/queue offers feed the per-client side; a 1 s thread (the existing stats thread may be reused, but the diag line must be each second and the old 5 s `tap:` line unchanged) writes the line to stderr. Keep tap_server.py at most 380 lines (move code out to tap_diag.py or a new module if needed).
3. The tunnel (streaming/player/serve.py is at 381 lines: MOVE `_tunnel`'s copy loops, `_copy` and `_shut` into a new streaming/player/tunnel.py with the same behaviour, and keep serve.py shorter than it is). The tunnel logs once a second, to stderr, while a tunnel is open: `tunnel: t=<unix s> up=<KB> down=<KB> sendmax=<ms> slow=<n> outq=<KB max>` where down is tap-server-to-phone bytes, sendmax and slow (over 10 ms) are the durations of the sendall toward the phone, and outq is the bytes unsent in the phone-facing socket's kernel buffer (TIOCOUTQ) and in the tap-facing socket. Add tunnel.py to the files the image copies (the Dockerfile copies the whole folder; page_files is only for files a browser fetches: tunnel.py is NOT one) and extend relay_test.py (tunnel byte-for-byte test must still pass, and a new test that the tunnel line appears with plausible numbers).
4. bench.sh: after a run, copy the session's `tapdiag:` and `tunnel:` lines (find how the session log is read there) to `<results>/<label>-tapdiag.log` and print one line at the end of the run's output: `tap diagnostics: <file>: seconds=<n> frames/s max=<n> key KB max=<n> queue max=<n> drops=<n> keyreq=<n> outq KB max=<n> tunnel outq KB max=<n> send ms max=<n>` (computed with awk; `-` when no lines). Test: a tiny shell self-test of the awk summary is not needed; run it by hand on a fixture and say so.
5. Prove it: `tools/stream.sh bench` uses the installed image, which does not yet hold your code, so test the modules by unit tests and by running tap_server/tunnel from the distro copy with a fake client; say that the bench line was only run on a fixture. No `build`.

in the report: Summary first, Hand-over last (the exact log line formats, so later jobs and the proof can parse them).
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: as CONTEXT.md; tests first.
allow: streaming/tap/tap_diag.py · streaming/tap/tap_diag_test.py · streaming/tap/tap_server.py · streaming/tap/tap_queue.py · streaming/tap/tap_runner.py · streaming/tap/tap_server_test.py · streaming/player/serve.py · streaming/player/tunnel.py · streaming/player/relay_test.py · streaming/bench.sh · tools/stream.sh · streaming/README.md · docs/briefs/m15/opt2c/g2-hostdiag-report.md · docs/briefs/m15/opt2c/g2-hostdiag
check: format
report: docs/briefs/m15/opt2c/g2-hostdiag-report.md
