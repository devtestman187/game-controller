# systest (S1) report

Inline batch (no runner, no workers, no tracker work). Test-only: no product code changed. No user-facing change, so no release-notes draft.
Range: 904d7faf..3cbc2002 (tests) plus the closing docs commit.

## Added (12 tests, packages/party_host/test/systest/)
- systest_support.dart: one shared rig. openSystest builds a real HostServer + ServerGameHost, the night providers over the host's real roster, N real ControllerClient phones (addPhone), one old phone (addOldPhone: raw frames, lists layout and status, not Capability.choices), rejoin, and DiskPrefs (prefs kept in a JSON file in a real temp directory). Time is the widget-test fake clock (tester.pump), so 5 s votes and the 30 s grace cost no real waiting.
- night_vote_phones_test.dart (10): 3-phone, 3-round night to its end once per NightPicker (6: host, director, shuffle, playlist, rotating, vote; the vote mode votes every round and checks 3 votes); phone drops mid-vote (vote settles, night goes on); all phones leave (settles by chance, no hang); old phone votes with a B press next to 2 new phones (counts as card 2).
- night_grace_save_test.dart (3): back at 25 s resumes as the same player with the same number and points; still away at 29 s is held, at 31 s ends with AwayEnd.graceOver, night keeps a greyed row; night saved to a real temp dir, read back by a new host and container, resumed, played on (shuffle played list also came back), finished, and gone from disk on end.

## Deviations (for the plan)
- Helper lives in party_host/test/systest, not connection/test: the night, the vote and the picker are party_host code, and connection/test helpers cannot be imported from another package. It mirrors wire_phone.dart for the old phone (does not duplicate startHost: it needs the night providers).
- The grace test uses a WebSocket on localhost, because the in-process link is the host phone's own player and never keeps an away slot (m12 code health N5). Sockets need real I/O, so those tests also run tester.runAsync for 40 ms per step; the 25/29/31 s clock is fake.
- The "real temp dir" save goes through DiskPrefs (a SharedPreferences stand-in writing a JSON file), not the shared_preferences plugin: the plugin has no directory hook off-device. NightSave's JSON and the host restart are real; the plugin's own file is not covered (device test).
- A real old phone must list layout and status: the host only sends layouts to phones that list them, so an old phone with no capabilities at all never sees the vote labels (not a bug: such a phone is older than layout).

## Findings
No bug found; no product code touched. One mismatch: NightState.totals is empty at night start (players join at 0, seen in rows), so tests check the roster, not totals, at the start.

## Counts
Tests: 12 new, all pass (packages/party_host: flutter test test/systest, ~10 s). Own tool calls: about 40, one thumb-haiku context pack (7 calls). Lessons proposed: 0.

## proc-sweep
proc-sweep: 0 process(es) listed (0 orphaned flutter_tester/dart)

no background command of mine is still running
