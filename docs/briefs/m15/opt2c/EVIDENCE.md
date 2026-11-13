# opt2c evidence: where the backlog starts (headless, instrumented, Nov 13, 2026)

Run o2c-stall-diag2 (docs/briefs/m15/bench-results/20261113-151824/o2c-stall-diag2; wc + SESSION_TAP=on + separate sound, netem stalls of 250-490 ms every 3 s on the browser hop for 30 s). Old policies, new counters.

- Host tap server (tapdiag lines): drop=0, kreq=0 and sendmax 0-1 ms in EVERY second of the run (queue depth 1). The tap server never saw a stall: its socket to the tunnel is on loopback and takes everything.
- Tunnel (tunnel lines): outq (unsent bytes in the phone-facing socket) 199-311 KB in single seconds during stalls (about 0.25-0.4 s of video at 9 Mbit/s), 0 otherwise; sendall to the phone never blocked more than 1 ms. So the delay builds in the kernel buffer and in TCP, invisible to the sender.
- Page (diagnostics table): gap max 491 ms, 7 gaps over 250 ms; decoder queue max 2-3; main thread lag max 57 ms (not the main thread).
- Page drops: 196 dropped, 9 keyframe requests. Mechanism (wc_player.js _handleFrame): after a stall the burst of frames arrives at once, the decoder queue passes maxQueueDepth (2), the page drops that delta and asks for a keyframe, and every later delta fails the `frame !== lastFrame + 1` test and is dropped too, until the next IDR (up to a second). A stall of 300 ms therefore costs about 22 frames and a keyframe request. The host never dropped anything.
- Key sizes: IDR 51-75 KB (about 0.5 Mbit), deltas 13-33 KB peak; stream about 4.3 Mbit/s on this game scene (the phone's 14-21 Mbit/s came with the storm's repeated IDRs and a busier scene).

Conclusion: the storm starts on the PAGE (burst arrival -> drop-until-keyframe -> key request), fed by silent buffering between the tap server and the phone (nothing on the host side sees or limits a stall). Fixes: (1) the page decodes a burst and draws only the newest frame, with a keyframe request only when the decoder is truly overloaded; (2) one outstanding spaced request on both sides; (3) host back-pressure (small send buffers) so a long stall is visible and bounded.
