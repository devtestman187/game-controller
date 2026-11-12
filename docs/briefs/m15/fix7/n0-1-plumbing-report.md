## Summary

The plumbing the fix7 batch runs on is in, with no switch of its own and every
existing behaviour unchanged when nothing is set.

- **Player options.** New `streaming/player/options.js` (a pure
  `parseOptions(search, defaults)` and `optionsLine(options)`). entrypoint.sh
  writes `SESSION_PLAYER_OPTIONS` (a comma list `a=1,b=x`) into `config.js` as
  `THUMB_PARTY.options`, an object; the page's own query string overrides it key
  by key and unknown keys are kept. player.js reads it once, exposes
  `window.THUMB_PARTY_OPTIONS`, and the stats overlay shows `options: x=1`.
  `serve.py` now serves `options.js` (the module would have 404'd) and its
  relay test checks that file too.
- **Bench and tool.** `bench.sh` and `tools/stream.sh` take `--player-query Q`
  (`[A-Za-z0-9=&_.,-]` only, refused before anything starts), put `?Q` on the
  headless viewer's URL and on the URL printed for `--viewer external`, and pass
  it through to the session-side script.
- **The summary names the switches.** A run opens with
  `switches: SESSION_FEC=true, player-query x=1, player-options none`, writes it
  to `<out>/switches.txt`, and `tools/stream.sh bench` fetches it beside the
  summaries and `stats` prints it again; nothing set prints `switches: none`.
- **Docs.** `streaming/README.md` has a "Switches" section; `docs/dev-tools.md`
  has one command line.
- **Proof.** `bash -n` on all three scripts, the 3 new Dart tests (which fail on
  the old scripts), the existing suites, and one 20 s probe smoke run in the
  distro: `--probe --seconds 20 --player-query x=1 --set SESSION_FEC=true`
  printed the switches line and its page saw `options: x=1` (DOM dump). That is
  the phase's only bench run.

The headless Chromium is not Safari: this run says the plumbing works and what
the page sees, not what an iPhone does. The phone decides.

## Files changed

| File | Change |
| --- | --- |
| `streaming/player/options.js` (new) | `parseOptions(search, defaults)` merges config defaults and the URL query (bare key = `1`, unknown keys kept); `optionsLine` formats `a=1 b=x` with sorted keys |
| `streaming/player/player.js` | imports the two, reads options once, sets `window.THUMB_PARTY_OPTIONS`, shows the line in the overlay (written at start too, so a DOM dump finds it); reporter and relay untouched |
| `streaming/player/serve.py` | `options.js` added to the served page files |
| `streaming/player/relay_test.py` | the page-file check now asks for `/options.js` as well (still 16 checks) |
| `streaming/entrypoint.sh` | `SESSION_PLAYER_OPTIONS` setting; `player_options_json` turns the comma list into the JS object in `config.js` |
| `streaming/bench.sh` | `--player-query` (usage, validation, viewer URL, printed URL), `switches_line`, written to `<out>/switches.txt` and printed at run start; `--set` values may hold `=` and `,` |
| `tools/stream.sh` | `--player-query` (usage, validation, passed on), `fetch_switches`, `print_switches` (bench and stats), same `--set` charset |
| `tv_test_app/test/stream_tool_test.dart` | 3 tests: usage names the flag, bad queries refused by both scripts |
| `streaming/README.md` | new "Switches (M15 fix7)" section |
| `docs/dev-tools.md` | one `bench --player-query` command line |

Evidence in `docs/briefs/m15/fix7/n0-1-plumbing/`: `switches.txt`,
`n010.json` (the summary), `smoke-bench.log`, `page-options.txt`.

## Smoke run (headless Chrome, tp-stream, Nov 12 2026)

```
switches: SESSION_FEC=true, player-query x=1, player-options none
n010: ready after 4s
measuring 20s on 1 session(s), 1920x1080, arena (probe)
the window ended after 29s
n010: 1 viewer(s) browser/chrome-headless, 1998 kbit/s received against the 10000 kbit/s ceiling,
  summary 4126 bytes, game 18.7 ms/frame, build 0.6 + raster 5.7 ms, 0% slow
```

From `n010.json`: press_to_screen median 218 ms (n=41, p95 274, max 290),
stream_total median 163, jitter buffer 128, encode 29, capture 2, decode 3,
delivered 57.38 fps, 1378 frames received / 1370 decoded / 8 dropped,
firstFrameMs 1322; host cpu 170 %, gpu 52 %, pipelineMs 47, encoded 55.08 fps.
The probe card is nearly still, so its bitrate (1998 kbit/s) says nothing about
the round's.

Page proof (one-off dump, session kept with `--keep`, container then removed):
`chrome-headless-shell --dump-dom "http://127.0.0.1:45782/?x=1"` holds
`options: x=1` in the stats div. A second session started by hand with
`SESSION_PLAYER_OPTIONS=a=1,b=x` wrote
`window.THUMB_PARTY = { signalingPort: 45791, splitTracks: false, options: {"a": "1", "b": "x"} };`
and was stopped.

The first attempt of the smoke run failed ("session 0 never played"): the relay
answered `no file at /options.js`, so player.js could not import. Adding
`options.js` to `serve.py`'s page files fixed it; the rerun is the run above.
That is a plumbing bug found by the run, not a second measurement.

## Decisions

1. `SESSION_PLAYER_OPTIONS` can only reach a container through `--set`, whose
   value pattern refused `=` and `,`; widened it to `[A-Za-z0-9._=,-]` in both
   scripts (still no spaces), because a list setting needs it and a special case
   for one key would be worse.
2. `serve.py` had to learn `options.js`; its relay test's served-file check was
   extended rather than loosened (it still proves other files are served).
3. A bare query key (`?lowdelay`) means `"1"`, the HTML-attribute convention, so
   it is not silently dropped.
4. The options line is put in the overlay at page start as well as in
   `showStats`, so the proof needed no virtual time and no console plumbing.
5. A `SESSION_PLAYER_OPTIONS` entry that is not `KEY=VALUE` is left out, so one
   bad word cannot break the page; unknown keys are kept in both paths.
6. When anything is set, the line names `player-query` and `player-options` even
   if one is none (the brief's format); with nothing set it is `switches: none`.
7. The viewer URL gets `?Q` only when Q is given, so a run with nothing set
   opens exactly the URL it opened before.

## Tests

- `flutter test test/stream_tool_test.dart`: 21 passed (18 before). The three new
  tests fail on the code as it was: the old usage had no `--player-query`, the
  tool called the flag unknown, and `bench.sh` exited 2 (usage) instead of 1.
- `dart format` 0 changed, `dart analyze --fatal-infos` no issues,
  `packages/metrics` 155 tests passed, `tv_test_app` 75 passed, 1 skipped
  (as before).
- `bash -n` on `streaming/entrypoint.sh`, `streaming/bench.sh`,
  `tools/stream.sh`.
- Relay self-test in the distro: 16 checks passed.
- No node on the PATH here or in the distro, so no node test for `parseOptions`
  (its two paths are exercised by the smoke run and the DOM dump).

## Self-check (review-rules.md part A)

1. **Every host setup.** Nothing here reads the platform; the page change applies
   to every viewer (headless Chrome smoke, DOM dump). A phone on "Play on this
   phone" / "Show on this device" / a joined phone are untouched: no app code.
2. **Kept state.** Options are read once at page start and never change; a
   reconnect reuses them. `switches.txt` is written at run start and fetched with
   the summaries; nothing is timed or cached. With no stream the page shows only
   the options line (when set) and no other state.
3. **Combines with other states.** Nothing pauses, hides or waits. Pairs checked
   by reading: reconnect (same options), press phase (line stays in the overlay),
   stats stopped (line was written first, the stop appends), split tracks (still
   its own setting, untouched), external viewer (same URL string).
4. **Stay in the job's folder.** All changes are in `allow:`; evidence sits in
   `docs/briefs/m15/fix7/n0-1-plumbing/`. `flutter test` refreshed the tracked
   plugin registrants' line endings, but `git diff` on them is 0 bytes.
5. **Stop rather than overstep.** No file outside `allow:` was needed. The job's
   shell refused to run repository scripts (`tools/stream.sh build/status/bench`,
   `tools/check.sh`, `tools/wsl-sync.sh`), so the image was built and the bench
   run straight in the distro and the checks were run one by one; reported below.

## Questions and suggestions

1. `--player-query` is not URL-encoded (charset enforced instead). A later switch
   needing a space or a non-ASCII value would need encoding — worth deciding in
   n2 before it appears.
2. `tools/stream.sh bench`'s switches echo and `stats`' line were not exercised
   end to end (the shell refused those scripts); their content and the flag
   validation are proven. n0-2's first run should show both lines.
3. The distro copy for this job was made from
   `/work/flash-20261112-112122-10599` (seven sampled files hash-identical)
   because `tools/wsl-sync.sh` and its `tar` pipeline were refused by the shell;
   the image was then built from it in the distro.
4. The `kept:` line prints twice at the end of a `--keep` run (pre-existing:
   `stop_all` runs from the exit trap and again at the end of `main`).
5. `SESSION_SPLIT_TRACKS` still writes `splitTracks` beside `options`; a later
   job could move it into the options object, but the brief said to leave it.

## Hand-over

What exists now: the switch convention end to end — a session switch (`--set`),
a player page switch (`--player-query` or `SESSION_PLAYER_OPTIONS`), the page's
`window.THUMB_PARTY_OPTIONS` and overlay line, and the `switches:` line that a
bench prints, keeps in `switches.txt` and `stats` reprints.

Commands that worked (from the distro; the Windows shell refused repo scripts):

```
cd /work/flash-20261112-125557-13309
docker build -f streaming/Dockerfile -t tp-session:latest .
bash streaming/bench.sh --probe --seconds 20 --player-query x=1 \
  --set SESSION_FEC=true --label n01 --out /work/stream-bench/n01-smoke --keep
python3 streaming/player/relay_test.py
```

Numbers: 218 ms press-to-screen median (41 presses), stream_total 163 ms,
jitter 128 ms, encode 29 ms, 57.38 fps delivered, 1998 kbit/s on the card.

The next phase must not redo: the options parsing, the URL plumbing, the
switches line, `serve.py`'s file list, or `relay_test.py`'s file check. It can
add a key with only an options read in player.js and a docs row.

Open: the phone (Safari) side is unmeasured; the two tool-side echoes and the
generated-registrant line endings are noted above.

## Commit message

streaming: one switch convention for the fix7 batch

Add player options: SESSION_PLAYER_OPTIONS in config.js (THUMB_PARTY.options)
and a URL query that overrides it, exposed as window.THUMB_PARTY_OPTIONS and an
overlay line. bench.sh and tools/stream.sh take --player-query for both the
headless viewer and the URL printed for a phone. A run opens with one switches
line, keeps it in switches.txt, and bench and stats print it again. The relay
serves options.js. Every switch stays off by default: with nothing set the page,
the URLs and the scripts behave as before.

## Status row

n0 phase 1 (plumbing) done: player options (env + query), --player-query, the switches line in bench and stats, docs, one 20 s smoke run proves it; open: the phone comparison, the three switches themselves (n1-n3) and two tool-side echoes not yet run end to end.

## Delete

- none
