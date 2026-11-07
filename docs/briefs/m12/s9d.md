job: m12 s9d G4 — three smoke and emulator script bugs from the Nov 7 runs
stop: after G4.
read: tools/smoke.sh · tools/emulator.sh · tools/tv-dev.sh · docs/dev-tools.md (their sections) · STATUS.md "Smoke check" row

what happened (Nov 7, 12:08–12:20):
1 `smoke.sh` decided the TV app's log was live because the flutter tool's crash report ("A crash report has been written to …", the temp-folder `_createDevFS` crash this PC's sandbox causes) was written to it after the start, then waited 48 s for a `hello` line that a dead log never writes, and failed `hello` — while `sim.log` shows the hello, the pairing and player 1. A log whose last lines are the tool's crash report is silent: treat it so (SKIP the TV-log proofs, keep the sim's), wherever the script decides "live".
2 `emulator.sh tap-name "Connect"` tapped the screen title "Connect to a TV" instead of the Connect button: it takes the first label that contains the text. Prefer an exact label match, and among several, a Button; fall back to "contains" only when nothing matches exactly. Say which callers relied on "contains".
3 `emulator.sh connect` printed "Connecting…" but the address never reached the box (the app had just opened). After typing, read the box back from `ui`; if it doesn't show the address, tap and type again (up to 3 tries, a second apart), then press the Connect button (by the exact match of 2), and fail with a clear message if the code prompt never shows.

do: the three fixes, nothing else. Keep each script's output lines and exit codes; update dev-tools.md if a behaviour it describes changes.
tests: `bash -n` on each script; for 1, a small self-test: feed the "is the log live" function a log ending in the crash report and one ending in a normal line (a function you can call with `--self-test`, or a test under tools/ if one exists; say which).
in the report: the changed functions (one line each), what you ran.
rules: no other script changes · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s9d-report.md · tools/smoke.sh · tools/emulator.sh · docs/dev-tools.md
check: format
report: docs/briefs/m12/s9d-report.md
