# M15 opt1b: page option jbtarget=<ms> sets the receiver's jitter buffer target, and the read-back proves it

## Summary

Added the page option `jbtarget=<ms>` (M15 opt1b): the new module
`streaming/player/jb_target.js` reads it (`jbTargetOf`), sets
`RTCRtpReceiver.jitterBufferTarget` on every receiver of both connections, once
a second and after each stream change / track, reads it back on demand, and
reports it as the gauges `jbTargetRequestedMs` / `jbTargetAppliedMs`, the fact
`jbtarget` and one overlay line. `lowdelay=1` leaves that one property to it
when both are on; the "Streaming quality" table gets the last column `jbtarget`.
Files: new `jb_target.js`, `jbtarget_selftest.html`; changed `player.js`,
`low_delay.js`, `reporter.js`, `overlay.js`, `serve.py` and `relay_test.py` (the
new module must be served), `bench.sh` (runs both test pages), `README.md`, and
`report_stream.dart`, `report_stream_test.dart`, `report_no_marker.txt` in metrics.

Tests: the new Dart test failed on the old code (header's last cell was `codec`)
and passes now, with all 163 metrics tests. The new page test failed before the
module existed and prints `SELFTEST PASS 24/24`; the marker page `60/60`; the
relay's 27 checks pass; `tools/check.sh format analyze metrics` passes.
Not done: no session and no bench (per the brief), so nothing says what Safari
on the phone does with the value; the headless run only proves the code works.

## Decisions

- **Fact text uses spaces, not `=`**: the host's fact pattern
  (`stream_stats.dart`'s `_technicalPattern`, mirrored by the page test's
  `factPattern`) has no `=`, so `req=0 has=yes read=0` would be dropped; the
  text is `req 0 has yes read 0`, and a multi-receiver read-back uses commas
  (`read 100,0`), because `/` is not a fact character either.
- **24 characters cannot hold three pairs plus an error**, so the text gives way
  in a fixed order: the error text is cut to whatever room is left; if the read
  cannot fit beside the error, the error replaces it (`req 0 has yes err setter`);
  if receivers disagree, the support pair gives way (`req 100 read 100,0`); with
  nothing read back (`missing`) the support pair stays (`req 4000 has none yet`).
  The requested value and the applied number (when single) are always in gauges.
- **Bare `?jbtarget` asks for 1 ms**: options.js gives every bare key the value
  "1", so it never means "on"; said in `jbTargetOf`'s doc comment and the README.
- **`serve.py` and `relay_test.py` list `jb_target.js`**: player.js imports it,
  and the relay 404s any file not in `page_files`, so a session would break
  without the entry; the relay test now fetches it too.
- **`watchConnection` lives in `jb_target.js`**, not in player.js: pictureReady /
  soundReady each add one line, and the track-event reapply is testable with a
  fake connection.
- **LowDelay takes `jitterBuffer` (default true)**: false leaves
  `jitterBufferTarget` to JbTarget and still zeroes `playoutDelayHint`, so the
  page without `jbtarget` behaves exactly as before.
- **The fixture `report_no_marker.txt` had to change**: its test compares a run
  without the marker byte for byte, and the new column is part of that text.
- **The CSV is unchanged**: its test still passes, so no CSV change was needed.

## Computed values

- `jbTargetOf`: `"0"`, `"20"`, `"4000"` → 0, 20, 4000; `"4001"`, `"-1"`, `""`,
  `"abc"`, `"1.5"`, `"1e2"` → null; no key / undefined / null options → null;
  `?jbtarget` → "1" → 1.
- Fact lengths: `req 0 has yes read 0` 20; `req 100 has partial` 20;
  `req 0 has yes err setter` 24 (error "setter threw" cut to 6); `req 100 read 100,0`
  17; `req 4000 has none yet` 21; worst case (4000, partial, "4000/4000/4000",
  error) → `req 4000 has partial` 20.
- Dart: the quality header's last cell is `jbtarget`; the viewer with the fact
  ends its row with `req 0 has yes read 0`; the one without shows `-`.
- Page tests: marker 60/60, jbtarget 24/24; relay 27 checks; metrics 163 tests.

## Self-check (review-rules.md part A)

1. **Every host setup.** Page-side only: every host's session serves the same
   player folder, and `serve.py` now lists `jb_target.js`, which the relay test
   fetches (27 checks). No host, phone or TV code changed; option off leaves the
   page byte-identical in behaviour.
2. **When kept state starts and ends.** The JbTarget timer starts on the first
   `watch`, is shared by later `watch` calls and ends in `stop()` from
   `connectionClosed`; with no receiver it sets nothing and reports `none yet`
   (tests "a receiver that appears later…", "before any receiver exists…").
3. **How it combines with the others.** Off: `jbTarget` is null, LowDelay is
   built as before, the reporter gets no extra provider and the overlay no line.
   With `lowdelay=1`: `jbtarget` wins on `jitterBufferTarget`, `playoutDelayHint`
   stays 0 (two LowDelay tests). After a reconnect new connections are watched in
   pictureReady / soundReady (track-event test).
4. **Stay in the job's folder.** Only files under the brief's `allow:` were
   written; no scratch file was left.
5. **Stop rather than overstep.** The host's 24-character, no-`=` fact rule
   contradicts the brief's example text; the text was fitted to the rule (which
   the brief asked), not the rule changed, and it is under Decisions.

## Hand-over

`jbtarget=<ms>` works end to end on the page: `jbtarget.js` sets and reads back
the target, `bench.sh --player-query "marker=1&jbtarget=0"` passes it, and the
summary shows the `jbtarget` column plus the two gauges. Commands that worked:
`bash streaming/bench.sh --selftest` and `python3 streaming/player/relay_test.py`
in the tp-stream distro; `tools/check.sh format analyze metrics` on Windows. The
next phase must not redo the text-fitting order; the open question is the phone:
only a Safari 27 run says whether the value arrives, stays and what it does to
press-to-screen. The brief's example text `req=0 has=yes read=0` cannot be sent
as a fact (no `=`), so a reader of the old docs should expect the space form.
The working tree already held changes this job did not make: the six
`tv_test_app/**/generated_*` files and the untracked `docs/briefs/m15/opt1/run-base`
and `docs/briefs/m15/opt1b/run-base`; they are not part of this diff.

## Commit message

M15 opt1b: jbtarget=<ms> sets the receiver jitter buffer target

Adds the page option jbtarget=<ms> (0..4000, off unless asked): a new small
module sets RTCRtpReceiver.jitterBufferTarget on every receiver of both
connections, reapplies it every second and after each stream change or track,
and reads it back every time. With lowdelay=1 the jbtarget value wins over that
switch's 0. Each reporter batch then carries jbTargetRequestedMs,
jbTargetAppliedMs (the read-back, when single) and the fact jbtarget, the
overlay shows one line, and the bench's Streaming quality table gets a
jbtarget column. Page tests run as a second selftest page; the relay serves the
new module. Nothing changes without the option.

## Status row

M15 opt1b: page `jbtarget=<ms>` done and proven on the page (24/24 page tests, 163 metrics tests); open: a Safari 27 phone run to show whether the value arrives and stays, and what it does to press-to-screen.

## Delete

- none
