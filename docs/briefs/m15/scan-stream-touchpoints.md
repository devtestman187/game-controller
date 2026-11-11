job: read-only scan: what Thumb Party already has for a video-streamed host (game runs on a Windows PC with an RTX 3080 or a cloud GPU, video goes to a thin client, the phone controller keeps working)
pub: no
stop: after the report.
read: docs/PRD-v2.md ("Platform direction", the streaming-ready rules S1–S9, "What it records", the v3 candidates table, Milestone 9 and 12 notes on latency stages) · docs/decisions.md and docs/project-notes.md (anything on streaming, the "PC bridge", the demo-video branch, Windows hosting) · docs/protocol.md · packages/protocol, packages/connection (discovery, pairing code, how a phone finds and reaches a host; every LAN-only assumption) · packages/metrics (the latency stages: names, where each is stamped, how a new stage would be added; session.dart, session_player.dart, report.dart) · packages/game_kit (the host interface, GameSession, FrameView, render-to-size, sound by event name) · packages/party_host (how the host draws, local players, the pause/away states) · tv_test_app (the Windows build: window or fullscreen, resolution, frame rate cap, audio output, command-line flags, how it shows the pairing code) · tools/tv-window.ps1, tools/tv-dev.sh, tools/smoke.sh · controller_app (how the phone connects by code or address: can it reach a host that is not on its Wi-Fi?)
decide: low-usage mode: never stop for a question; state assumptions under "Decisions".

The owner wants a testable video-streaming version in 1–2 days: the TV app runs on a Windows PC (RTX 3080), its window is captured and streamed to a thin client on a TV, phone or tablet, and players still use the Thumb Party phone controller. Stage-by-stage latency (S7) must extend to encode, network, decode and display. Change no file but the report. Answer each with file:line at HEAD:
1. **What the PRD and decisions already say** about streaming, v3 and S1–S9: quote the rules, and say for each rule whether the code meets it today (with evidence).
2. **The Windows host as a stream source**: how tv_test_app runs on Windows (window/fullscreen, resolution, vsync/frame cap, audio device, flags); anything that would stop a capture tool (Sunshine, OBS, a WebRTC capturer) from capturing it at 1080p60; whether it can run headless or on a virtual display.
3. **The controller path when the screen is remote**: how the phone discovers and connects (mDNS? broadcast? the four-digit code: how it maps to an address), which parts assume the same Wi-Fi, what "type the address" accepts (IP:port? a host name?), whether a phone on another network could connect if the PC's port is reachable (port forward, Tailscale), the port(s) and protocol (TCP/UDP/WebSocket), and any timeouts tuned for LAN.
4. **Latency stages today**: each stage's name, where it is stamped (file:line), its clock (whose clock, how phone and host clocks are aligned), how stages reach the session summary and the report; then exactly where "encode", "network", "decode" and "display" stages could be added with the least change, and what a streaming client or capture tool would have to report for each.
5. **What a thin client must show**: does anything on the TV screen need input from the TV device itself (remote presses, consent prompts, settings), or can everything be driven from the phone? What on the host screen is device-specific (the pairing code, Wi-Fi name, stats consent)?
6. **Phone as its own display**: could the phone that controls also show the video (controller overlay over video)? What in controller_app would need to change?
7. **Reuse list**: what can be used as is, what needs a small change, what is missing, for (a) streaming with an off-the-shelf tool and no code change, (b) adding the four latency stages to our metrics, (c) a cloud GPU host.
8. **Risks and unknowns** you could not settle from the code.

in the report: the answers in that order, short, with file:line; a one-page summary at the top.
rules: change no file but the report · install nothing
allow: docs/briefs/m15/scan-stream-touchpoints-report.md
check: format
report: docs/briefs/m15/scan-stream-touchpoints-report.md
