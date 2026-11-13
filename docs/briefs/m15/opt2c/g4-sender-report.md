# M15 opt2c-4 sender: report

## Summary

The tap server no longer writes a frame to the socket in one call and gives up
on it: `streaming/tap/tap_sender.py` holds at most one message at a time,
writes it with `send(..., MSG_DONTWAIT)`, and finishes it when the socket
allows — a message is never abandoned half-way and a slow client is never
closed for being slow (only one whose socket accepts nothing for 5 s is). Every
socket that carries frames now has TCP_NODELAY and a small send buffer: 96 KiB
on the tap server's client socket and on the relay's phone-facing socket, 64 KiB
send and receive buffer on the tunnel's tap-facing socket, all set at
accept/connect. With the kernel auto-tuning gone, a phone that stops reading
fills the buffer in tens of milliseconds and shows up as `blocked` (ms a
message waited) and `outq` instead of megabytes of hidden backlog.

The queue gained the age rule: each frame is stamped when it is queued, and
before a message starts the sender drops frames older than two frame times
(`2 / fps` from the hello, 33.3 ms at 60 fps). If the oldest frame left is a
delta whose predecessor was dropped that way, the client jumps to the newest
keyframe in its queue (that frame already carries the discontinuity flag) or,
with none, clears and waits for the next keyframe under g3's key rule with no
extra ask. The tunnel hop stays; the flaky slow-client test is now driven by
conditions instead of sleeps and was green 20 runs in a row. Transport stays
WebSocket: a WebRTC DataChannel sender still needs a GstWebRTC typelib the
session image does not ship.

## Files changed

- `streaming/tap/tap_sender.py` (new, 167): `MessageSender` — control messages
  first, one queued frame per message, `pump`/`_flush`/`_finish`, per-wait
  blocked time, `has_stalled`/`wait_s` for the 5 s close, `write_sockets` for
  select; `age_limit_s(fps)`.
- `streaming/tap/tap_sender_test.py` (new, 195): 11 tests on a real socketpair
  (SNDBUF 4 KiB): whole message, message in parts finished byte for byte,
  blocked timing, stall at 5 s, frames waiting in the queue, a control message
  after a half-written frame, closed peer, fps flowing into the age limit.
- `streaming/tap/tap_server.py` (379): uses the sender, `TAP_SNDBUF_BYTES = 96
  KiB` set right after accept together with TCP_NODELAY, select on writability
  while a message waits plus the 5 s stall close, `send_control` for
  hello/pong/close/end, `client_sockets()` for the tests, `SEND_TIMEOUT_S` and
  the one-shot `_write` gone.
- `streaming/tap/tap_server_test.py` (500): the flaky slow-client test made
  deterministic (fast client reads each frame before the next publish; loop
  stops at the first drop within 16 frames; asserts the fast client dropped 0
  and the slow one did, and its `outq` stays within 2 × 96 KiB); new
  NODELAY/send-buffer test on the accepted socket; queue tests moved to
  `take_for_send`.
- `streaming/tap/tap_queue.py` (271): `Frame` carries `enqueued_s`;
  `take_for_send(age_limit_s)` drops aged frames, jumps to the newest keyframe
  (flagging discontinuity) or clears to the key rule; lock instead of the old
  notify; `aged` in `level()`/`totals()`/`stats()`; `take` and
  `drop_to_keyframe` removed.
- `streaming/tap/tap_queue_test.py` (219): age tests (inside the limit, past
  it, delta behind an aged frame, no keyframe left, second clear inside the
  spacing) and the remaining tests on `take_for_send`.
- `streaming/tap/tap_diag.py` (301): the tapdiag line gained `blocked=` (ms) and
  `aged=`, both per window from monotonic totals; `send(client, bytes, s)`
  replaces `send_message`; the `timeouts`/`partial` counters and the
  SEND_OK/BLOCKED/BROKEN values are gone.
- `streaming/tap/tap_diag_test.py` (242): `blocked`/`aged` window tests
  (including a message still pending), the fake queue gained `blocked_s`.
- `streaming/player/tunnel.py` (202): TCP_NODELAY on both sockets in
  `Tunnel.__init__`, `TAP_SNDBUF_BYTES = 96 KiB` on the phone-facing socket,
  `TAP_RCVBUF_BYTES`/`TAP_UP_SNDBUF_BYTES = 64 KiB` on the tap-facing one;
  `relay()` no longer sets NODELAY.
- `streaming/player/relay_test.py` (500): `test_tunnel_socket_tuning()` on two
  TCP loopback pairs (Nagle off both ways, buffers ≤ 2× the constants), 5
  checks.
- `tools/stream.sh`: `cmd_selftest` runs `tap_sender_test.py`.
- `streaming/README.md`: the `tapdiag:` line, what `blocked` and `aged` mean,
  the sender's message rule, the 5 s close, the age rule and the small buffers.
- `docs/briefs/m15/opt2/PROTOCOL.md`: an age-rule paragraph after the backlog
  rule (limit from the hello's fps, keyframe jump, no extra ask) and the small
  buffers/back-pressure sentence.

## Tests and values

- Red first, on the old tree: `tap_sender_test.py` →
  `ModuleNotFoundError: No module named 'tap_sender'`; `tap_queue_test.py` →
  `AttributeError: 'ClientQueue' object has no attribute 'take_for_send'`
  (6 errors in 16 tests).
- In tp-stream, on the finished tree: `tap_sender_test.py` 11 OK,
  `tap_queue_test.py` 16 OK, `tap_diag_test.py` 19 OK, `tap_server_test.py`
  33 OK (3.617 s), `tap_runner_test.py` 6 OK, `relay_test.py`
  "relay test: 49 checks passed" (44 before), `bench.sh --selftest` all five
  pages PASS, exit 0.
- The slow-client test, alone, 20 runs: 20 OK.
- Constants: `AGE_LIMIT = 2 / 60` = 0.0333 s (33.3 ms; the brief's 34 ms);
  `age_limit_s(30)` = 0.0667; `age_limit_s(None)`/`(0)` = 2/60. Linux doubles
  SO_SNDBUF/SO_RCVBUF, so 96 KiB shows as 192 KiB and 64 KiB as 128 KiB;
  the tests allow `<= 2×`. `STALL_CLOSE_S` = 5.0, `QUEUE_FRAMES` 4.
- `python3 -m py_compile` on the seven changed modules: OK; `bash -n
  tools/stream.sh`: OK.
- Format: `dart format --output=none --set-exit-if-changed controller_app
  tv_test_app packages assets` → 795 files, 0 changed (PASS).

## Decisions

- **The tunnel hop stays.** A replacement would need fd passing or a new
  listener per phone; both cost more than the hardened tunnel. It is sized
  like the tap's own sockets, so its backlog shows the same way.
- **Control messages go first**, so a pending frame never delays `end`, a pong
  or a close, but a half-written frame is still finished before them — a
  WebSocket frame may not be interrupted.
- **`MSG_DONTWAIT` on every send**, so the socket keeps blocking reads with
  select, and a full buffer is a `BlockingIOError` the sender counts.
- **The age clear uses `queue._clear_to_keyframe()` through the key gate**: a
  cleared client asks once for a keyframe, and a second clear inside the 1.5 s
  spacing is held back and counted (`keyreq_suppressed`), as g3 fixed.
- **A 5 s silent socket is closed**; a slow client that still accepts some
  bytes is never closed. `pending_s` counts from the last byte the socket took.
- **Removed `tap_server`'s `send_message`, `SEND_OK/BLOCKED/BROKEN`,
  `timeouts`/`partial`, `ClientQueue.take` and `drop_to_keyframe`**: the
  sender and `take_for_send` replace them, and their coverage moved to
  `tap_sender_test`/`tap_queue_test` rather than being left duplicated.
- **`client_sockets()`** is public only for the tests' `getsockopt` checks
  (the brief asks for the accepted socket's options to be asserted).
- **The buffer constants stand in both files**: `tap_server.py` and
  `tunnel.py` run in separate processes from separate folders, and the
  relay may not import the tap.
- **Transport: WebSocket stays.** Recorded as the brief asks: a WebRTC
  DataChannel sender needs `GstWebRTC` in the session image's Python bindings,
  which it does not ship; tp-stream's host GStreamer does have `webrtcbin`,
  so the gap is the image's typelib, not the host's plugins. Building that
  image path is its own job.

## Self-check (review-rules A, items 1–5)

1. **Every host setup.** The tap server and tunnel are host-side and the same
   for every phone; a phone on "Play on this phone" is the tunnel's one user,
   and no other setup reads these sockets. Covered by `relay_test.py`,
   `tap_server_test.py` — not affected by the setups that never open `/tap`.
2. **When kept state starts and ends.** Sender state starts at accept (buffers,
   sender) and ends on close/removal; `pending_s` starts at the first refused
   byte and ends at the finish or the 5 s close; the age stamp starts at
   `offer` and ends at send or drop. Tested: `tap_sender_test` stall/wait and
   `tap_queue_test` aged frames.
3. **How a new state combines with the others.** The new states (waiting for
   writability, aged drop) sit inside one client thread and never touch pause,
   away or results; a pending message and the stop path are tested together
   (`end` after a half-written frame).
4. **Stay in the job's folder.** Only the brief's `allow:` files changed; the
   report and this list are the only docs written.
5. **Stop rather than overstep.** Nothing needed outside `allow:`; the
   transport item is recorded, not built.

## Suggestions and open items (not acted on)

- The tunnel's `TAP_*` constants duplicate `tap_server.py`'s because of the
  folder split; a shared file would need a change to the allow list.
- `tools/check.sh format` itself could not be run here (the shell refused the
  script and needed approval); its single step was run by hand and passed.
- Worth measuring next: the Nov 13 stall runs with the new `blocked`/`aged`
  counters, to see whether the first backlog shows at the tap at all once the
  kernel buffers are small.
- The 5 s stall close has no test with a real full socket beyond the
  `has_stalled`/`wait_s` unit tests; an integration case would need a socket
  the kernel refuses for 5 s.
- `git status` shows six `tv_test_app/**/generated_plugin*` files modified
  with an empty content diff (line endings only); this job did not touch them.

## Hand-over

- Start from `streaming/tap/tap_sender.py`: one message at a time, control
  first, `MSG_DONTWAIT`, `pending_frame_bytes` counted at `note_sent`.
- The queue's `take_for_send(age_limit_s)` is the only reader now; `take` and
  `drop_to_keyframe` are gone.
- `tapdiag:` ends `… slow= blocked= aged= outq=`; `bench.sh` reads by field
  name, so it needed no change. The README documents both.
- The next gate should run `tools/stream.sh selftest` (now six Python suites
  plus the page) on a machine where the script is allowed, and a real phone
  run with the small buffers.

## Commit message

M15 opt2c: the tap sender finishes messages and ages frames

A tap message is written with send(MSG_DONTWAIT) and finished when the socket
allows, never abandoned; control messages wait behind a half-written frame
and a socket that takes nothing for 5 s is closed. Each frame is stamped when
queued and frames older than 2/fps are dropped before a message starts; a
delta behind one jumps to the newest keyframe or waits under the key rule.
TCP_NODELAY and 96 KiB send buffers (64 KiB in the tunnel) make a stalled
phone visible as blocked/aged/outq instead of hidden kernel backlog. The
slow-client test waits on conditions and was green 20 runs.

## Status row

M15 opt2c-4 sender: the tap sender's whole-message writes, aged-frame drop with keyframe jump, small tap/tunnel buffers and NODELAY, the `blocked`/`aged` diag fields, a deterministic slow-client test (20/20) and the recorded WebSocket decision are done and green (tap sender 11, queue 16, diag 19, server 33, runner 6, relay 49 checks, five page self-tests, format PASS); open: a real phone run with the small buffers and the selftest through `tools/stream.sh`.

## Delete

- none
