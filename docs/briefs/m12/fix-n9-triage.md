job: m12 build 4 triage N9 — does the TV app crash when it can't save; read-only
stop: after the triage. Change no file but the report; fix nothing. Write only inside this job's folder.
read: docs/code-health.md N9 · docs/dev-tools.md ("When the app's log is silent") · packages/party_host/lib/src/{live_stats,session_recorder,host_service,saved_pairings}.dart and every other place the host writes a file or the preferences (find them) · packages/metrics (where a session is saved) · tv_test_app/lib and controller_app/lib/src/host (the storage adapters) · docs/coding-guidelines.md §2 (swallowed errors) and §7

the evidence: from Claude's shell the TV app can't write to the user's AppData. Log of the Nov 7 20:43 smoke run: `Smoke controller connected (pairing code), player 1` · `Error saving preferences to disk: PathAccessException: … shared_preferences.json (OS Error: Access is denied, errno = 5)` · the app keeps running · 12 s later, at the disconnect: `Session of Smoke controller ended after 11 s …` (twice) · `[tv] The screen may sleep again` · `Lost connection to device.` (the app process ended). Earlier logs show `[stats] Stats: session … saved (…)` at this point; it never came.

questions:
1 What writes a file between a controller's disconnect and the stats' "saved" line (the session summary, a stats file, pairings, preferences), and does an exception from it escape: file:line of each write and of the nearest catch, or none. Which one most likely ended the process?
2 Every other host write (on pairing, on settings, on a round's end, on stop): which catch and log a failure (guidelines §2), which don't.
3 The fix: every host write caught at the storage boundary, logged once through `LogSink` ("Couldn't save the stats: …"), and the app goes on; what the player sees, if anything. Files, lines, the failing test you'd write first (a storage fake that throws), and what it could break.
format: `## Q N` with Answer, Confidence (sure / likely / guess), Fix, Test, Risk. At most 60 lines.
allow: docs/briefs/m12/fix-n9-triage-report.md
check:
report: docs/briefs/m12/fix-n9-triage-report.md
