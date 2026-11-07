# m12 tools job 2b G4 — `smoke.sh` proves each step from the controller's side; the sim reconnects with a saved pairing

All four items are done. The Dart is checked (format, analyze, `connection`'s 176 tests); the bash is **read, not
run**: `bash -n tools/smoke.sh` and `tools/smoke.sh --help` were both refused in this job's sandbox ("This command
requires approval"), the same refusal t2 met. So the first real `tools/smoke.sh` run is Claude's.

## Files changed

- `tools/smoke.sh` (271 → 367 lines) — item 1: every step is now proved by a line of the simulated controller's
  own output, with the TV app's matching line as a second proof when its log is live, and the PASS line names the
  proofs it used (`sim`, `sim+tv`, `tv`, `tool`). Item 2: a second, short run connects with the pairing the first
  one saved (`$out/sim-token.json`), proved by `CONNECTED` and no `Sending pairing code`. Item 3: `--emulator`
  installs the phone app when the device hasn't got it. New steps `player`, `ping`, `reconnect`, `phone-install`;
  `phone-hello` is skipped instead of failing when the TV app's log is silent.
- `packages/connection/bin/sim_controller.dart` (197 → 266 lines) — `--token-file <path>`: reads a saved pairing
  before connecting and uses it instead of the code; saves one when the host issues a token. Every existing option,
  output line and behaviour is unchanged.
- `docs/dev-tools.md` (400 → 403 lines) — the smoke section: what each proof is, the silent TV log, the saved
  pairing, the `--emulator` install; the sample output is left as it was, with the note the brief asked for.
- `docs/briefs/m12/t2b-g4-report.md` — this report.

## The steps now, and what proves each

| Step | The simulated controller's own line (`sim`) | The TV app's line (`tv`), when its log is live |
| --- | --- | --- |
| `hello` | `Welcome from …` — the host's answer to the hello (`client_messages.dart:107-110`) | `Smoke controller (sim 0.11.0, supports metrics, rating) says hello from 127.0.0.1` (`host_connection.dart:277-279`) |
| `paired` | `Paired with …` (`client_messages.dart:132`) | `Smoke controller connected (pairing code), player 1` (`host_connection.dart:347`) |
| `player` | `The TV made this phone player 1` (`client_messages.dart:53`) | the same connected line |
| `ping` | `ping 1 ms (last 30 s: …)` (`sim_controller.dart:169`) | — |
| `input` | `Summary: ran 0 min 12 s, 735 input states sent, 0 drops, …` (`sim_controller.dart:187`) | — |
| `metrics` | `metrics batch 1 (1 waiting)` (`sim_controller.dart:153`) | — |
| `disconnect` | `Disconnecting` (`controller_client.dart:243`) | `Smoke controller disconnected` (`host_connection.dart:119`) |
| `reconnect` | `CONNECTED` (the status line, `sim_controller.dart:114`), and no `Sending pairing code` | `Smoke controller connected (saved pairing), player 1` (`host_connection.dart:303-304`) |

- **How a step decides.** `sim_step()` waits for the sim's line first (that alone is a pass), then calls
  `tv_line()`. `tv_line()` returns 1 without waiting when the TV app's log isn't live; when it is live it waits
  its usual `wait_secs` for the matching line after `$mark` (the line count taken before the client started), and a
  step that doesn't get it **fails**, printing the log's last lines that name the controller (`FAIL <step>`, the
  usual TV-log tail and `Smoke failed`). The reconnect step does the same by hand, because it also has to check
  that the code wasn't sent.
- **"Live"** is `tv_is_live()`: the log has a `[host]` line after its last `Listening on port …` line
  (`host_server.dart:137`). In Claude's Nov 6 run the log held only that line, so it isn't live there and every
  step is `sim`; on the owner's PC the app's lines keep coming, so the steps are `sim+tv`.
- **`ping`, `input`, `metrics` are `sim` only.** The host doesn't log a pong, and it logs input only in its
  `Latency … input delay ~ avg … (N states)` line, which comes every 30 s (`host_server.dart:31`, found in t2), so
  a 12-second run can't reach it; nothing covers a metrics batch. There is no host line to match, so these three
  steps would fail wrongly if they demanded one.
- **Order.** The second run starts only after the first has exited (`wait "$sim_pid"`): the host keeps one
  connection per controller and both runs use the same controller id, so overlapping them would let one replace
  the other.

## The token file: `id`, `host`, `token` — three values, not two

This is the one place the diff goes past the brief's wording ("holds only the id and token"), and it is forced by
the client library the brief forbids changing:

- The client's saved tokens are a map **keyed by the host's id**: `ControllerClient(tokens: …)`
  (`controller_client.dart:26`), `tokenFor(String hostId)` (`controller_client.dart:376`, used by
  `client_messages.dart:113` as `tokenFor(welcome.hostId)`). A map keyed by anything else finds nothing, and the
  client is created before the host id is known (it only arrives in the welcome), so the id has to be in the file.
- The **controller id** is what the host looks the pairing up by (`host_pairings.dart:87 known(controllerId)`,
  `host_connection.dart:302-309`), and the sim otherwise makes a new one per run
  (`sim_controller.dart:72`, unchanged for runs without a file).
- So the file is `{"id": …, "host": …, "token": …}` (`_readTokenFile`, `sim_controller.dart:230`;
  `_writeTokenFile`, `:259`), nothing else in it, written only where `--token-file` says, only after a pairing
  delivers a token (`onTokenChanged`, `:94`; a null token — the host forgetting the phone — leaves the file
  alone), and read only when the option is given.

Reading and writing:

- A missing file means a first run: the sim pairs with `--code` as before. With a file, `code:` is `null`
  (`sim_controller.dart:182`) and the client sends `PairRequestMessage(token: …)` after the welcome, logging
  `Using the saved pairing` (`client_messages.dart:119`) — never `Sending pairing code`.
- A file that isn't JSON, or is missing `id`/`host`/`token`, exits 64 with one line (`… is not a saved pairing…`),
  like the other bad-option paths; a file that can't be written prints one line to stderr and the run goes on
  (the pairing itself worked).
- One new output line: `  · Saved the pairing to <path>` (the sim's own `  · ` style). Nothing else in the output
  changed — the metrics, ping, player and summary lines keep their exact wording, which is now what the smoke
  reads.
- A token the host no longer knows logs `saved pairing not recognized, waiting for the code` on the TV side
  (`host_connection.dart:306`); the sim then waits for a code as it always did (stdin), and with `--seconds` it
  exits 1 after that time. The smoke's `reconnect` step fails after its wait, with the sim's log printed.

## `--emulator` (item 3)

- **Is the app there?** `adb shell pm path com.thumbparty.app` printing `package:…` means yes. When it prints
  nothing, `tools/emulator.sh install` runs as the step `phone-install` (the line only appears when it really
  installs: a device that already has the app prints no such step).
- **adb is found the way `tools/emulator.sh` finds it** (`ANDROID_HOME`/`ANDROID_SDK_ROOT`, else the usual SDK
  folder per OS, else the PATH) in `find_adb()`, because `tools/emulator.sh` has no "is it installed" command and
  this job may not change it. If none is found the script exits 2 before touching the phone.
- **The phone's proofs.** `phone-paired` is `tools/emulator.sh connect` exiting 0 (it waits until the phone shows
  its player badge) — `tool`. `phone-shot` is the screenshot (`tool`). `phone-hello` is the TV app's
  `(android …) says hello from` line — `tv` — and when that log is silent there is nothing to read, so the step is
  **skipped**: `SKIP  phone-hello   (the TV app's log is silent, so there is no hello line to read)`. That is the
  one new output word; a skip is not a failure, and it keeps the sandbox run (`--emulator` with a silent log) from
  reporting a failure it can't prove or disprove.

## `docs/dev-tools.md` (item 4)

The smoke section now says: each step's proof and the `sim`/`sim+tv`/`tv`/`tool` labels; the TV app's own lines
per step; that the log may be silent in a sandbox (and why: `flutter run`'s tool can crash after start, so only
`[host] Listening on port …` remains) and what "live" means; the second connect with `sim-token.json` and its
`CONNECTED` without the code; `--emulator`'s install, the phone's proofs and the skipped `phone-hello`; the failure
line now names the sim's log too; and "What it doesn't check" no longer claims saved pairings are impossible — it
says a saved pairing outliving the TV app isn't covered. The sample output is untouched, with
"(sample; replaced after the first real run)" in front of it. The table row now says "the clients' and the app's
own logs".

## Checks I ran

| Check | Result |
| --- | --- |
| `tools/check.sh format analyze connection`, twice | run 1: `PASS format (1s)`, `PASS analyze (8s)`, `PASS connection (176 tests, 16s)`, `All checks passed (25s)`; run 2, after the last change: `format (2s)`, `analyze (7s)`, `connection (176 tests, 12s)`, `All checks passed (21s)` |
| `tools/review.sh` | `review: 0 fail, 2 note` — both notes are in files this job didn't touch (`controller_app/lib/src/providers/device.dart:24`, `controller_app/lib/src/providers/metrics.dart:32`: Claude's own uncommitted app work carried into the job's worktree) |
| `bash -n tools/smoke.sh` | **not run: refused** ("This command requires approval"), as in t2; `tools/smoke.sh --help` was refused too, so the script was read, not parsed |

Computed values for the review:

- `printf 'PASS  %-13s (%s, %ss)'` pads the step names like this: `tv-app` 7 spaces, `hello` 8, `paired` 7,
  `player` 7, `ping` 9, `input` 8, `metrics` 6, `disconnect` 3, `reconnect` 4, `phone-install` 0,
  `phone-paired` 1, `phone-hello` 2, `phone-shot` 3, `phone-reset` 2 (13 minus the name's length).
- A run's shortest path: run 1 = `sim_seconds` 12 s, run 2 = `reconnect_seconds` 5 s, plus the compile of the first
  `dart run` and the disconnects; the summary steps wait `sim_wait` = 12 + 20 = 32 s, the others 20 s.
- The token file's three keys and their checks: `id` and `host` and `token`, each a non-empty `String`
  (`sim_controller.dart:242`); anything else in the JSON is ignored, and the file holds nothing else.

## Questions

1. **The token file has a third value (`host`).** The client keys tokens by the host's id
   (`controller_client.dart:376`), and the host id only arrives in the welcome, so a file with the controller id
   and the token alone can't be used without changing the client. Is `{"id", "host", "token"}` the shape you want,
   or should the sim learn the host id another way (a first, code-less connect just to read the welcome, then a
   second connection with the token)? That would keep two values but makes two connections.
2. **A step fails when the TV log is live and its line doesn't come at all**, not only when an error line names the
   controller (my reading of "contradicts it": if the log is live, the host would have written that line). If you
   meant only error lines, it is a different grep in `tv_line`.
3. **`SKIP` is a new output word,** used only for `phone-hello` when the TV log is silent. If you'd rather keep
   PASS/FAIL only, the alternatives are to merge that check into `phone-paired` or to drop it.
4. **`find_adb()` copies `tools/emulator.sh`'s SDK discovery** (about 13 lines), since `emulator.sh` has no
   "is it installed" command. An `emulator.sh installed` command would let the smoke drop it (suggestion below).
5. **The sample output in `dev-tools.md` no longer matches a run:** it has no `(proof, s)` field and lists fewer
   steps (`player`, `ping`, `reconnect` are missing). I left it exactly as it was, as you asked; it should be
   replaced on the first real run.
6. **`ping`, `input` and `metrics` can never be `sim+tv`.** If you want the TV side of the input proved too, the
   only host line is the 30-second `Latency … input delay` one, which needs a longer first run (suggestion below).
7. **`phone-paired` is `tool` only,** even when the TV log is live and has the phone's `connected (pairing code)`
   line; `phone-hello` covers the TV side. Say if you want the two merged.

## Suggestions (not acted on)

- **`tools/emulator.sh installed`**: exit 0 when `pm path com.thumbparty.app` finds the app, printing where it is.
  Then the smoke's `find_adb`/`phone_has_app` pair becomes one call, and the package name lives in one script.
- **A `--seconds` passthrough on `smoke.sh`**: with 35 s the host's `Latency … input delay ~ avg … (N states)`
  line arrives, and `input` would get a TV proof of its own (nothing else in the host's log covers input).
- **The sample output** should also show the new field and steps once a real run exists: `PASS hello (sim+tv, 2s)`
  and the `reconnect` line are the two things to copy from it.
- `docs/project-notes.md:83` (the `sim_controller` recipe) could mention `--token-file`; outside this job's files.

## Commit message

```
tools: smoke.sh proves steps from the sim; saved pairing reconnects

smoke.sh proves hello, paired, player, ping, input (0 drops), metrics
and disconnect from the simulated controller's own output, and checks
the TV app's matching line too when its log is live: PASS says sim or
sim+tv. The sim gains --token-file (controller id, host id, token), so
a second, short run connects with the saved pairing and must reach
CONNECTED without the code. --emulator installs the phone app when it
is missing; phone-hello is skipped while the TV app's log is silent.
```

## Status row

| Tools 2b `smoke.sh` proofs | **Done** (G4, Nov 6): `tools/smoke.sh` proves hello, paired, player, ping, input (0 drops), metrics, disconnect and the saved-pairing reconnect from the simulated controller's own output, checks the TV app's matching line when its log is live (`PASS … (sim, 2s)` / `(sim+tv, 2s)`), and `--emulator` installs the phone app when the device hasn't got it; `sim_controller --token-file` saves the pairing (`id`, `host`, `token`) and a later run connects with it without the code. Open: neither the smoke nor the sim's saved-pairing run was tried here (no apps; the sandbox refused even `bash -n`), so the first real run is Claude's; Q1 (the token file needs the host id too) in [t2b-g4-report.md](t2b-g4-report.md). |

## Delete

- none
