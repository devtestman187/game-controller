job: m12 tools job 2b G4 — smoke.sh proves each step from the controller's side; the sim reconnects with a saved pairing
stop: after G4. You can't run apps here: Claude runs the smoke check.
read: tools/smoke.sh · docs/briefs/m12/t2-g4-report.md (your questions) · packages/connection/bin/sim_controller.dart · tools/emulator.sh · the run below

decisions (answers to t2-g4-report Q1–6): Q1 bash -n passed (Claude ran it) · Q2 yes: add it now (item 2) · Q3 the literal refusal is right · Q4 --keep keeps both, fine · Q5 replace the sample with a real run once Claude has one (item 4) · Q6 yes: install when the app isn't there (item 3).

what happened: Claude's first run (Nov 6, 19:15) failed at "hello", but the connection worked. In Claude's sandbox `flutter run`'s tool crashes after start (it can't create a temp folder for hot reload); the app keeps running, but from then on its log lines no longer reach tv.log, which only had `[host] Listening on port 45780 (pairing code 4087)`. The sim's own output (sim.log) had everything:
  Connected to 127.0.0.1:45780, saying hello / Welcome from DESKTOP-… (TV app 0.11.0, supports metrics, rating) / Sending pairing code / PAIRING / Paired with DESKTOP-… / CONNECTED / The TV made this phone player 1 / ping 1 ms … / metrics batch 1 (1 waiting) / Summary: … 735 input states sent, 0 drops … / Disconnecting / IDLE
On the owner's PC the tool doesn't crash, so tv.log stays live there.

do:
1 smoke.sh: prove each step from the sim's output (those lines are the host's replies: welcome, paired, player number, pings answered, metrics batch, inputs sent with 0 drops, disconnect). Also check the TV log for the matching host line when the TV log is live (it has a host line newer than the "Listening" line), and say per step which proof was used: `PASS hello (sim+tv, 2s)` or `PASS hello (sim, 2s)`. A step passes on the sim's proof alone; it fails if the TV log is live and contradicts it (say an error line for that player).
2 sim_controller.dart: `--token-file <path>`: after pairing, save the controller id and the host's token there; when the file exists, connect with them instead of the code. smoke.sh's second connect uses it and must reach CONNECTED without "Sending pairing code". Keep every existing option and output line as it is.
3 `--emulator`: install the app with `tools/emulator.sh install` when `adb shell pm path com.thumbparty.app` finds nothing. The phone's proof is `tools/emulator.sh connect` returning 0 (it waits until the phone shows connected) plus the screenshot; the TV log's hello for the phone when the log is live.
4 docs/dev-tools.md: the smoke section says what each proof is and that the TV log may be silent in a sandbox; leave the sample output as it is with a note "(sample; replaced after the first real run)".

rules: bash for smoke.sh; Dart for the sim, following packages/connection's style · the sim's token file holds only the id and token, is written only where `--token-file` says, and smoke.sh puts it in its run folder and deletes it at the end · no change to the host or client libraries · `tools/review.sh`: no FAIL on your lines.
allow: tools/smoke.sh · packages/connection/bin/sim_controller.dart · docs/dev-tools.md
check: format analyze connection
report: docs/briefs/m12/t2b-g4-report.md
