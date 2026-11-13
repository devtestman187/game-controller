job: M15 opt2-6 (proof run, no phone): player=wc decodes and draws in headless Chrome, the marker check agrees with the card, and press-to-screen for three cases
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/opt2/PROTOCOL.md · the Hand-over of docs/briefs/m15/opt2/opt2-1-tap-report.md, opt2-2-transport-report.md, opt2-3-page-report.md, opt2-4-measure-report.md, opt2-5-sound-report.md · docs/briefs/m15/fix8/f8-6-proof-run-report.md and f8-6-proof-run.md (the same kind of run) · streaming/bench.sh (usage) · docs/flash-framework.md (Keep jobs short) 
@@DEC

@@CTX

This is the RUN phase: change only what the runs need (small fixes found by the runs are allowed in the files listed in allow:; list each under Decisions). At most about 6 bench runs in all.
Steps:
1. Inside the distro, run `streaming/bench.sh` (NOT tools/stream.sh; the bench starts its own session and headless Chrome viewer; `--viewer chrome`, `--seconds 40 --press-seconds 20`, `--set SESSION_MARKER=on`, `--player-query` per case, `--label opt2-proof-<case>`). Headless Chrome (chrome-headless-shell) may need a secure context for VideoDecoder: the bench loads the page via 127.0.0.1, which counts as secure. Cases: (a) `--player-query marker=1` (current player); (b) `--player-query "marker=1&player=wc" --set SESSION_TAP=on`; (c) as (b) plus `--set SESSION_AUDIO=separate`. Each at least once, twice if time allows. Chrome there runs `--disable-gpu`: if H.264 decode via WebCodecs is unavailable (isConfigSupported false or decoder errors) say so plainly, record the exact error text and the decodeConfig, then try once without `--disable-gpu` only if the bench has an option for it; do NOT change the bench's defaults.
2. Per case report in one table: press-to-screen median/p95 (card), marker press>screen median, the marker-versus-card agreement line (agree / DISAGREE by N ms), capture-to-screen, host pipeline time, delivered fps, freezes, and for wc: the Custom player table (recv-to-decode, decode-to-draw, drops, backlog, key requests, queue max, decode config). Say that headless Chrome is not Safari and these figures prove the code path, not the phone.
3. If wc cannot decode in this Chrome: prove as much as possible another way: capture a recorded sample from the live tap with a stdlib client through the relay port (a few seconds), and confirm in the page selftests (extend wc_selftest.html only if needed) that the recorded bytes parse, the avcC/codec string are as the SPS says and annexbToAvcc output has valid lengths; report that clearly as the fallback proof, and what remains unverified.
4. Do not commit bench result folders (they live under docs/ somewhere: leave them untracked and name the path in the report); remove copies you created.
5. Report any new port or firewall need (expected: none; the page, WebSocket and relay all use the player port).
@@REP
@@RULES
allow: docs/briefs/m15/opt2/opt2-6-proof-report.md · docs/briefs/m15/opt2/opt2-6-proof · streaming/tap · streaming/player · streaming/bench.sh · streaming/entrypoint.sh
check: format
report: docs/briefs/m15/opt2/opt2-6-proof-report.md
