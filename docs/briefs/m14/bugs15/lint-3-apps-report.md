## Summary

`dart analyze packages/metrics controller_app tv_test_app` prints **No issues found!** (started from 55 issues).

| kind | count | where |
| --- | --- | --- |
| `strict_raw_type` | 28 | 14 in `packages/metrics/lib/src` (report, report_games, report_players, report_rounds), 14 in its tests |
| `discarded_futures` | 15 | controller_app 13 (discovery 1, host_screen 1, profile 3, storage 4, controller_screen 4), tv_test_app 2 |
| `inference_failure_on_collection_literal` | 8 | metrics tests (empty `[]` / `{}` in summary literals) |
| `only_throw_errors` | 2 | controller_app `haptics.dart` (the `FakeHaptics` hook) |
| `unused_shown_name` | 1 | controller_app `test/support/pixels.dart` |
| `unused_field` | 1 | tv_test_app `latency_screen.dart` (`_badgeDiameter`) |
| **total** | **55** | |

Possible real bugs (details and lines below): the `FakeHaptics` throw is unchanged for every value the tests use; every
new `unawaited` is a call that was already fire-and-forget, so nothing new can be lost — the ones whose failure would
be silent are the four `SharedPreferences` writers (storage, profile), `discovery.restart` (no internal catch), the
`host.disposed.then` without `onError`, and the two shader/consent loads. None of them changed behaviour.

Tests (run in this job, after the change): metrics 162 passed; controller_app 505 passed; tv_test_app 54 passed,
1 skipped. `tools/check.sh format` PASS; `tools/check.sh metrics phone tv` PASS.

Repo-wide `tools/check.sh analyze` still FAILs, on packages outside this job's `allow:` (connection 19, party_host 9,
protocol 5, puzzle_game 5, test_game 1, toy_look 1 = 40 issues). The three packages of this job are clean.

## Decisions

1. **`Map<Object?, Object?>` for the values read out of a summary record**, not `Map<String, Object?>`. The summaries
   come from `jsonDecode` (string keys) *and* from test literals, where an empty `{}` is a `Map<dynamic, dynamic>` at
   runtime; `as Map<String, Object?>` would throw on those, which the brief forbids ("do not throw where the code did
   not"). `Map<Object?, Object?>` accepts both, and matches the style already used for external maps
   (`device_status.dart`, `haptics.dart`). The only cast added is in tests, where the values come from a
   `SessionCollector` that writes `Map<String, Object?>`.
2. **Test helpers** return the map types they actually produce: `Map<String, Object?>` / `List<Map<String, Object?>>`,
   with `.cast<String, Object?>()` where the source is a hand-built literal (csv_build tests) and `as Map<String,
   Object?>` where a summary from the collector is read.
3. **Empty literals** got the argument that describes the cell: `<Object?>[]` for lists the report only filters
   (`ratings`, `switches`, `tags`), `<String, Object?>{}` for the empty `games` map.
4. **`only_throw_errors` in `FakeHaptics`**: kept the public `Object? failWith` field and made the throw
   `throw error is Exception ? error : Exception('$error')`. Every value the two tests set (`PlatformException`,
   `Exception`) is an `Exception`, so the same object is still thrown; only a non-Exception value (none today) is
   wrapped, with its text kept. Changing the field to `Exception?` would have been a public-API change.
5. **`unused_field` in `latency_screen.dart`**: deleted `_badgeDiameter` and its comment. The badge is `ToyBadge`,
   which sizes itself from the look, so the constant was a leftover, not a value the layout wanted.
6. **`pixels.dart`**: dropped `ImageByteFormat` from the `dart:ui` show list; nothing in the file names it.
7. No `// ignore` comment was added, no text or public API changed, no other package touched.

## Possible real bugs (fire-and-forget futures, behaviour unchanged)

1. `controller_app/lib/src/storage.dart:36` — the controller ID is generated and written `unawaited`. A failed write
   is invisible; the ID stays in the in-memory cache for this run, but the next launch allocates a new one and the TV
   sees a new phone (its per-host tokens no longer match it).
2. `controller_app/lib/src/storage.dart:104` — `setToken` writes the join token fire-and-forget. A lost write means the
   phone rejoins without the token the TV issued.
3. `controller_app/lib/src/storage.dart:119,121` — `lastHost` setter: a lost write only costs the "last host" shortcut.
4. `controller_app/lib/src/profile.dart:36,38,40` — the nickname and character are saved fire-and-forget; if the app
   dies before the write flushes, the next launch shows the old profile, with no message to the player.
5. `controller_app/lib/src/ui/controller_screen.dart:116,138` — `discovery.restart()` (`discovery.dart:146`) awaits
   `stop()` then `start()` and catches nothing; a throw from `start()` is an unhandled async error and the search
   silently does not happen. Ordering matters only inside `restart` itself, which is unchanged.
6. `controller_app/lib/src/ui/controller_screen.dart:121` — `gyro.resume()` releases the tilt hold; if it throws, the
   error is unhandled and tilt input could stay paused after the app comes back.
7. `controller_app/lib/src/ui/controller_screen.dart:154`, `tv_test_app/.../first_launch_consent.dart:21` — the rating
   prompt and the consent prompt are dialogs whose failure would be unhandled and leave no prompt; no ordering.
8. `controller_app/lib/src/host/host_screen.dart:35` — `host.disposed.then(...)` has no `onError`: if `disposed` ever
   completes with an error, the route is not popped and the error goes to the zone.
9. `tv_test_app/lib/src/ui/shader_spike_screen.dart:63` — a failed `ToyShaders.load()` leaves `_shaders` null (the
   fallback drawing) and the error unhandled; the screen keeps working but says nothing.
10. `controller_app/lib/src/discovery.dart:165` — `service.resolve(...)` already had `.catchError` logging the failure;
    `unawaited` only records the intent.

Nothing was changed beyond `unawaited`, as the brief asked.

## Checks run in this job

- `dart analyze packages/metrics controller_app tv_test_app` → No issues found.
- `dart test` in `packages/metrics` → 162 passed.
- `flutter test` in `controller_app` → 505 passed.
- `flutter test` in `tv_test_app` → 54 passed, 1 skipped.
- `tools/check.sh format analyze metrics phone tv` → format, metrics, phone, tv PASS; analyze FAIL (40 issues in
  connection 19, party_host 9, protocol 5, puzzle_game 5, test_game 1, toy_look 1 — all outside `allow:`).
- `tools/review.sh` → 0 fail, 4 note (the notes are pre-existing long functions and the 312-line
  `shader_spike_screen.dart`; none is a line this job added).
- Longest file touched: `packages/metrics/lib/src/report_games.dart` 297 lines, `shader_spike_screen.dart` 312,
  `report.dart` 300 — all under 400, none grown past 380.

## Self-check (docs/review-rules.md part A, items 1-5)

1. **Every host setup** — not affected: no message, screen flow or timing changed; the diff is type annotations,
   `unawaited` wrappers and one dead constant. Tested by the full phone (505) and tv (54) suites.
2. **When kept state starts and ends** — the only state touched is saved preferences (`storage`, `profile`) and the
   discovery search; their lifetimes are unchanged, the writes were already fire-and-forget.
3. **How a new state combines with the others** — no new state, flag or timer; no pause/lock interaction changed.
4. **Stay in the job's folder** — every write is inside `allow:` (metrics, controller_app, tv_test_app, this report).
   `docs/code-health.md` was left alone: nothing in these packages is left open.
5. **Stop rather than overstep** — the repo-wide `analyze` needs packages outside `allow:`; I did not touch them and
   report it instead (see the STATUS row and question 1).

## Hand-over

The three packages are lint-clean with the strict settings; the remaining 40 repo-wide issues are in connection,
party_host, protocol, puzzle_game, test_game and toy_look and need their own job. `docs/code-health.md` needs no
entry from this job. Nothing here should be reverted piecemeal: the test-helper type arguments and the lib map types
went in together and `dart analyze` is the gate.

## Commit message

```
lint: clear the strict-lint issues in metrics, phone and TV apps

Give the raw maps read out of a session summary explicit type arguments
(`Map<Object?, Object?>`: the values come from JSON and from test literals, so a
narrower cast could throw where the code did not), and the same for the test
helpers and empty literals.
Wrap the fire-and-forget futures that were already discarded in `unawaited`
(preferences writes, discovery restarts, the host's disposed listener, the
consent and rating prompts, the shader load) — behaviour unchanged.
Throw through the FakeHaptics hook as an Exception, keeping the object the
tests pass, and drop two dead declarations. `dart analyze` is clean for the
three packages; the tests are unchanged and pass.
```

## Status row

M14 bugs15 lint-3-apps: metrics, controller_app and tv_test_app are clean under the strict lints (55 issues fixed,
metrics 162 / phone 505 / tv 54+1 tests pass); open: the 40 repo-wide analyzer issues in connection, party_host,
protocol, puzzle_game, test_game and toy_look, for their own jobs.

## Delete

- none
