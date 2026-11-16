job: M14 bugs14 b027: the sound engine dies silently after minutes on iPad and nothing restarts it (B-027)
pub: no
stop: after it. No change to what plays, volumes, the lifecycle restarts or the sound settings.
read: packages/party_host/lib/src/sound.dart (play, restart, _load, _applyLoop) · packages/party_host/lib/src/sound_loop.dart · packages/party_host/lib/src/loop_audio_engine.dart · packages/party_host/lib/src/sound_wish.dart · packages/party_host/test/sound_loop_protect_test.dart (fake engine pattern) · sound_restart_test.dart · controller_app/lib/src/host/host_screen.dart:43 · controller_app/lib/src/ui/joined_view.dart:89 · docs/review-rules.md
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job cannot be done; then say why under "Blocked".

Owner report (B-027, iPad): "after playing for several minutes, there is no more sound (music or sound effects). If I closed (minimized) the game and brought it back, the sound effects and music came back." Cause (triage, not measured on a device): the SoLoud engine dies and nothing detects it; only the app-lifecycle onShow calls restart(). play() only logs failures; the loop has no health check.

do:
1 New file packages/party_host/lib/src/sound_watchdog.dart: class SoundWatchdog with callbacks (active, wanted, paused, busy, pulse, restart), period 3 s (Timer.periodic via start()/dispose()), cooldown 5 s between restarts (injectable now). tick(): skip (and forget the last position) when not active, not wanted, paused or busy; else pulse null (no voice though a loop is wanted), invalid voice, or a position equal to the previous tick's = dead engine, so call restart(). failed(): a play() that threw restarts too (when active and not busy), same cooldown.
2 SoundLoop (sound_loop.dart): add `bool get paused`, `bool hasSource(String name)` and `({bool valid, Duration position})? get pulse` (null with no handle; valid false when the engine does not know the handle or throws). Keep behaviour otherwise.
3 SoLoudSoundPlayer (sound.dart): a late final _watchdog wired to the player: active = app lifecycle resumed or unknown (WidgetsBinding.instance.lifecycleState), wanted = status.ready && wish loop set && loop.hasSource, busy = _restarting != null, restart = existing restart() (keeps _restartAt resume position) with a log line. Start it after the first successful load; dispose it in dispose(); call _watchdog.failed() in play()'s catch.
4 Tests (NEW file packages/party_host/test/sound_watchdog_test.dart, fake LoopAudioEngine whose voice can die or freeze; each must fail on old code): a loop that keeps advancing is left alone; an invalid voice restarts; a frozen position restarts on the second look; nothing is judged while hidden, paused or restarting; a failed play restarts but not twice within the cooldown.
in the report: start `## Summary` (at most 30 lines): what changed, test counts you saw, decisions. State "Fixed, unverified: needs device check (iPad)". End with `## Hand-over`. Do not claim a test passes unless you ran it here.
self-check: docs/review-rules.md part A, items 1-5, one line each in the report with the test that shows it.
tests: new tests only in the NEW file above (the runner proves they fail on old code); no real timers left running.
rules: aim 80-120 turns · no lib file you touch ends over 380 lines · tests first · write only inside allow: · stage nothing · never git add -A · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m14/bugs14/b027-audio-watchdog-report.md · packages/party_host/lib/src/sound.dart · packages/party_host/lib/src/sound_loop.dart · packages/party_host/lib/src/sound_watchdog.dart · packages/party_host/test
check: format analyze host
report: docs/briefs/m14/bugs14/b027-audio-watchdog-report.md
