# opt2b: shared context for every job of this batch (read it first, whole)

Game-streaming project. A Linux session image (WSL2 distro tp-stream) captures a game, encodes H.264 1080p60 (nvautogpuh264enc) and sends it with webrtcsink to a page (streaming/player). Batch opt2 added the custom player: page option `player=wc` (WebCodecs VideoDecoder drawing on a canvas, video over the host WebSocket `/tap`, host switch SESSION_TAP=on; sound with SESSION_AUDIO=separate is a sound-only WebRTC connection). Background: docs/briefs/m15/opt2/PROTOCOL.md and, of docs/briefs/m15/opt2/opt2-3-page-report.md, only Summary and Hand-over.

## What happened (iPhone Safari 27.2, plain http page on the LAN, NOT a secure context; the probe said VideoDecoder exists there), Nov 13, 2026
Bench: `--viewer external --seconds 60 --press-seconds 30 --set SESSION_MARKER=on --set SESSION_TAP=on --player-query "marker=1&player=wc"`.
- The owner SAW a fine moving picture, but the bench waited 180 s ("still no viewer") and failed: it counts a viewer only when /stats/session holds `bitrateReceivedKbps`, `stream_display` or `stream_decode` (see wait_viewer / has_receive_data in streaming/bench.sh). So four of six runs gave no measurement.
- With `SESSION_AUDIO=separate` no sound was heard (mute switch checked, picture tapped), and once the page showed "the decoder stopped: Decoder failure" from the first frame while a choppy picture kept playing.
- The tap stream is profile avc1.F4002A = High 4:4:4 Predictive (opt2-1 report): Safari's decoders do not take 4:4:4.
- The headless proof ran the page over localhost with marker=1, which hid all of this. Plain http is not a secure context: VideoDecoder, crypto.subtle, crypto.randomUUID, navigator.clipboard, mediaDevices, Notification, serviceWorker are absent there in Chrome (Safari 27.2 still offers VideoDecoder).

## Rules for every job
- decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".
- Report starts with `## Summary` (at most 25 lines, in its first 40 lines): what was built (files), tests and results, root cause (proved or suspected: say which), decisions, not done, obstacles (one line each), turns if known. Ends with `## Hand-over` (at most 20 lines: what exists, exact commands that worked, what not to redo, open problems). Self-check: docs/review-rules.md part A items 1-5, one line each.
- Aim for about 100 turns (hard target 150). No lib or script file you touch may end over 380 lines (split it; the runner stops otherwise); no function over 60 lines. Tests first: each new test file must fail on the code as it was; a behaviour change gets a failing test first.
- Scripts pass `bash -n`, python passes `python3 -m py_compile`. Install nothing, download nothing. Never `wsl --shutdown`. Touch only processes you started, by PID. Wrap long commands in `timeout`. Leave no scratch file behind (temp files in /tmp inside the distro, deleted afterwards).
- Every switch defaults OFF; behaviour with it off stays identical. Never touch E:\AI\game-controller. Never print the DeepSeek key.
- Do not run `tools/stream.sh up`/`build` or any bench with `--viewer external`. Page tests: `timeout 120 bash streaming/bench.sh --selftest` in the distro (wsl: tp-stream; sync files the way earlier jobs did, see the opt2-3 report's obstacle line).
- Stay inside `allow:`.
