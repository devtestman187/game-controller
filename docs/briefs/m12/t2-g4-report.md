# m12 tools job 2 G4 — `tools/smoke.sh` and `tools/commit-job.sh`

Two new developer tools and their documentation: a smoke check that pairs real clients with the development
TV app over the real network stack, and a one-command commit for a finished job. G4 done. **Neither script
could be run here** (no apps, no commits, and this job's sandbox refuses even `bash -n` — see "Checks"), so the
report also says what to run first.

## Files changed

- `tools/smoke.sh` (new, 271 lines) — `[--emulator] [--keep]`. Starts the development TV app through
  `tools/tv-dev.sh` (or uses the copy already running), reads its port and pairing code and its log file from
  `tv-dev.sh status`, runs the simulated controller against it, and proves each step from a log line. Six steps
  as it stands (`tv-app`, `hello`, `paired`, `input`, `metrics`, `disconnect`), six more with `--emulator`
  (`emulator`, `phone-app`, `phone-paired`, `phone-hello`, `phone-shot`, `phone-reset`).
- `tools/commit-job.sh` (new, 194 lines) — `<brief> [--message-file <file>] [--push] [--dry-run]`. Stages a
  job's `allow:` paths, its brief, its report and its `<brief>-{review,review-report,plan}.md` files, never a
  `generated_*` file, and commits the report's draft message.
- `docs/dev-tools.md` (52 lines added, 1 changed) — one row per script in the scripts table, `smoke.sh` in the
  sentence that says which scripts need Windows, a `## tools/commit-job.sh` section after `tools/review.sh`, and
  a `### A quick check with real clients: tools/smoke.sh` section after the emulator section.
- `docs/briefs/m12/t2-g4-report.md` — this report.

Nothing else changed: `tools/tv-dev.sh`, `tools/emulator.sh`, `packages/connection/bin/sim_controller.dart` and
`tools/flash.sh` are untouched (one of them would need a small change for the saved-pairing step, below).

## The host's own words, as the brief asks (found with `git grep` in `packages/connection/lib`)

| What | The line, in the code |
| --- | --- |
| the hello | `packages/connection/lib/src/host_connection.dart:277-279` — `'${hello.name} (${hello.platform} ${hello.appVersion}$caps) says hello from ${remoteAddress ?? localPeerLabel}'` |
| connected | `host_connection.dart:347` — `'${hello.name} connected ($how), player $player'`, where `$how` is `'pairing code'` (`:313`) or `'saved pairing'` (`:304`) |
| the disconnect | `host_connection.dart:119` — `'$who disconnected${code == null ? '' : ' (code $code)'}'` |

As the TV app prints them in debug (`kDebugMode`, `packages/party_host/lib/src/providers.dart:45-48`, through
`flutter run` into `tv.log`), with the sim started as `smoke.sh` starts it (times illustrative):

```
12:04:31.412 [host] Smoke controller (sim 0.11.0, supports metrics, rating) says hello from 127.0.0.1
12:04:31.418 [host] Smoke controller connected (pairing code), player 1
12:04:43.907 [host] Smoke controller disconnected (code 1000)
```

The simulated controller's own two lines (`packages/connection/bin/sim_controller.dart`): `:130`
`'metrics batch $batch (${client.metricsWaiting} waiting)'` and `:162-165`
`'Summary: ran ${…} min ${…} s, ${client.inputsSent} input states sent, …'`.

## How `smoke.sh` decides, and why

- **Which copy of the TV app.** `tv-dev.sh status` first: exit 0 with a port, code and log means a development
  copy is running, so it is used and `started_tv` stays 0 (it is never stopped). Otherwise `tv-dev.sh start`
  runs, its output goes to `$out/tv-start.log` — **never through a pipe**, because `dev-tools.md` records that
  piping `start` never ends (the app's Windows processes hold the pipe open).
- **The log file.** The path is the one `tv-dev.sh status` prints (`Log:     C:\…\tv.log`), turned into a bash
  path with `cygpath -u`, so the script doesn't keep a second copy of `tv-dev.sh`'s state folder name.
- **Waiting for a line.** Each step records the log's line count and then polls
  `tail -n +<count+1> log | grep -qE <pattern>` every 0.5 s, so a line from an earlier session can't make a step
  pass. Timeout is `SMOKE_WAIT_SECS` (default 20 s), validated as a number (exit 2 otherwise). Polling is fine
  here: the no-real-time rule is for tests, not for a script.
- **The steps and what proves each one.** `hello` and `paired` are the two TV-app lines above;
  `disconnect` is the third. `input` and `metrics` are the client's own lines, because the host does not log
  input: its `Latency …: input delay ~ avg … (N states)` line comes from `HostServer.latencyLogInterval`
  (`host_server.dart:31`), 30 s apart, so it is no quick proof (and no log line covers a metrics batch at all).
  `client.inputsSent` counts only states actually sent on a live connection
  (`controller_client.dart:168-170`: `if (_snap.isConnected) _send(…)`), so a non-zero count proves the input
  reached the socket; the hello line's `supports metrics, rating` proves `--metrics` took effect.
- **The sim's options.** `--host 127.0.0.1 --port <port> --code <code> --name "Smoke controller" --stream
  --metrics --seconds 12`: `--stream` is the "streams input" option (tilt 60 times a second), `--metrics` the
  metrics option, and 12 s is enough for one batch (the sim sends them every 10 s). The name matters: the TV
  app's own built-in simulated controllers are also called "Simulated controller"
  (`packages/party_host/lib/src/simulated_controllers.dart:56`), and the smoke's lines must not be confused
  with theirs.
- **Timings.** One sim step waits `sim_seconds + wait_secs` (32 s), so the first `dart run` compiling the
  package doesn't fail the step; the others wait 20 s.
- **Failure output.** `FAIL <step> (<s>s)`, then the last 10 lines of the log that step was reading — the TV
  app's log by default (as the brief says), or the tool's own output when a tool itself failed (e.g.
  `emulator.sh start`), then `Smoke failed: <step>. Logs: <folder>` and exit 1. `$out` keeps every tool's
  output (`tv-start.log`, `sim.log`, `emulator.log`, `phone-*.log`) and, with `--emulator`, `phone.png`.
- **Cleanup.** A `trap … EXIT` kills the sim (`$!` of the `(cd packages/connection && exec dart run …)` subshell,
  so it is the dart process) and calls `tools/tv-dev.sh stop` only when this run started the TV app. `--keep`
  skips both. Nothing else is stopped: not the emulator, not a phone, not anything by name.

### The second connect, without the code: skipped, and why

The brief's step b asks for a second connect that must be let in without the pairing code, "if the sim
supports saved tokens; otherwise say so in the report and skip that step". It doesn't support them:

- `sim_controller.dart` passes no `tokens:` to `ControllerClient` and has no `--token` option; the client itself
  does support them (`controller_client.dart:26` `Map<String, String> tokens = const {}`, `:104` `tokens`,
  `onTokenChanged` `:49`; `client_messages.dart:113-120` sends `PairRequestMessage(token: …)` when one is saved).
- Even with a token, the sim makes a new controller ID on every run
  (`sim_controller.dart:60`: `'sim-${List.generate(6, …)}'`), and the host's book is indexed by controller ID
  (`host_pairings.known(hello.controllerId)`), so the saved pairing would never be found.

So the step is skipped, as the brief allows, and `docs/dev-tools.md` says what the smoke does not cover. What
would make it possible is a one-line-ish change to `sim_controller.dart` (`--id` and/or saving the token it is
given through `onTokenChanged`), which this brief forbids me to make.

## How `commit-job.sh` decides, and why

- **The brief's fields.** `field() { sed -n "s/^$1: *//p" … | head -1 | tr -d '\r'; }` and the
  `sed 's/ *· */\n/g'` split are copied from `flash.sh:103-108`, so the two read `allow:` and `report:` the
  same way. Checked against this job's brief: `allow:` line → `tools/smoke.sh`, `tools/commit-job.sh`,
  `docs/dev-tools.md`; `report:` → `docs/briefs/m12/t2-g4-report.md` (both confirmed with `grep -n '^allow:\|^report:'`).
- **What gets staged.** The allow paths, the brief, the report and `<brief without .md>-{review.md,review-report.md,plan.md}`
  are each added to a list only when they exist or git already knows them (`git ls-files --error-unmatch`), so a
  deleted file still stages and a path that never existed doesn't make `git add` fail. Then one
  `git add -A -- <those paths> ':(exclude)*/windows/flutter/generated_*'`.
- **The generated files.** The exclude pathspec was tested read-only here:
  `git status --porcelain -uall -- . ':(exclude)*/windows/flutter/generated_*'` drops exactly
  `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h` and
  `generated_plugins.cmake`, which
  are the three that Flutter rewrote in this checkout.
- **Refusals, all exit 1 and all before anything is staged** (except the last): anything already staged
  (`git diff --cached --name-only`, listed); the report the brief names is missing; the message is empty; and
  after staging, nothing to commit (`git diff --cached --quiet`). A brief without `allow:` is exit 2: a
  read-only job has nothing to commit.
- **The message.** The report's `## Commit message` section, cut the way `flash.sh` prints it
  (`sed -n '/^## Commit message/,/^## /p' | sed '1d;/^## /d'`), then `tr -d '\r'`, then an awk filter that drops
  blank edge lines, a leading ```` ``` ```` line and a closing ```` ``` ```` line. `--message-file` gets the same
  filter. `COMMIT_TRAILER`, when set, is added after a blank line.
- **`--dry-run`** exports `GIT_INDEX_FILE` to a `mktemp` path, removes it and runs `git read-tree HEAD`, so the
  stage/diff/refuse steps run exactly as in a real commit and only the real index is left alone — the same trick
  as `flash.sh:260-269`. Nothing is committed.
- **Committing.** `git diff --cached --stat`, the message, `git commit -F <message file>` (no `-n`, no
  `--no-verify`: hooks and signing run as configured), `git log -1 --format='%h %s'`, and `git push` only with
  `--push`.

## Checks I ran, and the one I could not

| Check | Result |
| --- | --- |
| `tools/review.sh` (default scope) | `review: 0 fail, 0 note` — no `.dart` file in `controller_app`, `tv_test_app`, `packages`, `assets` changed, so there is nothing for it to look at |
| `git status --porcelain -uall` | my three files: ` M docs/dev-tools.md`, `?? tools/smoke.sh`, `?? tools/commit-job.sh` (plus Claude's own ` M docs/design/m12.md`, ` M docs/project-notes.md` and the three `generated_*` files) |
| `git status … ':(exclude)*/windows/flutter/generated_*'` | the pathspec in `commit-job.sh` removes exactly the three `generated_*` files (see above) |
| `git ls-files -s tools/` and `ls -l` | both new scripts are `-rwxr-xr-x` on disk, like the other `.sh` files (committed as `100755`), so `tools/smoke.sh` runs directly |
| `wc -l` | `tools/smoke.sh` 271, `tools/commit-job.sh` 194 — both under the 300-line limit. `docs/dev-tools.md` is at 400 lines now (349 before this job): see the first suggestion |
| `bash -n tools/smoke.sh tools/commit-job.sh` | **not run: refused.** Every form (`bash -n <abs>`, `bash -n <rel>`, `bash -n < file`, `sh -n`) answered "This command requires approval" in this job's sandbox, so the syntax was only read, not parsed. Run it first. |

What I could check without a shell: the `--help` line ranges (`sed -n '2,20p'` and `2,27p'` cover exactly the
header comments, `set -u` is the next line in both files), and the sample output in `dev-tools.md` — the
`%-13s` field of `printf 'PASS  %-13s (%ss)'` gives 8, 9, 8, 9, 7 and 4 spaces after `tv-app`, `hello`,
`paired`, `input`, `metrics` and `disconnect`, which is what the sample shows (verified with `grep -o`).

Nothing in either script could be executed here: no apps, no emulator, and commits are not mine to make. So the
step timings, the log patterns and the staging are reasoned from the code and the strings above, not observed.

## Questions

1. `bash -n` is the one check the brief asks for and this sandbox refused it, so please run
   `bash -n tools/smoke.sh tools/commit-job.sh` (and then `tools/smoke.sh` and
   `tools/commit-job.sh <brief> --dry-run`) before trusting the diff. The two scripts are the first bash in
   `tools/` that this job's permission list doesn't cover.
2. The second connect without the code is skipped (see above). Do you want `sim_controller.dart` to grow an
   `--id`/token option in a later brief, so the smoke can check a saved pairing too?
3. The "already staged" refusal is the literal one: *anything* staged refuses, not only files outside the job's
   set. Say if a staged file that is inside the set should be allowed through instead.
4. `--keep` leaves both the dev TV app and a still-running sim; if you meant only the TV app, it is one
   condition in `cleanup`.
5. The sample output in `docs/dev-tools.md` is hand-written (no run was possible). If you want it exact,
   replace it with a real run's output; the shapes are right but the seconds are guesses.
6. `--emulator` runs `launch` but not `install`, as the brief says, so the phone app must be installed already
   (now noted in `dev-tools.md`). Should the flag install when the app isn't there?

## Suggestions (not acted on)

- `docs/dev-tools.md` is 400 lines now (349 before this job), past the "about 300, hard limit 400" line
  the guidelines keep for code. The DeepSeek Flash helper part (about 60 lines) is the natural piece to move to
  a doc of its own; not this brief's items.
- `docs/dev-tools.md:3` still says "Two scripts replace the most repeated manual steps" while the table now
  lists nine. A one-word fix ("These scripts…"), outside this brief's three items.
- `docs/project-notes.md` "Testing recipes" could point at `tools/smoke.sh`: it is the scripted version of the
  recipes it describes, and it would sit next to the `sim_controller` line there.
- `tools/flash.sh:361-364` prints the report's draft message without the fence stripping `commit-job.sh` does,
  so a report that fences its message (as t1's did) shows the ```` ``` ```` lines in flash's output too. The
  same awk filter would make the two prints identical.
- `smoke.sh` could take a `--seconds` passthrough if you ever want a longer run (a 30 s run would make the
  host's `Latency … input delay` line reachable, and that would also prove the input on the TV's side).

## Commit message

```
tools: smoke.sh checks real clients, commit-job.sh commits a job

smoke.sh starts the development TV app (or uses the running copy) and
pairs a simulated controller with it over the real network stack,
proving the hello, the pairing, input, metrics and the disconnect from
the app's own log; --emulator adds the phone app and a screenshot, and
only what it started is stopped again.
commit-job.sh stages one job's allow paths, brief, report and review
files (never generated_* files), refuses anything already staged, and
commits the report's draft message, pushing only with --push.
```

## Status row

| Tools 2 `smoke.sh`, `commit-job.sh` | **Done** (G4, Nov 6): `tools/smoke.sh [--emulator] [--keep]` pairs a simulated controller (and, with the flag, the phone app on the emulator) with the development TV app over the real network stack and proves each step from the app's log, stopping only what it started; `tools/commit-job.sh <brief> [--message-file <file>] [--push] [--dry-run]` commits one job's allow paths, brief, report and review files with the report's draft message and never a `generated_*` file. dev-tools.md has a section and a table row for each. Open: neither script has been run (this job's sandbox refused `bash -n`), so Q1: run `bash -n` and one `smoke.sh`/`--dry-run` before relying on them; Q2–Q6 in [t2-g4-report.md](t2-g4-report.md) (the saved-pairing reconnect, the strict staged check, `--keep`, the hand-written sample, `--emulator` without `install`). |

## Delete

- none
