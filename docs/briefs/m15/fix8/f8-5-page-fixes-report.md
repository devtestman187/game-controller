# M15 fix8 phase 5 — page fixes (build): report

## Summary

The player page now ends its session instead of reconnecting forever, and says which session it
belongs to so a bench session can tell a viewer it did not serve from one it did. Both halves are in,
tested and shown working in one 30 s run in `tp-stream`.

- **The ended line.** `streaming/player/session_end.js` holds the decision as a pure function,
  `sessionPhase({ hasPlayed, isPlaying, lostMs })`, and a small watch that calls it every second:
  playing while the picture plays; waiting while the page has never played (a page opened before the
  TV is a start, not an end); reconnecting for a drop of up to 15 s (the longest hiccup the page
  treats as a hiccup, `hiccupMaxMs`); ended past it. An ended page says
  "The stream has ended. Reload this page to join the next session." in its status line, stops its
  statistics, its reporting, its reconnect timers and its connection, and ignores any producer that
  appears afterwards. Only a reload joins the next session.
- **The session it joined.** The entrypoint makes a per-container `session_id` (date + PID), writes it
  into `config.js` (`window.THUMB_PARTY.sessionId`) and starts the relay with `--session-id`. The page
  sends it on every report (`sessionId` in the POST body, `x-player-session` on the stats batches).
  The relay answers an earlier session's report with `{"stale": true}` (and names the page in
  `GET /player`'s `stalePages`), refuses its stats batch with a 403 "this page belongs to an earlier
  session", and the page treats that answer as its session having ended.
- **What the bench sees.** The page puts its status line in `document.title`, so a run reads a state
  off a page it left open. `streaming/bench.sh --end-check` gives each viewer a
  `--remote-debugging-port`, reads the titles from `GET /json`, prints
  `"<session>: ignored a viewer loaded before this session: <id>; waiting for a fresh page"` for a
  stale page (once per id), keeps waiting for a fresh one until its own timeout, and after the run
  removes each session's containers and waits for the page to say the ended line.
- **Defaults are unchanged.** `--end-check` is a new switch, off by default; a run without it behaves
  exactly as before (no debug port, no extra requests, no extra output). The relay's session check
  passes everything when the relay has no id (an older entrypoint, the tests' default).

## Files changed (one line each)

- `streaming/player/session_end.js` (new, 92): `sessionPhase`, `createSessionWatch`, `endedText`,
  `hiccupMaxMs`, `watchTickMs`.
- `streaming/player/overlay.js` (new, 117): the page's text — status line, tab title and the numbers
  box the "i" key opens — moved out of `player.js` so it stays under the guides' 380/400-line limits.
- `streaming/player/player.js` (383): imports the two new modules, names itself and its session, ends
  the session (status, stats, reporting, links, playback), feeds the watch the picture's play/loss,
  and gates every signalling callback on `ended`.
- `streaming/player/streams.js` (197): `stop()` — sets a flag the connect/reconnect paths return on and
  clears the pending reconnect timer.
- `streaming/player/page_state.js` (102): the page's identity (`identifyPlayer`), the relay's stale
  answer (`setStaleHandler`), `sessionIdOf()`, and "ended" in the state list.
- `streaming/player/reporter.js` (370): sends `x-player-session: <session id>` on every stats batch.
- `streaming/player/serve.py` (335): `--session-id`, `stalePages` in `GET /player`, the 403 for an
  earlier session's batch, `stale: true` for its reports, and `overlay.js` in the served files.
- `streaming/entrypoint.sh` (612): `session_id="${SESSION_ID:-$(date +%Y%m%d%H%M%S)-$$}"`, written into
  `config.js` and passed to `serve.py`.
- `streaming/bench.sh` (956): `--end-check`, `free_port()`, the debug port per viewer, the
  ignored-viewer line, the ended-line check after the run, and a tightened selftest PASS grep.
- `streaming/player/marker_selftest.html` (360): 10 checks over the session's end (60 in total).
- `streaming/player/relay_test.py` (255): `test_session_identity`, 8 checks over a page's session (24
  in total).
- `streaming/README.md`: the ended line and the 15 s hiccup, the session identity, `--end-check`, the
  ignored-viewer line, and the relay test's twenty-four checks.
- `docs/dev-tools.md`: the two self-tests' counts and what they cover.
- `docs/briefs/m15/fix8/f8-5-page-fixes/f85-run.log` (new): the proof run's output, fetched from the
  distro.

## Decisions

- **No node in the distro, so the pure function is tested in the page's own selftest.** The brief
  prefers node on PATH; there is none, so the decision logic is checked in
  `marker_selftest.html` run by the headless Chrome already in the image (the second of its three
  ways), and the watch is tested there too against a fake clock. The relay half runs in `relay_test.py`,
  which the image has Python for.
- **A hiccup is 15 s, and the longest hiccup is stated as one number.** `hiccupMaxMs = 15000` in
  `session_end.js`, with a selftest check that pins the boundary (15 000 ms is still reconnecting,
  15 001 ms ends the page) so a future change to it must change the test and the README together.
- **A page that never played never ends.** A TV viewer that opens before the host starts has not
  missed anything, so it keeps waiting at every length of drop; only a picture that played and then
  stayed away past the hiccup means the session is over. This is what lets a viewer opened a minute
  early still join, and it is checked in the selftest at 600 000 ms.
- **The session is an id in `config.js`, compared by the relay.** No clocks, no protocol handshake: the
  entrypoint already writes `config.js` per container, so the id costs one string, and the relay
  compares it with the one it was started with. A relay started without an id accepts everything
  (older entrypoint, the tests) — the check can only ever refuse, never lock a page out of a session
  that has no identity.
- **A stale page is told, not dropped.** The relay answers its report `{"stale": true}` with 200, so
  the page knows to end and says the ended line; its numbers are refused (403) so none reach the host.
  The bench prints the ignored-viewer line from `GET /player`'s `stalePages`, deduped by id.
- **The bench reads the DOM through Chrome's own `/json`.** After the run the relay is gone, so the
  page cannot be asked anything; the title it mirrors is readable from the browser's debugging port
  with the curl-based tooling the bench already uses. Only `--end-check` runs open a port.
- **`--end-check` refuses `--viewer app` and `--keep`.** The app viewer has no debugging port to read,
  and `--keep` means "leave the containers", which the end check (it removes each session to end it)
  cannot do. Both refusals are in `check_args`, with a sentence saying why.
- **A false `SELFTEST PASS` was possible and is fixed.** The old grep matched the page's own inline
  script text, so a page that never ran a check looked like a pass (it did, on the first run of this
  job). The grep now needs `SELFTEST PASS <n>/<n>`.
- **The overlay/status seam moved to `overlay.js`.** `player.js` reached 433 lines during this job and
  the guides send a diff back over 400; the split is along the responsibility seam (what the page says
  vs what it wires up) and is a verbatim move, re-verified by both selftests and the proof run.

## Proof: one 30 s run in `tp-stream`

Staging (inside one `wsl -d tp-stream` call, so the distro stays up): start a first session
`tp-stale-a` on ports 45780–45783 with the GPU flags, wait for `http://127.0.0.1:45782/`, load it in
`chrome-headless-shell` (this is the viewer that will be stale), stop the container, then run

```bash
bash streaming/bench.sh --seconds 30 --label f85 --end-check --out /work/f85
```

after rebuilding the image (`docker build -f streaming/Dockerfile -t tp-session:latest .`) — the image
carries the player folder, and without the rebuild the run tested the old page (first attempt, no
line, 2 viewers counted, "the page did not say the stream ended in 45s").

Output (`f85-run.log`, the bench's own lines; the two "stale staging" lines are the script's):

```
f850: ready after 4s
f850: ignored a viewer loaded before this session: ThumbPartyPlayer-1794541935473; waiting for a fresh page
measuring 30s on 1 session(s), 1920x1080, arena
the window ended after 41s
f850: 1 viewer(s) browser/chrome-headless, 8979 kbit/s received against the 10000 kbit/s ceiling, summary 3891 bytes, game 49.2 fps, 20.9 ms/frame, build 1.4 + raster 9.8 ms, 7% slow
results in /work/f85
f850: the page says "The stream has ended. Reload this page to join the next session."
```

Both effects in one run: the viewer loaded before the session is named, not counted (1 viewer, not 2),
and the bench kept waiting for a fresh page (which arrived 4 s later) instead of failing; the session
was then stopped and the page it had served said the ended line. The numbers are a normal run's (49.2
fps, 8979 of 10 000 kbit/s, 3891-byte summary, 3 s over the window for the stop and the read).

## Checks run

- `python3 streaming/player/relay_test.py` in the distro: `relay test: 24 checks passed`.
- `bash streaming/bench.sh --selftest` in the distro: `SELFTEST PASS 60/60`.
- `bash -n` on `bench.sh`, `entrypoint.sh`: OK.
- `tools/check.sh format analyze metrics tv`: format PASS, analyze PASS, metrics PASS (162 tests), tv
  PASS (92 s).
- The proof run above, after the `overlay.js` split (it passed before the split too, with the same
  lines and 1 viewer).

## Self-check (review-rules part A)

1. **Every host setup.** Not affected: the change is inside the TV viewer's page, the relay that
   serves it and the bench that drives it. A phone host, "Play on this phone", "Show on this device"
   and a joined phone never load `streaming/player/`. An older build's session has no session id, and
   its pages are accepted (the relay's check passes when either side has none) — tested by
   `test_session_identity`'s first check.
2. **When kept state starts and ends.** The page's `ended` flag starts false, is set once by the watch
   or by the relay's stale answer, and clears only on a reload; after it, linking, connecting, the
   stats timer and the reporter all stop (selftest: "the watch ends once past the hiccup"). The
   watch's own timer starts with the page and is stopped by `stop()`; a picture that never comes
   leaves the page "waiting" forever, which is the intended TV state. The relay's stale list starts
   empty per container and is capped at 10 pages (`max_stale_pages`), deduped by id.
3. **How a new state combines with the others.** Pairs that can happen: ended + a producer from the
   next session (the page ignores it: `ended` gate in the listeners — selftest and the proof's stale
   page); ended + a stream still open (playback cleared, links stopped); ended + statistics in flight
   (`overlay.stop`, reporter stopped); ended + a reconnect timer pending (`StreamLinks.stop` clears
   it); stale answer + a normal drop (both end the session, `endSession` is idempotent). Not
   testable here: the pause menu, host away, results — none exist on the viewer page.
4. **Stay in the job's folder.** Every changed file is in the brief's list; the only other writes are
   the report and the fetched log, both named in it. Nothing outside the repository was written
   except inside the distro (image, `/work`, `/tmp`).
5. **Stop rather than overstep.** Nothing needed outside `allow:`. One point worth a decision (below):
   `player.js` crossed 400 lines during the job, so I split `overlay.js` inside the same files I may
   change rather than leaving it over the limit.

## Hand-over

What exists now, and what the next phase must not redo:

- The ended/hiccup rule is `sessionPhase` in `streaming/player/session_end.js`; its boundary (15 000 ms
  reconnecting, 15 001 ended) is pinned in `marker_selftest.html`, so a change to the number means
  changing the selftest, `streaming/README.md` and this report.
- The session id path is complete: entrypoint → `config.js` → page body/header → relay's compare →
  `stale: true` / 403 → the page's end. Anyone adding a report body field must keep
  `identifyPlayer`'s `sessionId` in it, or the relay will treat that page as an earlier session's.
- The bench's DOM reading is `document.title` + `GET /json` on `--remote-debugging-port`; it only
  exists under `--end-check`. Do not add a second title writer on the page without checking
  `wait_ended_title`'s substring.
- Commands that worked: `tools/wsl-sync.sh tp-stream`, then in one `wsl -d tp-stream -u root -- bash -lc`
  call `python3 streaming/player/relay_test.py`, `bash streaming/bench.sh --selftest`, and the staged
  proof run above. The image must be rebuilt (`docker build -f streaming/Dockerfile -t tp-session:latest .`)
  after any player or entrypoint change, or the run tests the old page — this cost one full run here.
- Open: `player.js` is 383 lines, `bench.sh` 956, `entrypoint.sh` 612 — the two shell files were
  already over the guides' numbers before this job; see Questions.

## Questions

1. **`bench.sh` (956) and `entrypoint.sh` (612) are over the guidelines' file length.** They were over
   before this job (the brief's own hard rule names only `lib/` files); splitting them is a job of its
   own, and I did not do it inside this one. Say which seam you want (bench's `end_check` block is the
   natural first one to lift into a sourced file).
2. **`--end-check` removes each session to end it.** That is the only way to end a session the bench
   can do without a new protocol message, but it means the mode cannot be combined with `--keep`; if
   you want an end check that leaves the containers, the session needs a stop message instead.
3. **Relay with no id accepts every page.** An image built by an older entrypoint (no `--session-id`)
   will count a stale page's numbers again. That is deliberate (compatibility), but if v3 ever runs
   mixed versions on the same host it should be revisited.

Note on the tree: `git status` also shows `tv_test_app/*/flutter/generated_plugin*` modified and
`docs/briefs/m15/c2/results/bench/` untracked. Neither is this job's: the registrants were touched at
21:36, before my first edit, and the c2 folder belongs to an earlier job. I left both alone (this job
cannot run git commands that change the tree).

## Commit message

```
Player page ends its session and names the session it joined

The page now stops reconnecting once its session is over: a picture
that played and stays away longer than a 15 s hiccup ends the page,
which says "The stream has ended. Reload this page to join the next
session." and ignores the next session's producers until reloaded.
Each session writes an id into config.js, the page sends it with its
reports, and the relay answers a page of an earlier session with
stale: true and refuses its numbers, so a viewer loaded before the
session is ignored instead of counted. bench.sh --end-check reads
that, prints the ignored-viewer line and checks the ended line
after the run; it is off by default.
```

## Status row

M15 fix8 phase 5 (page fixes) built: the page ends its session with the ended line and the bench
ignores a viewer loaded before the session (proved by one 30 s run); open: file lengths of
`bench.sh`/`entrypoint.sh` and an end check that does not remove the containers.

## Delete

- docs/briefs/m15/fix8/f8-5-page-fixes/proof.sh
