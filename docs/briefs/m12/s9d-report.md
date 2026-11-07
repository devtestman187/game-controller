# s9d report — the three smoke and emulator script bugs from Nov 7 (G4)

**Done** for the three fixes. Two scripts and `docs/dev-tools.md` changed; no other file.
`bash -n` passes on both scripts and `tools/check.sh format` passes, but **the `--self-test` was not
run**: this sandbox asks for approval before running any script except `tools/check.sh` and
`tools/review.sh` (`bash tools/smoke.sh --self-test`, `bash -c …`, `awk`, `command -v` and even
`dart --version` are all refused), so the run below is missing. Q3 has the one command to run.

## 1. `smoke.sh`: a log that ends in the flutter tool's crash report is silent

- `tool_crash_line='A crash report has been written to'` and `crash_tail_lines=3` — the marker and
  how many of the log's last non-blank lines are looked at for it (top of the script, with the
  other constants).
- `tv_is_live` — first takes the log's last 3 non-blank lines (`tr -d '\r'`, drop blank lines,
  `tail`), and returns 1 (not live) when one holds the crash report; then the old rule (a `[host]`
  line after the last `Listening` one).
- `self_test` — new; writes the two log shapes below into the run's folder, calls `tv_is_live` on
  each, prints one `PASS self-test`/`FAIL self-test` line per case and returns 0 when both are read
  right, 1 when one isn't; removes its two files and the (then empty) folder.
- `main` — `--self-test` sets `wants_self_test`, and after `tv_is_live`/`self_test` are defined the
  script runs the self-test and `exit $?`. Nothing else of a run happens (no app started).
- The header gained the option and two lines on the rule; the `--help` range moved from `2,22p` to
  `2,25p` so the printed help still ends at the exit-code line.

`tv_is_live` is the one place the script decides "live": `tv_line` (every `sim_step`'s TV proof) and
the `--emulator` `phone-hello` step both go through it, so with a crashed log they now keep
`sim` / `SKIP` instead of waiting for a line that can't come (the Nov 7 run waited 48 s for its
`hello`).

**Why last 3 lines and not the last one.** Flutter prints the report path inside a short block
(`Oops; flutter has exited unexpectedly…`, the report line, sometimes a trailing blank line), so
"the last few lines" is safer than "the very last"; a live log can't hold the marker in its tail,
since the tool that writes lines is the thing that crashed (a restart truncates the log).

## 2. `emulator.sh`: `find_node` prefers an exact label, and a Button among equals

- `find_node` (label branch) — scores every node: label equal to the wanted text is 4 for a
  `Button`, 3 for any other class; a label that only *contains* it is 2 for a `Button`, 1 for any
  other class; the first node with the highest score wins. Nothing matching gives the empty line it
  gave before, so `wait_for` and `tap-name` keep their messages.
- The EditText branch is unchanged (`EditText` as $1 still takes the $2-th edit box).

On the Nov 7 screen (`emulator.sh ui` would list them as `Connect  Button  x  y` and
`Connect to a TV  View  x  y`) the old rule took the first label from the start
(`index($1, want) == 1`), i.e. the title; the new rule scores the button 4 and the title 3 and taps
the button.

**Callers that relied on "contains" (the old prefix rule):** `connect`'s
`wait_for "Enter the code"` — the screen's text is `Enter the code shown on <host>`
(`controller_app/lib/src/ui/connect_panels.dart:251`), so only the contains tier finds it.
`launch`'s `wait_for "Connect to a TV"` is exact (`controller_app/lib/src/ui/connect_screen.dart:30`),
and the documented `tap-name "Sticks"` is an exact Button label (`docs/dev-tools.md`, the `ui`
sample). The brief's `tap-name "Connect"` is the caller that must *not* match by containment alone.

## 3. `emulator.sh connect`: check the address reached the box, then press Connect

- `elements` — new; the `uiautomator dump` + `sed 's/></>\n</g'` lines that `nodes` used to hold,
  shared now so the box can be read back from the same dump `ui` prints.
- `nodes` — unchanged output, now reading from `elements`.
- `edit_text` — new; the `text` attribute of the $1-th `EditText` in that dump: what the box holds
  now, empty while nothing reached it.
- `type_address` — new; each try taps the first edit box, waits 1 s, types the address, waits 1 s,
  and reads the box back; the address appearing in the box ends it with 0, up to `address_tries=3`
  tries a second apart, then 1.
- `connect` — checks the box exists (same message as before), calls `type_address` and stops with a
  message naming the address and the 3 tries when it never lands; taps the `Connect` button by its
  exact label (no longer Enter); and when the code screen doesn't show within 20 s it now stops with
  "the code screen didn't show after Connect: is the TV app on at <address>?" (before, it went on and
  failed 30 s later with "not connected", which hid the cause). Everything after the code prompt,
  the badge loop and every exit code are unchanged.

## Changed functions, one line each

- `smoke.sh tv_is_live` — returns 1 when the log's last 3 non-blank lines hold the flutter tool's
  crash report, before the old `[host]`-after-`Listening` rule.
- `smoke.sh self_test` (new) — writes a live and a crashed log, checks `tv_is_live` on both, prints
  one line per case, 0/1.
- `smoke.sh` main — `--self-test` parsed; runs `self_test` and exits after the functions exist;
  header/help updated (`2,25p`).
- `emulator.sh elements` (new) — the screen's nodes, one per line from `uiautomator dump`.
- `emulator.sh nodes` — reads from `elements`; same output.
- `emulator.sh edit_text` (new) — the $1-th edit box's `text` attribute.
- `emulator.sh find_node` — exact label first (Button among equals), contains only when nothing
  matches exactly.
- `emulator.sh type_address` (new) — tap, type, read back; 3 tries, a second apart.
- `emulator.sh connect` — verify the address in the box, press the exact `Connect` button, clear
  message when the code screen doesn't show.
- `emulator.sh` constants — `address_tries=3`; header line for `tap-name`.

## What I ran

- `bash -n tools/smoke.sh` — PASS (no output).
- `bash -n tools/emulator.sh` — PASS (no output).
- `tools/check.sh format` — `PASS  format (2s)`, `All checks passed (2s)`.
- `tools/review.sh` — `review: 0 fail, 0 note` (it reads `.dart` files only; this diff has none).
- `tools/smoke.sh --self-test` — **not run**: "This command requires approval" (every script but
  `tools/check.sh`/`tools/review.sh` is refused here; see the top and Q3).
- `--help` for both scripts — not run for the same reason; the `sed` ranges were checked by hand
  (`smoke.sh` 2–25 now ends on the exit-code line; `emulator.sh`'s `2,24p` header is the same length
  as before).

## Values (for the self-test and the label rule)

- `crash_tail_lines = 3`; `address_tries = 3`; each address try = tap + 1 s + type + 1 s = 2 s, so
  at most 6 s before the clear failure.
- Self-test log A (expected live): `[host] Listening on port 45780 (pairing code 5416)` and
  `[host] Smoke controller (sim 0.11.0, supports metrics) says hello from 127.0.0.1`.
- Self-test log B (expected silent): log A's two lines plus
  `A crash report has been written to C:\Users\...\flutter_01.log`.
- Expected output of `tools/smoke.sh --self-test`, exit 0:
  `PASS self-test: a log ending in the flutter tool's crash report is silent` and
  `PASS self-test: a log ending in an app line is live`. With the old `tv_is_live`, log B counted as
  live (its `[host]` line follows `Listening`), so the first line would be `FAIL self-test: a log
  ending in the flutter tool's crash report was read as live` and the exit code 1.
- `find_node` scores: exact Button 4, exact other 3, contains Button 2, contains other 1. For the
  Nov 7 screen that is `Connect|Button` 4 against `Connect to a TV|View` 3.

## Questions and suggestions

1. **Q1 — Reading the box back.** `edit_text` reads the edit node's `text` attribute, which is where
   Android's accessibility tree holds a field's value (the `ui` label column falls back to it when
   there is no `content-desc`). I could not check a real dump from here (no emulator). If Flutter puts
   the typed address in `content-desc` instead, `type_address` will fail all 3 tries and `connect`
   will stop with its clear message; the fix is one line (read the label `nodes` prints instead). A
   first `tools/emulator.sh connect …` on this PC will show which it is.
2. **Q2 — The keyboard over the Connect button.** The brief asks for the button rather than Enter, so
   `connect` now taps it. On the 2400×1080 panel the software keyboard covers the bottom of the
   screen, and the manual-entry row is at the bottom of the left column: if the tap lands on the
   keyboard instead, the fix is to hide the keyboard first (`keyevent 111`/`4`) before the tap. Not
   verified here.
3. **Q3 — The self-test needs a run.** The sandbox refused every script but `tools/check.sh` and
   `tools/review.sh`, so `tools/smoke.sh --self-test` was not executed. It needs Flutter on the PATH
   (the script checks for `dart` and `flutter` before anything else, even for the self-test); one run
   takes a second and starts nothing.
4. **Note — a retry appends.** If an attempt leaves part of the address in the box (not what Nov 7
   showed; the box stayed empty), typing again appends to it, as the brief's "tap and type again"
   says. Clearing first would need a documented key sequence; say if you want one.

## Files changed

- `tools/smoke.sh` — the crash-report rule in `tv_is_live`, its constants, `self_test` and the
  `--self-test` option, header and help range.
- `tools/emulator.sh` — `elements`, `edit_text`, `type_address`, `find_node`'s exact/Button/contains
  ranking, `connect`'s box check and Connect button, `address_tries`, header line.
- `docs/dev-tools.md` — `tap-name`'s label rule (command list and a bullet with the connect
  behaviour), the smoke log-live rule with the crash report, and `--self-test` in the smoke commands
  and its section.

## Commit message

tools: read a crashed TV log as silent, tap exact labels (s9d)

smoke.sh took a TV log ending in the flutter tool's crash report for a
live one and waited for a hello a dead log never writes; its last few
lines now count as silent, so those steps keep the controller's proof,
and --self-test checks both log shapes.
emulator.sh's find_node takes a label equal to the text first, a Button
among equals, and one containing it only when nothing matches exactly,
so "Connect" is the button, not "Connect to a TV".
connect reads the address box back, taps and types up to 3 times, presses Connect and says so when the code screen never shows.

## Status row

| 9 Docs and device tests | … **s9d done** (`s9d.md`): `smoke.sh` treats a TV log ending in the flutter tool's crash report as silent (with `--self-test`, not yet run here); `emulator.sh` `find_node` prefers an exact label and a Button, and `connect` checks the address box (3 tries) and presses Connect, failing clearly when the code screen doesn't show. Open: a real `smoke.sh --emulator` run on this PC, s8c, the PRD M12 acceptance tests in the checklist |

## Delete

- none
