# b019-3-fix-core report: three LiveStats review fixes (B-019)

## Summary

`packages/party_host/lib/src/live_stats.dart` (360 → 377 lines, cap 380):

- Finding 3: `resume()` now awaits `uploadNow()` and then calls `_checkPlayers()`, so a
  player who stayed paired through `pause()` gets a session again, with no join or leave.
- Finding 5: a `bool _disposed` field, set at the end of `dispose()`. `uploadNow()` returns
  early when it is set and arms the retry timer only when it is not, so an upload that fails
  after `dispose()` cannot leave a timer (or a retry) behind. `_checkPlayers()` returns early
  on it too, so nothing new starts after dispose.
- Finding 8: `endSession()` clears `_ending` and `current` only when `identical(_ending, s)`,
  i.e. when the session it saved is still the ending one. A session that starts and ends while
  an older one is being written keeps its own `current` summary and stays the ending one.
- The retry interval moved from an inline `Duration(minutes: 5)` to a named `_retryInterval`
  documented with its PRD ID; the value is unchanged.

`packages/party_host/test/live_stats_fixes_test.dart` (new, 283 lines): one test per finding,
written first and each seen failing on the old code.

- Test (a) on the old code: after `pause()` then `resume()`, `stats.session` was null —
  `Expected: not null / Actual: <null>` at "the own player is still here, so resume() starts a
  new session". Passes with the fix.
- Test (b) on the old code: after `dispose()`, the upload started by its end failed and armed a
  retry — `Expected: empty / Actual: [Timer (duration: 0:05:00.000000)]` at "no timer outlives
  dispose()". Passes with the fix.
- Test (c) on the old code (unconditional clear restored temporarily): the older save's
  captured `current` was `null` — `Expected: '3d962977ad24ff6d' / Actual: <null>` at "the
  summary of the session that is still being written stays when the older save lands". Passes
  with the fix.

Checks: `tools/check.sh format analyze host` — PASS format, PASS analyze, PASS host
(462 tests, 49 s) after the final edit; re-run after the last comment trims: PASS format,
PASS analyze, PASS host (462 tests, 57 s).

One run in between failed a test this job does not touch: `live_stats_lifecycle_test.dart`'s
`pause() ends and saves the session…` threw `PathNotFoundException` listing its own
`tp-stats-life-…/sessions` folder. The file passes alone (5 tests) and the suite passed on the
re-run, with no code change in between, so it is a flake in that test's temp folder, not this
diff (the save path is untouched here; see question 4).

Decisions: see the section below.

## Files changed

- `packages/party_host/lib/src/live_stats.dart` — the three fixes above, the `_disposed` field,
  and the named retry interval.
- `packages/party_host/test/live_stats_fixes_test.dart` — new file, three tests (a), (b), (c).
- `docs/briefs/m14/bugs10/b019-3-fix-core-report.md` — this report.

## The three fixes, one by one

### Fix 3: `resume()` starts a session again

```dart
@override
Future<void> resume() async {
  await uploadNow();
  _checkPlayers();
}
```

`pause()` ends the session, so a player who stays paired across a pause has no session when
the host comes back, and nothing calls `_checkPlayers()` until the next presence change. The
own player is present in `host.players` throughout, so the check starts a session for them.
The doc comment says why the call is there so it is not dropped as redundant later.

### Fix 5: nothing is scheduled after `dispose()`

- `bool _disposed = false;` (documented, "Set by dispose: nothing new may start or be
  scheduled after it (B-019)").
- `uploadNow()`: `if (_disposed || up == null || ...) return;` and the retry arming is
  `if (!_disposed) _retry = Timer(_retryInterval, ...);`.
- `dispose()` cancels `_pingTimer` and `_retry`, then sets `_disposed`, then awaits
  `_changes.close()`.
- `_checkPlayers()` starts with `if (_disposed) return;`, so a stream event that arrives while
  `dispose()` is awaiting cannot start a session either.

`dispose()` still awaits the upload it starts, so a failure there is still reported in
`state.lastError`; it is only its follow-up that is now dropped. Setting the flag after the
cancels keeps the cancel and the guard on one code path: the flag is the reason there is
nothing to re-arm.

### Fix 8: a newer ending session keeps its summary

```dart
if (identical(_ending, s)) {
  _ending = null;
  _set(_state.copyWith(current: null));
}
```

`endSession()` sets `_ending`, saves (an await that lets the next session start and end), then
clears. Clearing unconditionally dropped the newer session's summary and its `_ending`, so
`stats.session` (which is `_session ?? _ending`) returned null for a session that was still
being saved. The identity check asks the exact question: is the ending I saved still the one
that is ending now?

## Computed test values

Setup shared by the three tests: a real `HostServer` + `ServerGameHost` on a temp folder, a fake
clock (`DateTime(2026, 11, 15, 10, 30)`), `sessionGap = 400 ms`, heartbeats at
`_quietLink = Duration(minutes: 1)` so no pong-driven presence event restarts a session between
an assertion and the call under test. Presence changes come only from the call each test checks.

- (a) resume: one session before the pause, id `paused`; after `pause()` `stats.session` is
  null; after `resume()` a session exists with id != `paused`; its summary has
  `players.length == 1`, that entry `install == 'own-player'` and `watched == 'host_phone'`;
  `server.snapshot.connected.length == 1` (the link never dropped, so no join or leave).
- (b) dispose + failing upload: the gated uploader is offered exactly 1 upload (the ended
  session), its failure is reported as `lastError == 'offline'`, and of every `Timer` created
  between the start of `dispose()` and the failure, 0 are still active. On the old code that
  count was 1 (the 5-minute retry).
- (c) save order: up to 10 session pairs per run; each pair starts a session, ends it, starts
  the next while the first save is pending, and ends that. Watched at the moment each save is
  logged, `current` must still be the newer session's id when the older file lands first.
  Expected value: the newer session's id, e.g. `'3d962977ad24ff6d'`; old code: `null`. The test
  asserts on the first attempt whose save order is older-first and fails if none of the 10
  attempts has that order, so a silent skip cannot pass.

## Decisions (low-usage mode)

1. Named the retry interval `_retryInterval` (`Duration(minutes: 5)`, PRD v2 T19) instead of
   leaving the literal in `uploadNow()` — guidelines: no magic numbers.
2. `_disposed` guards both the retry arming and `_checkPlayers()` — a disposed `LiveStats` must
   neither start a session nor schedule work; the two are the same promise.
3. `dispose()` sets `_disposed` after the cancels and before `await _changes.close()`, so the
   upload it already started may still fail and report, but nothing after it can re-arm.
4. Fix 8 uses `identical` rather than an id comparison: the question is whether the object
   saved is still the ending one, and `SessionCollector` ids are unique per session.
5. Test (c) repeats the session pair up to 10 times instead of trying to force one write order.
   The two files are written with independent I/O and finish in whichever order the disk gives;
   the bug is only visible when the older lands first, so the test looks for that order and
   fails loudly if it never comes up in 10 tries. See question 1 for the alternative.
6. The tests run the server's heartbeats at 1 minute. A pong reaches `HostServer` as a change,
   which re-runs `_checkPlayers()` and would restart sessions between an assertion and the call
   under test; with it quiet, the only presence changes are the ones each test makes.
7. `settle()` (four zero-delay event-loop turns) before pausing in test (a), because a session
   start arrives through a broadcast stream and needs a turn to reach `LiveStats`.

## Self-check (review-rules part A, one line each with its test)

- Every host setup: yes — all three tests build a real `HostServer`/`ServerGameHost` through
  `startStats()` and register `addTearDown` for `dispose()` and the folder; test (b) itself
  proves dispose is exercised.
- When kept state starts and ends: `_disposed` starts false and becomes true once, in
  `dispose()` — test (b); `_ending` is set by `endSession()` and cleared only when it is still
  the saved session — test (c).
- How a new state combines with the others: `_disposed` short-circuits `_checkPlayers()` (no
  new session) and the retry arming (no new timer); test (b) covers the timer half, test (a)
  runs the same path with the flag false and still gets its session.
- Your folder only: the diff is `live_stats.dart`, the new test file and this report.
- Stop rather than overstep: REVIEW finding 9 (the file is over ~300 lines and wants a split)
  and the host-suite evidence gaps from the run review were left for their own jobs.

## Questions and suggestions

1. Is case (c) acceptable as a bounded loop? The literal "starts and ends during the write"
   window cannot be selected from outside: `_saveSession` describes the path and
   `SessionStore.save` does the write, and on Windows the two writes finish in either order
   (both orders observed across runs). The alternative is to inject the store into `LiveStats`
   (a `SessionStore` constructor parameter, as `nowMs` already is), which makes the test single
   attempt and exact but adds a seam to the shipped class. Say which you prefer and it is a
   small follow-up.
2. `live_stats.dart` is 377 lines, under this brief's 380 but over the guidelines' ~300 and
   REVIEW finding 9. Splitting it was out of scope here; the natural seam is the save/upload
   half (`_saveSession`, `uploadNow`, `_refreshCounts`).
3. The fix for 5 also quiets `_checkPlayers()` after dispose, which the brief only asked for on
   the retry path. It is the same "nothing after dispose" rule and covered by test (b)'s
   folder; if you want the flag to guard only the timer, that is a one-line revert.
4. The one failing run (Summary) hit `live_stats_lifecycle_test.dart`, which this job does not
   allow me to change, so it was left as observed: the file passes alone and the suite passes on
   re-run. If `Directory.list()` on a just-written temp folder turns out to be racy on Windows,
   that test wants the same retry `deleteTempFolder` has; that is its own job.

## Hand-over

- Reviewer: the three tests are the evidence; run
  `flutter test packages/party_host/test/live_stats_fixes_test.dart` from `packages/party_host`.
  To see them fail, revert each fix alone: drop `_checkPlayers()` from `resume()`, drop the
  `if (!_disposed)` around the retry arming, drop the `identical(_ending, s)` guard.
- The file is 377 lines, so the next change to it should expect to split it.
- Test (c)'s loop prints nothing on success; if it ever says "one attempt wrote the older file
  first", the write order is not being exercised on that machine and the loop bound needs a look.

## Commit message

Fix LiveStats resume, retry after dispose and save race (B-019)

resume() runs the presence check after uploadNow, so a player who stayed
paired through pause() gets a session again. dispose() sets a disposed flag,
and a failing uploadNow no longer arms a retry after it; _checkPlayers()
stops too. endSession clears current and _ending only when _ending is still
the session it saved. Adds live_stats_fixes_test.dart, one test per fix.

## Status row

Bugs10 b019-3-fix-core done: LiveStats resume/dispose/save fixes (B-019) with three tests seen failing on the old code then passing, host suite 462 green; open: live_stats.dart is 377 lines and wants the split from REVIEW finding 9.

## Delete

- none
