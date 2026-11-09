# M13 step 7: sound (lobby music, the countdown, player joined, volume and music)

Job: `docs/briefs/m13/s7-sound.md`. Gate: the whole step ("stop: after it"). **Status: done.**

## What the step now does

The three cues are in `SoundKey` and credited. `SoundPlayer` gained `playLoop`/`stopLoop`, `stop(name)` and
a master `volume`; `SoLoudSoundPlayer` keeps what it was asked for in a pure `SoundWish` (one loop, one
volume) and carries it out at the end of every load, so a loop or volume wanted before the sounds are in, or
across an iOS restart, comes back. `SoundSettings` (volume 80%, music on) saves through `lookPrefsProvider`
under `sound.volume`/`sound.music`, and `soundPlayerProvider` applies it with `ref.listen(...,
fireImmediately: true)` — `percent / 100` — so it follows the player on the TV, the Windows app, the host
phone and a joined phone. `LookAndSoundSection` shows Sound volume (slider, 10 steps of 10, "80%" beside the
label) and Music. A `LobbyMusic` controller counts open lobbies and open rounds through `LobbyHold` (the game
picker's body) and `RoundHold` (Shape Race and the Arena screen), wants the loop while a lobby is open, no
round is, Music is on and the app is shown, settles after the frame, and calls `playLoop('lobby')` or
`stopLoop()` only when that wanted state changed. `Pausable` plays the countdown as its beat starts from the
top and stops it when the beat is held or ends early; the TV asks for no beat so it has no countdown, as the
class doc now says. `playerJoinedProvider` plays `player_joined` once per new non-local player.

## Test counts

| suite | before | after |
| --- | --- | --- |
| kit | 48 | 48 |
| host | 206 | 233 |
| phone | 405 | 408 |
| tv | 51 passed, 1 skipped | 52 passed, 1 skipped |

Thirty-one new tests:

- host 27: `sound_wish_test` 5, `sound_settings_test` 6, `sound_keys_test` 2, `lobby_music_test` 5,
  `countdown_test` 3, `player_joined_test` 4, `look_and_sound_test` 2 more.
- phone 3: `controller_app/test/sound_test.dart` 3.
- tv 1: `tv_test_app/test/sound_test.dart` 1.

look, puzzle and arena are unchanged and not in this job's check command; nothing in their folders changed.

## Files changed

New:
- `packages/party_host/lib/src/sound_wish.dart` — the pure "wanted" state (loop name, volume, clamped), with `stopsFrom`/`startsFrom` so the same loop asked again never restarts.
- `packages/party_host/lib/src/sound_settings.dart` — `SoundSettings` (default 80/on, `maxVolume` 100, `stepPercent` 10) and `soundSettingsProvider` with `setVolume`/`setMusic`, saved through `lookPrefsProvider` under `sound.volume`/`sound.music`, read back clamped.
- `packages/party_host/lib/src/prefs.dart` — `prefsProvider` moved out of `providers.dart`, so `sound_settings.dart` can save through the look's prefs without `providers.dart` and `look_providers.dart` importing each other. Same provider, same override points.
- `packages/party_host/lib/src/ui/lobby_music.dart` — `LobbyMusic` (`openLobby`/`closeLobby`/`openRound`/`closeRound`, `isWanted`, `settle` after the frame, `AppLifecycleListener`) and `lobbyMusicProvider`.
- `packages/party_host/lib/src/ui/lobby_music_widgets.dart` — `LobbyHold` and `RoundHold`, which open and close a hold while mounted.
- `packages/party_host/test/sound_wish_test.dart` — loop started once and not restarted, another loop stops the old one, restart starts the wanted loop and keeps the volume, clamping, and the real player keeping a volume with no engine.
- `packages/party_host/test/sound_settings_test.dart` — defaults, saved read back, 140 → 100 saved and on set, -5 → 0, both keys written, a new scope reads back; the volume reaching the real player (0.8 at creation, 0.3 at 30%, 0.3 from saved 30).
- `packages/party_host/test/sound_keys_test.dart` — `byEventName('player_joined')` (and `lobby`, `countdown`), and the three files exist beside `soundFiles`' paths.
- `packages/party_host/test/lobby_music_test.dart` — picker starts once and the join screen keeps it, a round stops it (Play again keeps it off, Change teams starts it again: `loopStarts == ['lobby', 'lobby']`), Music off/on, hidden/resumed, two changes in one frame make no start.
- `packages/party_host/test/countdown_test.dart` — once as the card shows 3 and still once at the beat's end; the away hold stops it (in `stopped` after 120 ms) and the beat over plays it again (2); the TV's round plays none.
- `packages/party_host/test/player_joined_test.dart` — a join plays once, away and back nothing, the local player nothing, two phones twice.
- `controller_app/test/sound_test.dart` — the host phone's picker plays the loop once; a joined phone's waiting and pad screens never do; Settings shows both rows and their strings.
- `tv_test_app/test/sound_test.dart` — a new phone on the TV home plays `player_joined`.
- `docs/briefs/m13/s7-sound-report.md` — this report.

Changed:
- `assets/lib/asset_manifest.dart` — `SoundKey` gains `lobby`, `countdown`, `playerJoined('player_joined')`; the enum doc names them as the host's own cues.
- `assets/CREDITS.md` — three audio rows, and the Audio paragraph names the host's cues.
- `tools/audio/README.md` — the "not used yet" line replaced by where the three cues play, their lengths and their shape; the duration check lists them.
- `packages/party_host/lib/party_host.dart` — exports `prefs.dart`, `sound_settings.dart`, `sound_wish.dart`, `ui/lobby_music.dart`.
- `packages/party_host/lib/src/providers.dart` — `prefsProvider` gone to `prefs.dart`; `playerJoinedProvider` added; `soundPlayerProvider` applies the volume (`ref.listen(soundSettingsProvider.select((s) => s.volume), ..., fireImmediately: true)`).
- `packages/party_host/lib/src/look_providers.dart` — imports `prefs.dart`.
- `packages/party_host/lib/src/sound.dart` — `playLoop`, `stopLoop`, `stop`, `volume` on the interface; `SoLoudSoundPlayer` keeps them in `_wish`, applies the volume and loop at the end of a load, stops the old loop before another, and guards every engine call as before.
- `packages/party_host/lib/src/testing/adapter_fakes.dart` — `FakeSoundPlayer` records `loop`, `loopStarts`, `stopped`, `volume`; `playLoop` of the name already looping is no start.
- `packages/party_host/lib/src/text/host_text.dart` — `soundVolume`, `music`, `musicLine`, and `percent`.
- `packages/party_host/lib/src/ui/look_and_sound_section.dart` — the rows split into `_LookRows` and `_SoundRows` (the `build` was over 60 lines); the volume slider (key `soundVolume`) and the Music switch (key `soundMusic`); the doc says which rows take focus and that left/right move the slider.
- `packages/party_host/lib/src/ui/games_screen.dart` — body wrapped in `LobbyHold`.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` — wrapped in `RoundHold` above its `ToyStillSky`.
- `packages/party_host/lib/src/ui/game_screen.dart` — wrapped in `RoundHold` above its `ToyStillSky`.
- `packages/party_host/lib/src/ui/pause_menu.dart` — `_countdownOn`/`_sound`, `_startCountdown`/`_stopCountdown` called from `_beat` (top of the beat, held, results, dispose), and the doc paragraph on which rounds play it.
- `packages/party_host/test/look_and_sound_test.dart` — both rows in Sunny and Night, the slider stepping 80 → 90 → 80 by arrow keys and saving, the Music switch saving.
- `packages/party_host/test/support/host_harness.dart` — `StubHome` watches `playerJoinedProvider`, as the real home does.
- `controller_app/lib/src/host/host_screen.dart` — the phone host watches `playerJoinedProvider` beside `gameSoundsProvider`.
- `tv_test_app/lib/src/ui/home/home_screen.dart` — the TV home watches `playerJoinedProvider` beside `gameSoundsProvider`.

Not mine (already in the working tree when the job started, outside `allow:`):
- `assets/audio/lobby.ogg`, `assets/audio/countdown.ogg`, `assets/audio/player_joined.ogg` — the brief's three cues, copied in by Claude (untracked in git; they belong in this change's commit).
- `tv_test_app/windows/flutter/generated_plugins.cmake`, `generated_plugin_registrant.cc`, `.h` — shown as modified by `git status`, but `git diff --numstat` is empty: line endings only, from Flutter tooling before the job. I did not edit them and can't restore them (no destructive git).
- `docs/briefs/m13/s7-sound.md` — the brief itself (untracked).

## The screens holding the wraps

- `LobbyHold` — `GamesScreen`'s body (`games_screen.dart`), so the game picker, the join screen, the Shape
  Race list, puzzle settings, stats and settings all count as one lobby.
- `RoundHold` — `PuzzleScreen` (`puzzle_screen.dart`) and `GameScreen` (`game_screen.dart`), each directly
  outside its `ToyStillSky`, so the results and the pause menu are still "a round is on".

## Every place a sound is now played from

- `packages/party_host/lib/src/providers.dart:221` — `gameSoundsProvider` hands each game event to `player.play(name)` (unchanged; now also on a joined phone at its own volume).
- `packages/party_host/lib/src/providers.dart:239` — `playerJoinedProvider` plays `player_joined` for each new non-local player.
- `packages/party_host/lib/src/providers.dart:289-293` — `soundPlayerProvider` sets `player.volume = percent / SoundSettings.maxVolume` (not a play; listed because it is where the volume is applied).
- `packages/party_host/lib/src/ui/lobby_music.dart:115` — `LobbyMusic._apply` starts the loop: `playLoop('lobby')`.
- `packages/party_host/lib/src/ui/lobby_music.dart:117` — and stops it: `stopLoop()`.
- `packages/party_host/lib/src/ui/pause_menu.dart:224` — `Pausable._startCountdown` plays `countdown` as the beat starts from the top.
- `packages/party_host/lib/src/ui/pause_menu.dart:232` — `Pausable._stopCountdown` stops it when the beat is held or ends early.
- `controller_app/lib/src/ui/joined_view.dart:141` — a joined phone's frame sounds (`_play`, unchanged).
- `controller_app/lib/src/providers/feedback.dart:33` — the UI's system click for a press (unchanged, not a cue).

## The lobby music: starts and ends

- Wanted when `lobbies > 0`, `rounds == 0`, `soundSettingsProvider.music` and the app is shown. Holds are
  counted and clamped at 0; either hold's `dispose` releases it, and `dispose` of `LobbyMusic` closes the
  listener.
- A change marks a settle: `addPostFrameCallback` (plus `ensureVisualUpdate`) then compares `isWanted` with
  what is playing, so a route replaced in one frame does one thing or nothing. Two changes in one frame make
  no start (tested).
- Shown/hidden: `AppLifecycleListener`; `hidden`, `paused` and `detached` are not shown, and a null state is.
- **Deviation:** when the app becomes hidden there is no frame, so a stop left to the frame's end would never
  come and the music would play in the background — the reason rule 4 exists. Hiding therefore applies
  immediately (`_apply()` straight from the listener); showing still settles after the frame. The class doc
  says so. Every other change settles after the frame as the brief asks. See questions 1.

## flutter_soloud API (5.2.1) against the brief's rules

- `SoLoud.instance.play(source, looping: true)` matches; it returns a synchronous `SoundHandle` (not a
  future), and `stop(handle)` returns a `Future<void>`, so stops are `unawaited` as elsewhere in the file.
- `setGlobalVolume(double)` matches; there is no getter for it, so the volume tests read the player's own
  `volume` (the wish) rather than the engine's.
- `getIsValidVoiceHandle` exists and guards every stop, as the existing `play` did.
- As the brief allowed, the engine can't start under `flutter test`: no device, `load()` ends not ready. The
  loop/volume logic is therefore tested through `SoundWish` (pure) and `FakeSoundPlayer`, plus one real
  `SoLoudSoundPlayer` test that a volume and loop are kept with no engine and that `dispose` is safe.
- Nothing else differed; the three new keys load like the ten (no `SoundStatus` or TV sound-panel change).

## Findings and risks

1. **Hiding stops immediately, not after the frame** — the brief's rule taken literally leaves music playing
   behind a hidden app, since no post-frame callback runs while frames are disabled. Deviation reported, not
   chosen silently (questions 1).
2. **`soundPlayerProvider` overrides bypass the volume wiring.** A test that overrides the provider with
   `FakeSoundPlayer` replaces the provider body, so the `ref.listen` never runs (`Expected 0.8, Actual 1.0`
   when I first tried it). The volume tests use the real player or the notifier directly; worth knowing for
   future tests.
3. **`prefsProvider` moved to `prefs.dart`** so the settings can save through the look's prefs without a
   provider-import circle; same provider and same `main()` overrides, but it is a file move in `allow:` that
   a review should see.
4. **Tests that watch a provider**: `playerJoinedProvider` does nothing unless a screen keeps it alive, so
   `StubHome` watches it like the real homes. A new harness home must too.
5. **Line counts**: `pause_menu.dart` 398, `providers.dart` 396, `host_text.dart` 353, `sound.dart` 302 —
   all under 400, `tools/review.sh` reports no FAIL (its notes name these). `Pausable._beat` stays under 60.
6. `tv_test_app/lib/src/ui/home/pairing_panel.dart:226` still says "Whether the four event sounds loaded" in
   a comment; it now covers thirteen (suggestion, not changed).

## Self-check: docs/review-rules.md part A, items 1–5

1. **Every host setup.** TV/PC host: no lobby music on its home (the pairing panel isn't a lobby:
   `lobby_music_test.dart`, "the picker starts the loop once, and the join screen keeps it") and it plays
   the join cue (`tv_test_app/test/sound_test.dart`, "a phone joining the TV plays the phone-joined cue
   once"); a round with a beat plays the countdown, no-beat (the TV's) plays none (`countdown_test.dart`,
   "a round with no beat (the TV's) plays no countdown"). A host phone on "Play on this phone": the picker
   plays the loop (`controller_app/test/sound_test.dart`, "the host phone's picker plays the lobby music").
   "Show on this device": the host's own player is `local`, so no join cue (`player_joined_test.dart`, "the
   host's own player plays nothing"). A joined phone: no lobby music and no countdown — it mounts neither
   (`controller_app/test/sound_test.dart`, "a joined phone's waiting and pad screens never play the lobby
   music"). One build older: no protocol change, so nothing to test.
2. **When kept state starts and ends.** Holds start on mount and end on dispose, clamped at 0; the loop stops
   at the end of `LobbyMusic`'s life (a host scope's dispose). Music off ends it on the picker and on starts
   it; hidden ends it, resumed may start it; two changes in one frame start nothing (`lobby_music_test.dart`,
   five tests). The countdown starts only at the top of a beat and ends when the beat is held (results, leaving
   and dispose stop it too, untested on their own as noted); a round with no beat never starts one
   (`countdown_test.dart`, three tests). With no lobby and no round neither runs.
3. **How a new state combines with the others.** A held beat and the countdown: host away stops it and the
   beat over plays it again (`countdown_test.dart`, "a host-away hold stops it, and the beat starting over
   plays it again"); the pause menu and a waiting phone reach the same `_stopped` branch, and while the beat
   holds the round the builder is `paused`, so no menu opens over it. The results can't open while the beat
   runs (they come after the round), so the early-end stop there is defensive. Leaving a round closes
   `RoundHold` → the music returns, Change teams starts it again, Play again keeps it off
   (`lobby_music_test.dart`). Music and a round: the round stops it and it comes back only once the round's
   screen is gone (`lobby_music_test.dart`, "a round stops it, Play again keeps it off, and Change teams
   starts it again"). `Pausable` stays the one owner of a round's pause and phase; `LobbyMusic` owns only the
   loop, and reads "a round is on" from the holds, not from `roundPhaseProvider`.
4. **Stay in the job's folder.** Every edit is inside `allow:` (`assets/lib`, `assets/CREDITS.md`,
   `tools/audio/README.md`, `packages/party_host`, `controller_app/lib`, `controller_app/test`,
   `tv_test_app/lib`, `tv_test_app/test`, this report). The three `.ogg` cues and the three
   `tv_test_app/windows/flutter/generated_*` files were in the tree before I started and are listed above;
   the generated ones differ only in line endings.
5. **Stop rather than overstep.** The only rule I couldn't meet as written is "settle after the frame" while
   hidden (no frame exists). I made the smallest change that keeps rule 4's purpose, documented it in the
   class and here, and did not touch the generated Windows files or the untracked cues.

## Questions and suggestions

1. Is hiding the one place where applying at once instead of after the frame is right? (No frame runs while
   hidden; Android would keep playing.) I believe yes.
2. `tv_test_app/lib/src/ui/home/pairing_panel.dart:226`'s comment still says "four event sounds"; shall I
   fix it in a later job (it's outside this one's files)? Left alone.
3. The slider steps by 10 in the widget (`divisions: maxVolume ~/ stepPercent`), so the keyboard steps and
   the drag agree; if the owner wants 1% steps the divisions change only.
4. Pairs not tested on their own: the pause menu and a waiting phone during the beat (both reach the
   `_stopped` branch the host-away test exercises), and the defensive results stop (no results can open
   while the beat runs). Say if you want them pinned separately.

## Commit message

M13 step 7: lobby music, countdown and join cue, volume

The host screens play the lobby music under the game picker and
join screen through LobbyMusic (one frame-settled owner), stop it
for a round, and keep it off across Play again. Pausable plays the
3-2-1 with the beat and stops it when the beat is held, and
playerJoinedProvider plays a cue per new phone. SoundSettings keep
the device's volume and music in prefs; SoundPlayer gained loops,
stop and a master volume kept across load and restart; the
look-and-sound section gains the volume slider and the music switch.

## Status row

M13 step 7 (sound): done — lobby music under the picker and join screen with Music/volume settings, the 3-2-1 with the Get ready beat (TV none), and the phone-joined cue; open: the hidden-app stop is applied at once rather than after the frame (question 1), and the TV's beat is a later step.

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted. Checks green (kit 48, host 233, phone 408, tv 52 + 1 skipped); review.sh 0 fail.

1. **Hiding stops at once:** yes, right. No frame runs while hidden, so a stop left to the frame's end would never come. Showing still settles after the frame.
2. **The pairing panel's comment:** fixed by Claude ("the host's sounds", not "four").
3. **10% slider steps:** kept. The remote and a drag agree, and 10 steps are quick with a D-pad.
4. **Untested pairs** (the pause menu and a waiting phone during the beat, the results' stop): not needed. They all take the `_stopped` branch the host-away test covers.
5. **Read in the code, not testable here:**
   - `SoLoudSoundPlayer` applies the wish at the end of every load. A `playLoop` in the window between a restart's `deinit` and its reload finds no source and starts nothing, and the reload starts it.
   - The countdown starts in `initState`, as the card shows 3, unless the round already stands still. After the beat it stays "on" so the "go" chord's tail plays out, and it's stopped only if the round's screen goes.
6. **For step 9, on a device:** hear the lobby loop's seam (it should be seamless), the volume slider's effect, the countdown against the card on a host phone, and the music stopping when the phone locks and coming back when it unlocks (the iOS restart path).
