job: M13 step 7: sound. Three new cues (lobby music, the 3-2-1 countdown, a phone joining), a looping voice for the music, a master volume, and the Sound volume and Music settings (design section 8, PRD L5)
pub: no
stop: after it.
read: docs/design/look-and-sound.md sections 7, 8 and 10 · assets/lib/asset_manifest.dart · assets/CREDITS.md · tools/audio/README.md · packages/party_host/lib/src/sound.dart, providers.dart (gameSoundsProvider, soundPlayerProvider, GamePlayersNotifier), look_settings.dart, look_providers.dart, testing/adapter_fakes.dart, ui/look_and_sound_section.dart, ui/look_and_sound_screen.dart, ui/games_screen.dart, ui/join_screen.dart, ui/puzzle_screen.dart, ui/game_screen.dart, ui/pause_menu.dart (Pausable's "Get ready" beat), ui/ready_card.dart, text/host_text.dart · controller_app/lib/src/host/host_overrides.dart, host_games.dart, lib/src/ui/joined_view.dart, and the phone's settings screen · tv_test_app/lib/src/ui/home/home_screen.dart · docs/review-rules.md · docs/coding-guidelines.md

Where it stands: Claude has copied `lobby.ogg` (19.20 s, a seamless loop), `countdown.ogg` (4.42 s: beeps at 0, 1 and 2 s, then a "go" chord at 3 s) and `player_joined.ogg` (1.02 s) into `assets/audio/` from the owner's Bubble Pop sound package. The ten existing cues come from the same package. `soundPlayerProvider` loads every `SoundKey` at start.

Claude's rules:
1. **Keys and credits.**
   - Add `lobby`, `countdown` and `playerJoined('player_joined')` to `SoundKey`.
   - Add three rows to assets/CREDITS.md in the existing audio rows' form: generated with `tools/audio/render.py` (numpy synthesis, no sampled material), Project, CC0 1.0. "Used for": lobby, the host's game picker and join screen; countdown, the 3-2-1 before a round; player joined, a phone joining the host.
   - Update the Audio paragraph in CREDITS.md and the "extra cues aren't used yet" line in tools/audio/README.md.
2. **`SoundPlayer` gains:**
   - `void playLoop(String name)`: loops that sound until `stopLoop`. There is one loop at a time. A second `playLoop` with the same name while it's playing does nothing: the music must not restart. A different name stops the old loop first. Use flutter_soloud's `play(source, looping: true)`.
   - `void stopLoop()`.
   - `void stop(String name)`: stops a one-shot sound that's still playing (needed by rule 5).
   - `set volume(double v)` (0..1, clamped) and its getter. This is the master volume, through `SoLoud.instance.setGlobalVolume`; 0 is silence.
   - **The player keeps what's wanted, not just what's playing.** A `playLoop` called before `load()` finishes starts the loop once the sounds are in. A `restart()` (iOS after a lock) starts the wanted loop again and sets the volume again. A volume set before load applies once the engine is up.
   - `FakeSoundPlayer` records all of it: `loop` (the name looping now, or null), `loopStarts` (every real start, so a test can see a restart), `stopped` (names) and `volume`.
   - `SoundStatus` and the TV sound panel need no change. The three new keys show there as loaded.
3. **The settings, `SoundSettings`** (a value like `LookSettings`): `volume` (an int percent, 0 to 100, default 80) and `music` (bool, default true).
   - Add `soundSettingsProvider`, a Notifier saved through `lookPrefsProvider` under the keys `sound.volume` and `sound.music`, with `setVolume` (clamped) and `setMusic`.
   - **Applying it:** `soundPlayerProvider` listens to `soundSettingsProvider` (fire immediately) and sets `player.volume = percent / 100`. So the volume follows the player wherever it lives: the TV, the Windows app, the host phone, and a joined phone's game sounds.
   - **`LookAndSoundSection`** gets, after Effects:
     - **Sound volume**: a `Slider`, 0 to 100 in 10 steps, its value as "80%" beside the label, key `soundVolume`;
     - **Music**: a `SwitchListTile`, key `soundMusic`, subtitle "Plays on the game picker and join screen.".
   - Strings go in `HostText`. The section's doc comment loses "The sound rows join it in step 7". The remote and the phones work the new rows like the others: they take the focus in order, and left and right move the slider.
4. **Lobby music: the screens decide** (design section 8; Claude's rule for what "picker and join screen" covers):
   - The music plays while **a lobby is open and no round is**:
     - a lobby is open from the game picker's mount to its dispose. Anything pushed over it still counts: the Shape Race list, puzzle settings, the join screen, stats, settings;
     - a round is open while `PuzzleScreen` or `GameScreen` is mounted, results and pause included.
   - So the music starts on the picker and carries on unbroken through to the join screen. It stops the moment a round's screen opens. Play again keeps it off. It comes back when the round's screen closes back to the join screen or picker, including Change teams.
   - **How:** a `LobbyMusic` controller in party_host counts two holds, `lobbies` and `rounds`.
     - Two small widgets hold them while mounted: `LobbyHold` wraps `GamesScreen`'s body, and `RoundHold` wraps `PuzzleScreen` and `GameScreen`, beside their `ToyStillSky`.
     - It's a provider (disposed with the host's scope), so the TV app and the phone host share it.
   - **The music is wanted when** `lobbies > 0`, `rounds == 0`, the Music setting is on, and the app is shown. Use an `AppLifecycleListener`: hidden or paused stops it, and resumed may start it again. Android keeps playing in the background otherwise.
   - **Changes settle after the frame** (`addPostFrameCallback`). Then it calls `playLoop('lobby')` or `stopLoop()` only if the wanted state changed. A route replaced in one frame (Play again, Change teams) never stops and restarts the music.
   - **Joined phones never play it.** They never mount the picker, so this follows. The phone hosts only with no TV (owner, Nov 8), so a host phone plays it on its own picker. A test pins the joined case.
   - The TV app's home screen (the pairing panel) is not a lobby. The music starts when the TV opens the picker.
5. **The countdown follows the "Get ready" beat** (Claude's rule: it plays with every 3-2-1 there is):
   - `Pausable` plays `countdown` when its beat starts counting from the top. That's at the round's start, and again when the beat starts over after a wait (host away, or a phone the round waits for).
   - When a beat is held, or ends early (results), it calls `stop('countdown')`, so no "go" sounds over a held round.
   - It plays through `soundPlayerProvider` on the host only. Play it at the moment the card first shows 3: the beeps land on 3, 2, 1 and the chord on the round's first step.
   - **The TV asks for no beat** (m12-host-touch rule 6), so the TV plays no countdown, and the Arena's 2 s break between rounds stays silent. Say so in the doc comment. A later step can give the TV a beat.
6. **Player joined:**
   - The host plays `player_joined` once when a player who isn't `local` appears in `gamePlayersProvider`'s list and wasn't in the list before.
   - A phone coming back from away is the same id, still in the list, so it plays nothing. A phone that left the list and joins again plays it again.
   - Simulated controllers play it too (the TV's test tool is how Claude hears it on Windows).
   - It lives in one small provider the host screens keep alive, like `gameSoundsProvider`, which the TV home and the phone host already watch. Watch it in the same places.
7. Files under 400 lines, functions under 60. No colours. Every string in `HostText`.

tests (each failing first):
- Keys (in party_host's tests; assets has no test folder): `SoundKey.byEventName('player_joined')` is `playerJoined`, and the three new files are bundled under `packages/game_assets/audio/` (read the asset manifest, or check the files exist beside `soundFiles`' paths).
- `FakeSoundPlayer`: none (it's a fake), but every rule below is tested through it.
- `SoundSettings`: defaults 80 and on; saved and read back through prefs; `setVolume(140)` is 100, `setVolume(-5)` is 0.
- **Volume applied:** setting 30% gives the player 0.3; a new scope reads the saved value back.
- **Section:** both rows are drawn in Sunny and Night; dragging the slider (or a right-arrow key while it's focused) changes the setting by 10; turning Music off saves it.
- **Lobby music (party_host, through the host harness):**
  - the picker starts the loop, once;
  - pushing the join screen keeps it with no new start (`loopStarts` stays 1);
  - starting a round stops it; Play again keeps it stopped; back to the join screen starts it again;
  - Music off stops it on the picker, and on again starts it;
  - the app going to `hidden` stops it, and `resumed` starts it;
  - two changes in one frame make no start.
- **controller_app:**
  - the host phone's picker plays the loop;
  - a joined phone's waiting and pad screens never do;
  - the Settings screen shows the two new rows.
- **Countdown:**
  - a round with a 3 s beat plays `countdown` once, as the card shows 3;
  - a host-away hold stops it, and the beat starting over plays it again;
  - a round with no beat (the TV's) plays none.
- **Player joined:**
  - a phone joining plays it once;
  - the same phone away and back plays nothing more;
  - a local player plays nothing;
  - two phones play it twice.
- **Restart:** with a loop wanted, `SoLoudSoundPlayer`'s bookkeeping restarts it. Test through a small seam if the engine can't run under test: keep the "wanted" logic in a pure class, and test that.
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). List any test you change, and why.

in the report:
- test counts before and after;
- the files changed;
- the screens holding `LobbyHold` and `RoundHold`;
- every place a sound is now played from, one line each;
- anything in the flutter_soloud API that differed from these rules.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s7-sound-report.md · assets/lib · assets/CREDITS.md · tools/audio/README.md · packages/party_host · controller_app/lib · controller_app/test · tv_test_app/lib · tv_test_app/test
check: format analyze host phone tv kit
report: docs/briefs/m13/s7-sound-report.md
