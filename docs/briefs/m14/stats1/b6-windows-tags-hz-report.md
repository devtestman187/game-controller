## Summary

**No code is broken: the exported Windows rounds are from older builds.** A
round is filed with its rate and its tags by the same code whatever hosts it;
nothing on the Windows path is skipped. I proved it end to end (a real
Windows-typed host service, a real socket phone, a real `ArenaSession`): the
summary's round came out with `hz: 60` and
`tags: [mode_bumper, map_playroom, robo_medium, finished]`.

The four steps the brief asked about, one line each:

- **Another recorder**: no — one `LiveStats` for every host type
  (`host_service.dart:146-157`), fed by `identity.hostType`
  (`tv_test_app/lib/src/tv_host_setup.dart:25-29`): a summary label, no branch.
- **`host.viewRateHz` null**: yes on a TV or PC host (`shareView` false, so
  `server_game_host.dart:248` keeps no view), but only the phones' view counts
  and stage samples read it (`session_recorder.dart:54`, `live_stats.dart:72`);
  a round's rate is the game's own `HostingSettings.frameRateHz`.
- **Records not reaching the recorder**: they do — `live_stats.dart:73` listens
  to `host.records`, `server_game_host.dart:301` feeds it, and the probe saw
  `round_start`, `round_end` and `frames` arrive in order.
- **`session()` null**: no — a session runs from the first player's join.

Dates: hz shipped in `3cd7fb3` (2026-11-07, first in m12.2); tags in `b86430f`
(2026-11-10, first in m14.2). Windows builds come only from release tags, so a
round with neither field was written before m12.2 (Nov 7, 2026, 12:21).

Tests: none kept — the probe passes on the current code, so it is under
**Delete**. Checks: `tools/check.sh format analyze host` PASS, 460 host tests.

## Where the two fields are set, on every host

- hz: the games write `round_start` with `hz` (`packages/test_game/lib/src/arena_session.dart:153`,
  `packages/puzzle_game/lib/src/puzzle_session.dart:75` and `:200-206`); the
  recorder stores it (`packages/party_host/lib/src/session_recorder.dart:72-75`)
  and the round JSON takes it (`packages/metrics/lib/src/session.dart:196-199`
  and `:234`).
- tags: the games write them on `round_end` (`arena_session.dart:177-179` with
  `_tags()` at `:217-223`, `puzzle_session.dart:145` and
  `packages/puzzle_game/lib/src/puzzle_report.dart:80`); the recorder passes them
  on (`session_recorder.dart:83`, `:96`) and `_roundTags` keeps them
  (`session.dart:232-241`, filter at `:322-325`; every tag I saw matches
  `^[a-z0-9_.-]{1,32}$`).

### Dates and builds

- hz shipped in `3cd7fb3`, 2026-11-07 11:12 — first in **m12.2** (Nov 7, 12:21),
  not in m12.1 (Nov 7, 05:49).
- tags shipped in `b86430f`, 2026-11-10 22:30 — first in **m14.2** (Nov 12,
  07:17), not in m14.1 (Nov 10, 21:47).
- Windows builds are one zip per release tag (`.github/workflows/release.yml:138-174`),
  so a build has them from those tags on, and no round is ever rewritten
  (`live_stats.dart:223`): a sessions folder carries every build the PC has run.

### Why the probe is not kept

It **passed on the current code** (460 host tests green, 1 of them mine), and by
the brief's own branch ("otherwise add no code") that means no code — a new test
that passes on the old code would also trip the runner's tests-first check.

## Decisions

- **No code, no test.** The brief's second branch: current code sets both fields
  and the exports predate the commits that added them.
- **Diagnosed on a real host, not by reading only.** The probe used
  `LiveHostService` with the TV app's Windows identity, a real in-process phone
  and a real `ArenaSession`, so it covers the whole chain the brief lists.
- **Arena, not the puzzle, for the probe.** The arena needs no puzzle library,
  and its `round_end` carries the host's own tags too; the puzzle's tag path is
  the same recorder plus `puzzle_report.dart:80`, and b4 covers its `level_`
  tag.
- **Kept `round_start` before the first step.** Nothing to change, but worth
  knowing: `ArenaSession` writes the rate only once a player is in its player
  list (`arena_session.dart:150-154`). A round whose first step ran with nobody
  in the host left the rate out (my first probe hit exactly that, a race in the
  test, not in the app).

## Self-check (review-rules.md part A)

1. **Every host setup.** Not affected: no code changed. The probe is a PC host
   (host type `windows`); the recorder it exercises is the one the TV, the
   phone hosts and older peers' summaries all go through.
2. **When kept state starts and ends.** Not affected. The round's rate is kept
   from `round_start` to the next `round_end` and cleared on an abandoned round
   (`metrics/lib/src/session.dart:196-199`, `:227-230`, `:244`).
3. **How a new state combines with the others.** Not affected.
4. **Stay in the job's folder.** Only `docs/briefs/m14/stats1/` was written, and
   the probe test inside `packages/party_host/test` (allowed), which is deleted.
5. **Stop rather than overstep.** Nothing needed outside `allow:`.

## Files changed

- `docs/briefs/m14/stats1/b6-windows-tags-hz-report.md` — this report.
- `packages/party_host/test/windows_round_tags_test.dart` — the probe; **to be
  deleted** (see below), it passes on the current code and proves the finding.

## Checks

- `tools/check.sh format analyze host` — PASS (460 host tests). An earlier run
  failed once on `live_stats_lifecycle_test.dart` (a Windows temp-folder
  `PathNotFoundException`, the flake noted in m12 s8c); it passed on the rerun.
- Probe values (a Bumper Round, one player, `HostingSettings(frameRateHz: 60)`,
  3602 advances at 60 Hz): round `hz: 60`, `timeS: 60.0`, `players: 1`, tags
  `[mode_bumper, map_playroom, robo_medium, finished]`, host `windows`, frames
  `drawn: 3602`.

## Suggestions (not acted on)

1. If Windows rounds keep turning up empty, ask the owner which build made them
   (the Stats screen shows no version per session; the summary's `host.app` does
   — `session.dart:296`). A `host.app` of 0.13.x or an m14.1 0.14.0 before
   22:30 on Nov 10 explains a missing hz/tags pair only for those files.
2. A cheap future guard: the games could repeat `hz` on `round_end` as a
   fallback for a round whose `round_start` arrived with nobody in the host. Not
   needed for this bug.

## Hand-over

- Nothing to fix in `lib/`: the Windows path has no skipped step, and the two
  commits that add hz and tags are in every build from m12.2 and m14.2 on.
- The finding is "older builds only": a Windows round with neither field was
  written before m12.2 (Nov 7, 2026, 12:21); with no tags only, before m14.2
  (Nov 12, 07:17).
- The probe test must go: it passes on the old code, and the runner stops on a
  new test that does. It is listed under Delete.
- If the owner can say which Windows build made the exports, the dates above
  turn the finding into a confirmed one; until then it is reasoned from the
  commits and the tags, not from the app's own version.
- b4's `level_` finding is separate: the 14 Nov TV puzzle rounds have `chaos_`
  but no `level_`, which its own brief covers.

## Commit message

Diagnose Windows rounds' missing tags and hz: older builds, no code change

The M14 stats1 b6 job asked why rounds exported from a Windows host carry no
tags and no round rate. Both are set by the same code on every host: the games
write `round_start.hz` and `round_end.tags`, the session recorder passes them
on, and the summary keeps them. A real Windows-typed host service, a socket
phone and a real Arena session produce a round with `hz: 60` and
`[mode_bumper, map_playroom, robo_medium, finished]`.

The commits that add the two fields are `3cd7fb3` (hz, 2026-11-07, first in
m12.2) and `b86430f` (tags, 2026-11-10, first in m14.2), while Windows builds
come only from release tags: the exported rounds predate them. No code changes.

## Status row

b6 Windows tags/hz: diagnosed, no code change - current code sets both
(`session_recorder.dart:72-75`, `:83/:96`) and a Windows-typed real host run
shows `hz: 60` with `[mode_bumper, map_playroom, robo_medium, finished]`; the
exports predate m12.2 (hz) and m14.2 (tags). Open: which Windows build made the
exports (only visible in each summary's `host.app`); the probe test is deleted.

## Delete

- packages/party_host/test/windows_round_tags_test.dart
