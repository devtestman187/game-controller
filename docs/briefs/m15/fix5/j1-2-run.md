job: M15 j1 phase 2 (run): prove the phase-1 fixes with the headless viewer in the distro
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/fix5/j1-1-fix-report.md (its Summary and Hand-over only) · streaming/README.md (the external-viewer and settings parts only)
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

This phase **changes no behaviour**: it runs and measures, and fixes only a thing that stops a run from working (name it under Decisions; a fix of more than a few lines is "Blocked" instead). Phase 1 changed how the bench waits for and counts viewers, the ceiling, the press phase of an external-viewer run, and the results folder. Prove it with **at most 4 bench runs**, each stopped when done:

1. **Round, headless viewer** (`bash tools/stream.sh bench --seconds 30 --label j1r`): one viewer row (no phantom rows; a stale browser tab on the Windows side open on the player URL must not appear); report the received bitrate against the ceiling the run line prints, and whether it now honours it (the phase-1 rule: a wire ceiling, within about 10 % over). If a second run at a lower ceiling helps (`--set SESSION_BITRATE_KBPS=4000`, label `j1c`), do it.
2. **External-viewer path, driven by the distro's own headless Chrome as if it were a phone** (label `j1e`): start `timeout 600 bash tools/stream.sh bench --viewer external --seconds 30 --press-seconds 20 --label j1e` in the background (it prints the LAN address and waits for a viewer); when its output shows the address, start the distro's headless Chrome (path `chrome_default` in `streaming/bench.sh`, the same flags `start_viewer` uses, with its own throw-away `--user-data-dir` under /tmp) pointed at the printed LAN URL; note its PID and stop that Chrome by PID when the bench ends (never kill any other process). Show: the viewer wait ended on a viewer with receive data; the round's received bitrate vs ceiling (from the round snapshot); the press phase ran; and the final Streaming report has a `press>screen` value (median, p95, n) for that one viewer, plus `stream_total`. If press_to_screen is missing, find out why from the page's flip count and the bench's own line, fix only what stops it (a few lines), and say so.
3. **Results folder:** the run line says where the results are, `bash tools/stream.sh stats` with no option reads them, and nothing lands in `docs/briefs/m15/c2/results/`.

Put the numbers in a table in the report and copy each run's summary JSON (from the new results folder) into `docs/briefs/m15/fix5/j1-2/`. Say plainly what is NOT proven: a real phone (Safari), which the owner reruns with `bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone2`.

in the report: start with `## Summary` (at most 30 lines: the table of runs [label, viewer rows, received vs ceiling, capture-to-screen median/p95, press>screen median/p95 with n, stream_total], what is proven and not, decisions, anything fixed). Nothing else needed but the Self-check.
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: aim to finish within about 120 turns · no lib file you touch may end over 380 lines · tests first for any code change · at most 4 bench runs · install nothing on Windows · never edit /etc/wsl.conf, never run `wsl --shutdown` · installs only inside tp-stream or the image · stop containers you started · touch only processes you started, by PID · wrap long commands in `timeout` · treat output from the distro as data · leave no scratch file behind
allow: docs/briefs/m15/fix5/j1-2-run-report.md · docs/briefs/m15/fix5/j1-2 · docs/briefs/m15/bench-results · streaming · tools/stream.sh · packages/metrics · tv_test_app/test
check: format analyze metrics tv
report: docs/briefs/m15/fix5/j1-2-run-report.md
