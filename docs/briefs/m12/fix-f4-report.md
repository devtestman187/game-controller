# M12 build 4 fix F4 — G4 report: the Get ready frame, its protocol row, the ratings copy

Done at G4, the gate the brief names, with the brief's four items: the beat frame (`n: -1`) is now a step's frame
with its `n` at -1 (roster and acks, built by one `_frame`), it goes out whether or not a viewer has paired, the
wire is documented (`docs/protocol.md` and `FrameMessage.n`), and a summary copies `ratings` like `rounds` and
`games`. Fixture: code-health N6 (findings 1, 2, 3 and 4 of the build 4 review) and N7 (finding 5). No file outside
`allow:` was edited (the three `tv_test_app/windows/flutter/generated_*` files show as modified, line endings only,
rewritten by the check tools' `flutter pub get` — see the note at the end).

## Files changed

- `packages/game_kit/lib/src/game_session.dart` (335 lines) — `_frame(n, atMs, {sounds})` is the one place a frame
  is built: snapshot, `snd`, `acks`, `roster`. `_publishIfDue` and `_publishFirstFrame` both call it, so the beat's
  frame and a step's frame cannot drift again. `_readPlayers()` (the player/pad/button part of the old `_sample`) is
  extracted so `_publishFirstFrame` can read the roster before any advance has run; `_sample()` calls it and keeps
  the freshness bookkeeping. `_publishFirstFrame` no longer returns on `!host.hasViewers`: the frame goes out and the
  host keeps it as `_viewFrame`, so a viewer that pairs during the beat gets it after `view_start`. Doc comments of
  the method and of the `paused` setter say so.
- `packages/game_kit/test/session_test.dart` (334 lines) — one test rewritten, two added (below); `dart:async` for
  the `Completer` of the pairing test.
- `packages/protocol/lib/src/view.dart` (297 lines) — `FrameMessage.n`'s doc: -1 for the beat's frame, then from 0,
  no frame while a round is paused, an older viewer reads -1 → 0 as no gap.
- `docs/protocol.md` (292 lines) — the `frame` row's `n` and the §10a paragraph: what the beat's frame carries, that
  it is sent before a viewer pairs, that none follows while a round is held or paused, and how an older viewer draws
  it.
- `packages/metrics/lib/src/session_player.dart` (190 lines) — `'ratings'` is a list of copies of the rating maps,
  like `rounds` and `games`; the "Copied…" comment now covers both `ratings` and `games`, so `playerJson` stays at
  40 lines (it was 42 with a comment of its own, a `review.sh` NOTE).
- `packages/metrics/test/metrics_test.dart` (277 lines) — 'a summary taken before a rating doesn't change after it'.
- `docs/briefs/m12/fix-f4-report.md` — this report.

## Tests, each failing first

I put the tests in with the fix out, ran them, then fixed, then ran them again. What the runs printed:

- `session_test.dart` 'the round's first frame is sent even when no viewer has paired yet' (replaces 'with no viewer
  the first frame is not sent'): `Expected: an object with length of <1> / Actual: [] / Which: has length of <0>` —
  the beat frame never left the session while `hasViewers` was false.
- `session_test.dart` 'the round's first frame carries the roster and the acks, like a step's': `Bad state: No
  element / List.single` at the `frames.single` line (no frame at all without a viewer); and the old code built
  `FrameMessage(n: -1, atMs: …, snapshot: …)` only, so `acks` and `roster` were the empty defaults whenever the
  frame did go out.
- `session_test.dart` 'a viewer that pairs during the beat gets view_start and the beat frame': `TimeoutException
  after 0:00:05.000000: Future not completed` — the phone got `view_start` and nothing after it (the host kept no
  frame to re-send).
- `metrics_test.dart` 'a summary taken before a rating doesn't change after it': `Expected: empty / Actual: [{'game':
  'arena', 'face': 'good', 'tags': ['laggy']}]` — the summary's `ratings` was the session's live list.

Old → new test names: 'with no viewer the first frame is not sent' → 'the round's first frame is sent even when no
viewer has paired yet' (the bug's own case, inverted by the fix; nothing else existing changed). Two tests added:
'the round's first frame carries the roster and the acks, like a step's' and 'a viewer that pairs during the beat
gets view_start and the beat frame'; one added in metrics.

## Values I computed

The fake clock starts at 0 and `FakeSnapshot.toJson()` is `{'n': steps}`, so the beat frame of the first two tests
is `n: -1`, `at: 0`, `s: {'n': 0}` (no step ran), `snd: []`, and:

- roster/acks test: players `a` (number 1, nickname `Phone a`) and `b` (number 2, no nickname), `inputSeqs['a'] = 4`
  → `acks: {'a': 4}` (only a player with an input seq has an ack) and
  `roster: {'a': (number: 1, name: 'Phone a'), 'b': (number: 2, name: '')}`.
- pairing test: the round is held with `hasViewers` false (checked), the viewer pairs, and its first two view events
  are `ViewStarted` then `ViewFrame` with `frame.n == -1`; the 5 s timeout only fires when that frame is missing
  (it did, before the fix).
- metrics: `early['players'][0]['ratings']` is `[]` before and after `rating()`; the summary taken after it has
  `[{'game': 'arena', 'face': 'good', 'tags': ['laggy']}]` (`'mode'` is left out: the player had no mode).

## Test counts

| Check | Before | After |
| --- | --- | --- |
| kit | 36 | 38 |
| metrics | 89 | 90 |
| protocol | 107 | 107 |
| connection | 295 | 295 |
| host | 117 | 117 |

## Self-check (review-rules.md part A)

1. **Every host setup.** `_publishFirstFrame` has no branch on host type: a TV/PC host and a phone on "Play on this
   phone" are the same `ServerGameHost` with `shareView` true, a phone on "Show on this device" has it false (its
   `publishFrame` keeps nothing, so no viewer ever gets a frame it shouldn't), and a joined phone is just the viewer
   that pairs. Test: 'a viewer that pairs during the beat gets view_start and the beat frame' (real `ServerGameHost`
   over an in-process link); the phone host's two modes are covered by `party_host`'s `ready_beat_test` (:77 with a
   viewer, :155 with none), still green in the `host` check. One build older: the wire is unchanged (same fields a
   step's frame already had), and -1 → 0 is a jump of one step, well under the 1.5-frame gap limit — `viewer_stats_test`
   'at 60 Hz a jump of more than 1.5 frames is a gap'.
2. **Kept state starts and ends.** `_firstFrameSent` starts at the first `paused = true` before step 0, ends the
   round (it can never fire after a step, `_stepCount != 0`), and a held round sends nothing more. Test: 'the round's
   first frame is sent even when no viewer has paired yet' plus 'a session that starts paused sends the round's first
   frame at once' (60 more drawn frames while held → still one frame). The host's kept frame (`_viewFrame`) starts at
   `startView` and ends at `endView` (connection tests unchanged).
3. **How a new state combines.** beat × no viewer and beat × a viewer pairing are the two new tests above; beat ×
   paused is 'nothing steps or is sent while paused' (frames length 1); beat × the pause menu, host away and player
   away are `party_host`'s `ready_beat_test:97`/`:116` and `away_card_test`, green in the `host` check. The one owner
   of the beat is still `Pausable` in `party_host`; this job only changes what the session publishes while held.
4. **Folder.** `git status` lists only the six files in `allow:` (plus the three `tv_test_app/windows/flutter/
   generated_*` line-ending rewrites the check tools make; `git diff --ignore-cr-at-eol` on them is empty).
5. **Stop rather than overstep.** Nothing needed a file outside `allow:` and the brief fitted the code; see Question
   2 about `docs/code-health.md`, which I left alone.

## Checks

- `tools/check.sh format analyze protocol kit metrics connection host`: **all PASS** — format; analyze;
  protocol 107 tests; connection 295; metrics 90; kit 38; host 117.
- `tools/review.sh`: **0 fail, 1 note** — `game_session.dart` 335 lines (aim 300, hard 400; it was 319 and already
  in code-health's "when touched" row).
- `dart format` run on the six changed Dart files; the format check passes.

## Questions and suggestions

1. `docs/code-health.md` isn't in this job's `allow:`, so N6 and N7 are still listed as "now" there; they are done
   with this commit and can move to its "Done" log.
2. The pairing test lives in `packages/game_kit/test/session_test.dart` and drives a real `HostServer` over an
   in-process link (no socket, no wall-clock assertions; only arrivals are awaited, with a 5 s timeout as the
   confusion tests use). The re-send it checks lives in `ServerGameHost._sendView`, and `packages/connection/test`
   wasn't in `allow:`; say if you'd rather have it there (or a shorter copy of it) next time.
3. The beat frame still has no marker of its own on the wire beyond `n: -1`; if a later change wants viewers to treat
   it differently (a countdown drawn over the board, no touch sample during it), a `beat` flag would be a protocol
   change — nothing done here.
4. If a player joins between the beat frame and the first step, their counters appear on the first step frame (when
   the round starts), not in the beat frame; that is the roster's normal update path and not tested separately.

## Commit message

fix(m12): the beat frame carries players and goes out with no viewer

- `_publishFirstFrame` builds the "Get ready" frame with the same code as a
  step's frame (`_frame`): the roster (`pl`) and the acks, so a joined phone
  draws its counters through the beat.
- It is published whether or not a viewer has paired, so the host keeps it as
  the latest frame and a viewer that pairs during the beat gets `view_start`
  and then it.
- `docs/protocol.md` and `FrameMessage.n`: `n` is -1 for that frame, then from
  0; frames stop while a round is paused; an older viewer reads -1 → 0 as no gap.
- A summary copies `ratings` like `rounds` and `games` (code-health N7).

## Status row

- **Build 4 fix F4 (the Get ready frame · its protocol row · the ratings copy):** done — the beat frame carries `pl`
  and `acks`, goes out with no viewer and reaches one that pairs during the beat, the wire and `FrameMessage.n` say
  so, and summaries copy `ratings`; open: code-health N6/N7 to move to Done, the connection-side home of the pairing
  test (Question 2).

## Delete

- none
