# M15 opt2-7 (wrap-up): README section for the batch, and the batch's size audit

## Summary

Documents only: `streaming/README.md` gains a section "Custom player (WebCodecs),
off by default" — `SESSION_TAP` and its tee/leaky tap branch, `TAP_PORT` and the
relay's `/tap` tunnel on the player port (no new port, no firewall rule), the
message format in two lines pointing at PROTOCOL.md, `?player=wc` and
`wcmode=annexb`, `--player-query "marker=1&player=wc"`, sound in this mode,
`SESSION_AUDIO=separate`'s new meaning, the "Custom player (wc)" bench table,
the image's new apt packages, and four known limits. Also: one TAP_PORT
paragraph under "Ports", and the stale `separate` clause of the picture
settings table now says "its own process" (533 → 607 lines).

Audit (full list under "Audit"): four files the batch touched end over 380
lines — `streaming/bench.sh` 965, `tools/stream.sh` 757,
`streaming/entrypoint.sh` 747, and `streaming/tap/tap_server_test.py` 407 (a
test file, inside the 500-line test limit). No function over 60 lines in the
batch's new files (longest: `tap_frames.py`'s `_sps_fields`, 50).

Checks: `bash tools/check.sh format` is refused by this shell, so its own
command ran: `dart format --output=none --set-exit-if-changed controller_app
tv_test_app packages assets` — 795 files, none changed. A Markdown-only diff
adds no test, no `bash -n` and no `py_compile` case.

Decisions, not done, obstacles: under their headings below. Turns used: not
known.

## Audit (read-only counts)

Files the batch touched (`git diff --stat 1de9cc3~1 HEAD`) that end over 380
lines, with their length before the batch:

| File | Now | Before | Note |
| --- | --- | --- | --- |
| `streaming/bench.sh` | 965 | 963 | a shell script, over 380 before and after (+2 lines) |
| `tools/stream.sh` | 757 | 753 | a shell script, over 380 before and after (+4) |
| `streaming/entrypoint.sh` | 747 | 612 | a shell script, over 380 before and after (+135: the tap, the sound's own process) |
| `streaming/tap/tap_server_test.py` | 407 | — (new) | a test file; the guidelines allow tests 500, so it is inside the limit and over the 380 script/lib one |

Also at exactly 380 lines, so the next line trips the runner's 380 rule:
`streaming/player/wc_player.js`, `serve.py`, `player.js`, `reporter.js`,
`wc_selftest.html`.

Functions over 60 lines in the batch's new files: none. Longest, measured from
the `def`/method line to its last body line: `tap_frames.py` `_sps_fields`
(183–232) 50, `entrypoint_audio_test.sh` `expected_joined` 50,
`wc_player.js` `constructor` (61–99) 39, `tap_server.py` `_handshake` (200–233)
34. Older than the batch but in a file it touched: `entrypoint.sh`'s `main()`
is 84 lines (645–728; 78 before).

## Files changed

- `streaming/README.md`: the new section after the capability probe, the
  TAP_PORT paragraph under "Ports", and the `SESSION_AUDIO` row's `separate`
  clause corrected to a second `gst-launch-1.0` process with its own log
  (`/run/thumb-party/sound-pipeline.log`) and its pipeline time (8.0 ms against
  `joined`'s 41.6 and 7.95 with no sound).
- `docs/briefs/m15/opt2/opt2-7-readme-report.md`: this report.

## Decisions (why)

- The tap branch is quoted without a byte-stream caps filter: opt2-1 measured
  that word stalling the pipeline at PAUSED and removed it, so PROTOCOL.md's
  wording would have described a branch the image does not run.
- The stale `separate` clause was fixed rather than left beside the new section:
  it now describes a second process, and two contradictory statements in one
  file would be worse than a slightly larger diff (opt2-5 named the README text
  as not done because the file was outside its `allow:`).
- The TAP_PORT paragraph sits under "Ports" because that table opens with
  "every port is an environment variable" inside the `--port-base` block, and
  TAP_PORT is the one that is not.
- The section goes after the capability probe: the page and its probe stay
  together, and the custom player then leads into "What the session measures".
- No live custom-player run is claimed: opt2-6's proof report does not exist, so
  the limits say "proven headless so far" from the page selftests in opt2-3/4,
  not figures from a session. The bullet is to be rewritten when opt2-6 lands.
- Only facts the five reports and PROTOCOL.md state are used; the one figure
  from elsewhere (the secure-context limit) repeats what the README's own
  capability-probe section already says.

## Self-check (review-rules part A)

1. Every host setup: not affected — a Markdown-only change; no TV, phone host,
   joined phone or older build reads this file.
2. Kept state: not affected — nothing held, timed, counted or remembered changed.
3. Combining states: not affected — no pause, away or input owner was touched.
4. Stay in the job's folder: only `streaming/README.md` and this report were
   written; `git status` shows no other text file changed.
5. Stop rather than overstep: nothing outside `allow:` was needed; the second
   README edit (the `separate` row) is inside the allowed file and is listed
   under Decisions.

## Hand-over

What exists: the section "Custom player (WebCodecs), off by default" (README
lines 321–388: switch table, tunnel, message, page, sound, bench table, image,
limits), the TAP_PORT paragraph under "Ports", and the corrected `SESSION_AUDIO`
row in "The picture's settings (M15 t1)".

Commands that worked: `dart format --output=none --set-exit-if-changed
controller_app tv_test_app packages assets` (795 files, 0 changed);
`git diff --stat 1de9cc3~1 HEAD` for the batch's file list; `wc -l` over the
batch's files; `grep -n` on `def`/method lines for the size audit.

Next phase must not redo: the section's facts (taken from the five reports and
PROTOCOL.md), the audit's counts, or the `separate` correction.

Open problems: opt2-6 (the proof run) has no report, so the limits bullet says
only what the page selftests prove — rewrite it with the run's numbers. Three
shell scripts over 380 lines (`bench.sh`, `entrypoint.sh`, `tools/stream.sh`)
and five files at exactly 380 want a split; `tools/check.sh format` cannot run
in this shell, only its `dart format` command.

## Commit message

README: document the tap, the custom player and separate sound

Add a "Custom player (WebCodecs), off by default" section: SESSION_TAP, TAP_PORT
and the relay's /tap tunnel on the player port, the message format (pointing at
PROTOCOL.md), ?player=wc and wcmode=annexb, the marker query, the sound in this
mode, the "Custom player (wc)" bench table, the image's apt packages and the
known limits. Note TAP_PORT under Ports, and correct SESSION_AUDIO=separate to
the sound's own process with its measured pipeline time. Documents only.

## Status row

M15 opt2-7 done: README's custom-player section, TAP_PORT note and `separate`
correction, plus the batch's size audit — open: opt2-6's numbers in the limits
bullet, and splitting the three scripts over 380 lines.

## Delete

- none
