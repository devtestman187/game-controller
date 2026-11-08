# N9 triage: does the TV app crash when it can't save?

Read-only job. The only file changed is this report. All line numbers are from the code as it stands today (Nov 7, build 4).

## Q 1
**Answer.** Nothing writes a file between that controller's disconnect and the missing `Stats: session … saved` line, no write can be shown to have ended the process, and the app was most likely force-stopped by the smoke run rather than crashing.

- The one session write is `LiveStats._save` (live_stats.dart:244-252) → `SessionStore.save` (session_store.dart:32-41), whose write and rename (36-37) sit inside a `try` that logs at 39: its exception cannot reach the caller.
- It had not even run yet: a session ends after `sessionGap` = 2 min with nobody connected (live_stats.dart:46, 197) and checkpoints every 1 min (47, 220). Twelve seconds in, neither timer had fired, so **no save was attempted at all**. The saved line (236) comes only from `endSession` — the 2 min gap, or `dispose` (317) at a clean exit.
- The write that fails in that log is the pairings save (host_service.dart:135 → saved_pairings.dart:25-26), fired by the pairing at connect (host_connection.dart:369). A disconnect saves nothing: `markSeen` (host_connection.dart:381 → host_pairings.dart:162) only stamps a time and calls no callback.
- `Error saving preferences to disk: …` is shared_preferences_windows 2.4.1's own `print` inside its catch: the plugin swallowed the `PathAccessException`, so no Dart exception was raised. Had one been, Flutter reports an unhandled Future error (FlutterError.reportError) and the app goes on — it does not end the process.
- The one host write that *can* throw uncaught is the folder listing, session_store.dart:46-47 (`exists`/`list`), reached through `_refreshCounts` (live_stats.dart:301). It runs after line 236 and only when a session ends, so it explains neither symptom.
- The end: smoke stops the TV app it started (tools/smoke.sh:285 before the frames step, 117/455 at cleanup) through `Stop-Process` (tools/tv-dev.sh:130). `flutter run` prints `Lost connection to device.` for a killed app, and a killed process runs no `dispose` → `endSession`, which is why the saved line is missing. The simulated controller runs 12 s and logs "after 11 s" (tools/smoke.sh:72).

**Confidence.** likely — the file:line facts are sure; that the stop, not some other death, ended the app is inferred (I can't run the app here). The brief's "earlier logs show the saved line at this point" is not reproducible from this code: only the 2 min gap or a clean exit produce it.
**Fix.** None for a crash: none was shown. The real holes are Q 2's.
**Test.** Not applicable to a triage; a `disconnect` re-run on an ordinary PC (proof `sim+tv`) would settle it.
**Risk.** None: nothing was changed.

## Q 2
**Answer.** Exactly one host write catches and logs its failure; the rest drop the future or leave the catch to a screen.
- Caught and logged: the session file — session_store.dart:36-37 write+rename, catch 38, log 39 ("Stats: could not save the session: …"), plus the per-file read/decode (51-55).
- Not caught in the package: the listing, session_store.dart:46-47, reached from `_refreshCounts` (live_stats.dart:301), `uploadNow` (280) and `StatsService.sessions()` (stats_screen.dart:35, no catch); `folder.create` and `File.copy` in `exportAll` (session_store.dart:73, 76) — only the snackbar at stats_screen.dart:51 catches; host_log_export.dart:54 `writeAsString` via `exportLog` (host_service.dart:269-280) — only latency_screen.dart:75 catches; `dir.create` in `start` (live_stats.dart:150) is caught one level up at host_service.dart:220-223, which switches the whole stats service off instead.
- Preferences, unawaited and uncaught: host_service.dart:120 (host id); host_service.dart:135 → saved_pairings.dart:26, returned into a `void Function` (host_server.dart:72) so an error there is unhandled; live_stats.dart:158 (consent); providers.dart:324 (puzzle settings). live_stats.dart:291 is awaited inside a `try`/`finally` with **no catch** (278-297), so it escapes to the `unawaited(uploadNow())` calls at 153, 161, 241.
- Swallowed reads with no line saying why: saved_pairings.dart:18 `catch (_)` (the whole pairings list is silently dropped), providers.dart:317 `catch (_)` (settings fall back to defaults). screen_awake.dart:18 is documented.
**Confidence.** sure — read from the code.
**Fix.** The same storage boundary as Q 3.
**Test.** The fake in Q 3, one case per write listed above.
**Risk.** See Q 3.

## Q 3
**Answer.** One storage boundary: catch it there, log once through the `LogSink` in the existing "Stats: …" wording, turn it into a value the caller handles, and let the host play on.
- session_store.dart: treat 46-47 and 73/76 like 36-37 — narrow catches (`on FileSystemException`), one log line, `const []` for a listing, and for `exportAll` either a failed result the screen shows or a small `StatsStorageError` the existing catch at stats_screen.dart:51 handles.
- live_stats.dart: catch `dir.create` at 150 here, log, keep `_directory` null so checkpoints no-op, instead of losing the whole service at host_service.dart:222; route 158 and 291 through one catching helper; add a `catch` to 278-297 that logs and sets `lastError`.
- Preferences: one helper, `savePrefs(LogSink log, String what, Future<bool> Function() write)`, used by host_service.dart:120 and 135 and providers.dart:324.
- What a person sees: nothing for a checkpoint or a session end — the Stats screen simply shows fewer saved sessions. The adult's buttons keep their snackbars ("Could not export", "Could not save the log") but in plain words ("Couldn't save the files. Check the disk and try again.", §7) instead of the raw OS text. A child sees nothing.
**Confidence.** sure on the holes; guess on the shape — the store seam and the error type are your call.
**Fix.** session_store.dart:32-80; live_stats.dart:149-154, 156-162, 278-297; host_service.dart:117-121, 135, 269-280; saved_pairings.dart:11-26; providers.dart:314-325; possibly a `storageError` field in stats_state.dart and the text at stats_screen.dart:52.
**Test.** First, and failing: a storage fake that throws. `SessionStore` is built inside `LiveStats` (live_stats.dart:58), so inject it (`LiveStats({SessionStore? files})`; the two construction sites are host_service.dart:141 and live_stats_test.dart:64). New case in live_stats_test.dart — "a session whose file can't be saved is logged once and the host plays on": a store whose `save` throws, one phone joins and leaves, `sessionGap: 400 ms` (test line 67) → exactly 1 "could not save the session" line, `stats.state.saved == 0`, and a second phone still starts a session (`stats.session != null`). It fails today at the uncaught listing (session_store.dart:47) through `_refreshCounts` (live_stats.dart:301). A cheaper case needing no seam, in a new test/session_store_test.dart: precreate `Directory('<dir>/s.json.tmp')` (the store writes `$path.tmp` first, 35-36), then `save('<dir>/s.json', {'schema': 1})` must not throw and logs 1 line — it passes today and guards the fix.
**Risk.** A wider catch would hide real bugs (`jsonEncode`, a broken summary) — keep it to the IO boundary; `_save` sets `lastSaved` (live_stats.dart:250) even when the write failed, so Diagnostics can show a summary that is not on disk; catching `create` inside `start` changes the "Stats are off" behaviour (host_service.dart:222); the seam touches both construction sites and any fake.

## Notes, questions, suggestions
1. The brief's message "Couldn't save the stats: …" repeats the sink's own tag (`log.sink('stats')`, host_service.dart:149 → "[stats] …"); keeping "Stats: could not save the session: …" reads better. Your call.
2. A failed checkpoint would log one line per minute for a whole session; log the first and count the rest, or once per session?
3. I could not open the pub cache here to quote shared_preferences_windows 2.4.1's catch; the log text ("Error saving preferences to disk: …") is that plugin's own message, so the swallow is very likely.
4. Per docs/dev-tools.md the `disconnect` step is skipped on this PC; the owner's device test, or a run from an ordinary terminal, is what proves the host survives.
5. `_save` (live_stats.dart:250) records `lastSaved` before the write is known to succeed — should a failed write leave the last summary in the state?

## Commit message
```
Report N9 triage: the TV app does not crash on a failed save

Findings only; no code changed. The session write is already caught and
logged (session_store.dart:38); it cannot end the host, and in the Nov 7
20:43 log no save had even been attempted: a session ends 2 min after the
last phone and the app was force-stopped at 12 s (tv-dev.sh:130), which is
what prints "Lost connection to device". The uncaught paths are the folder
listing (session_store.dart:46-47), export create/copy (73, 76) and the
unawaited preferences writes (host_service.dart:120, 135, providers.dart:324).
```

## Status row
- **N9** (the TV app, storage): triaged — no evidence the host crashes on a failed save; the file write is already caught and the log's ending is the harness's stop. Open: the uncaught listing/export/prefs paths (Q 2, Q 3), the store seam and its failing test, and a `disconnect` re-run on an ordinary PC.

## Delete
- none
