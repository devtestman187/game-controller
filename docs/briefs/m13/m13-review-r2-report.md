# M13 review R2: the host

Read-only pass over `git diff d06f88a HEAD -- packages/party_host assets` (lib and tests), against review-rules A to D,
coding-guidelines, design/look-and-sound (sections 6–8 and the "decided at step 6/7" blocks), m12-host-touch rules 1–6,
m12-joined-view §0 and PRD-v2 L3 and L5 (G2 and C20 for part C). Only this report was written; nothing was fixed.
Checks: `flutter test` party_host 233 passed; `dart analyze` clean; `dart format --set-exit-if-changed` 0 changed
(125 files); `bash tools/review.sh --base d06f88a` 2 fail, 151 note, both FAILs outside this area.

## Findings

No **must** here: the two review.sh FAILs are r1's arena build and r3's `shader_spike_rows.dart`, and the loop, the
countdown and the palette behave as design section 8 and D1 say in the states the tests cover.

- **should** · `away_card.dart:19` (party_host/lib/src/ui) · the string table · `labels: {ControllerButton.a: 'OK'}` is
  the only user-visible literal outside `HostText` in party_host (a grep of `lib/src/ui` for `Text('`, `labels` and
  `'OK'` finds it alone); `controller_menus.dart:14` says `HostText.ok` for the same row, and no test covers this row.
- **should** · `pause_menu.dart:219-232` against `lobby_music.dart:121-131` · the countdown against the beat · it stops
  only from `_beat` (every 16 ms) and `dispose`, where the music's `AppLifecycleListener` stops at once on hide. Press
  Home during "Get ready" where Dart timers are suspended and the beeps and the "go" chord play on to an empty room.
- **should** · `lobby_music.dart:102-105` · the holds, "scope disposed" · `dispose()` sets `_disposed` and drops its
  lifecycle listener, nothing more, so the loop ends only through `soundPlayerProvider`'s `dispose` (engine deinit) in
  the same teardown; the doc (line 144) promises a stop this class doesn't do, and no test disposes a scope mid-loop.
- **should** · `toy_theme.dart:18-77` (no `focusColor`), `host_screen.dart:111` · the focus highlight (L3) · buttons and
  cards draw the look's ring, but the Material controls (the Look choices, the Effects and Music switches, the volume
  slider, the back arrow) get Material's 12 % black wash: a faint grey from the couch, and no test checks a lit one.
- **later** · `assets/CREDITS.md:1-6` · credits · six puzzle audio rows (snap, wrong, tick, pickup, time_up, help) sit
  above the `# Asset credits` heading and outside its table, so they render as loose pipe text over the title; the M13
  rows are in the table. Git is blocked here, so I can't tell whether this predates the range.
- **later** · `game_screen.dart:126` · the round hold · the Arena's round screen is `GameScreen`, so its hold is the
  Puzzle's widget (`sky_holds_test` covers its still sky), but no lobby-music test opens a `GameScreen`.
- **later** · `providers.dart:233-243` · the player-joined cue · `seen` is replaced by each new list, so a phone that
  drops off and comes back plays it again, and a host opened with phones in it plays nothing for them: right-looking,
  unstated in section 8 and untested.
- **later** · `controller_app/test/sound_test.dart` · the volume · the mapping is pinned in party_host and every app
  overrides `party.prefsProvider` at its root, so a joined phone takes the setting; no test checks its sound's volume.

## Combination table (A3)

| State | Verdict |
| --- | --- |
| picker and join screen, Music on, app shown | tested by lobby_music_test "the picker starts the loop once, and the join screen keeps it" |
| Music off on the picker, then on; hidden; shown; two changes in one frame | tested by lobby_music_test's other four tests |
| a round, Play again, Change teams | tested by "a round stops it, Play again keeps it off, and Change teams starts it again" |
| Music off × round; Music on mid-round; a picker closed by Back; a pause card over a round | **not tested**: `isWanted` is false while `_rounds > 0`, so a settle during a round can only stop; `LobbyHold`'s `dispose` is the settle path the round test covers; a pause card stays inside the round route |
| a scope disposed while the loop plays | **not tested**: `dispose()` stops nothing (the third should); the engine deinit does it in both apps |
| countdown: a 3 s beat; host away holding it, then restarting it; the TV's round with no beat | tested by countdown_test's three tests |
| countdown × results, × dispose, × a phone the round waits for | **not tested**: `_beat` stops it when `!enabled`, `_stopped` covers a waiting phone and `dispose` stops it, but nothing asserts the stop call |
| countdown × app hidden | **not handled** (the second should) |
| player joined: a phone joins; away and back; the host's own; two phones | tested by player_joined_test's four tests |
| palette: Auto at 18:59 then 19:01 with no route; a push; a pop; a Look change; a dialog | tested by look_palette_test's five tests |
| palette × round | **not tested**: only `ToyLookRouteObserver` refreshes, and no round route pushes or pops while a round stands; `build()` also re-reads the clock on any look setting's change, Effects included |
| a still sky in a round against a drifting menu | tested by sky_holds_test's two tests |

## Part A, job by job

1. **Every host setup.** All four read the one `soundPlayerProvider` and `toyLookProvider` from their root scope, which
   every app overrides; no protocol change, so an older peer is unaffected.
2. **Kept state.** The palette is worked out at start, on a Look change and on a push or pop only
   (look_providers.dart:68-104); the music's holds count in and release on dispose; the countdown's flag and sound are
   cleared on dispose.
3. **Combinations.** The table. 4. **The folder.** Only this report was written. 5. **Overstep.** Nothing stopped.

| Job | Its self-check | True? |
| --- | --- | --- |
| 3a the look's wiring | the palette at start, on a setting and on a page route; saved and read back; a dialog leaves it alone | yes (host 165 then): look_providers_test and look_palette_test's five; the one addition above is that `build()` re-runs on another look setting's change, harmless |
| 3b the host's screens and cards | every screen, card and dialog in the look, the strings in `HostText`, the fit tests | yes (host 197 then, 233 now) apart from one literal (finding 1) and the Material controls' focus (finding 4) |
| 6 the shaders' host side (the sky) | a round's sky stands still, a menu's drifts | yes: `RoundHold` over `ToyStillSky` in game_screen.dart:126 and puzzle_screen.dart:192; sky_holds_test |
| 7 sound | the three cues, looping, volume and mute; kit 48, host 233, phone 408 | yes as claimed; the gaps are the four shoulds and the later items below (8 the pad is r3's) |

## Part C, weighed against M14

| Item | Cost now | Weighed against M14 |
| --- | --- | --- |
| a third hold for G2's scoreboard between rounds | `openRound`-shaped pair and a hold widget, ~10 lines and a test | **worth doing before M14 G2.** If the scoreboard is a route of its own, `_rounds` drops to 0 while it shows: the lobby loop starts under it and stops again when the next round mounts, for every scoreboard of a night. Play again and Change teams already show the holds compose; the scoreboard would be the first state with no hold at all. Nicknames (C20) cost nothing: no host sound or look code reads a name |
| the countdown when the app is hidden (the second should) and the credits rows (the fifth finding) | one listener, as the music has; one move | M14 adds screens with countdowns and sounds of its own (the cat's meow, the pop-ups), so both grow; cheap now |
| the Material controls' focus (the fourth should) | one `focusColor:` in `toyTheme` | the same price later, but M14 adds the scoreboard, the awards and the Chaos setting, all Material controls, so it is paid once for all of them now |

## PRD coverage

- **L3** "every menu, card and screen in the same look … with an easy-to-see focus highlight": the look is done (s3b:
  every screen and card through `HostButton`/`HostCardButton`/`ToyCard`, all text through `HostText`, the theme in both
  apps; screen_fit_test, look_and_sound_test, host_focus_look_test). Open: the Material controls' focus and the one
  literal. "On the TV and on phones" is r3's.
- **L5** "lobby music (looping), countdown and player-joined sounds, a mute switch and a volume setting, saved with the
  other settings": the loop plays on the host's picker and join screen and stops for a round (lobby_music_test,
  controller_app's "a joined phone's waiting and pad screens never play the lobby music"), the countdown follows the
  beat (countdown_test), the cue plays once per new phone (player_joined_test), the volume reaches the player
  (sound_settings_test's two) and both settings read back. Open: the countdown when hidden. **"A mute switch"**: Settings
  has Look, Effects, Sound volume (0–100, default 80) and Music (on/off) — no switch called mute. The step-7 decision
  says "Mute is volume 0", and 0 silences everything, the loop included, so L5 is met in effect but not by one tap; the
  Music switch silences the lobby music only. Question 1.

## review.sh

```
FAIL func     packages/test_game/lib/src/arena_hud_widgets.dart:132 69 lines (>60): Widget build(BuildContext context)
FAIL color    tv_test_app/lib/src/ui/shader_spike_rows.dart:117 a colour outside toy_look
review: 2 fail, 151 note
```

The 69-line build is the arena HUD's `_PlayerRow` (r1's must, reported); the colour is the dev shader screen (r3's).

## Not checked

- Nothing on a device: under `flutter test` a `FakeSoundPlayer` records the calls, so the loop's seamlessness, its stop
  on hide, the volume and the Material focus on a TV are device checks (STATUS's step-9 list).
- tv_test_app and controller_app's own suites (r3's): only their sound tests were read. review.sh's 151 notes were not
  triaged, and git is blocked here, so "predates the range" rests on the code alone.

## Questions and suggestions

1. Does L5's "a mute switch" mean a switch? Mute is volume 0 (decided at step 7) and Music is music-only; a one-tap
   mute would be a `sound.mute` key, a row and one line in `SoundWish.volume`.
2. Should the countdown stop at once when the app is hidden, as the lobby music does?
3. Add the scoreboard hold now (part C) or with M14 G2?
4. Move the six misplaced rows into `assets/CREDITS.md`'s table? I left the file alone.
5. Should `toyTheme` set `focusColor: colors.focus`, so Material controls stop drawing the grey wash?
6. The away card's row says 'OK': `HostText.ok`, or a word of its own?

## Commit message

```
M13 review r2: the host's screens, sound and settings

- Read d06f88a..HEAD for party_host and assets. No fixes.
- No must; 4 shoulds (a literal outside HostText, the countdown that plays on
  when the app is hidden, LobbyMusic.dispose stopping nothing, Material controls'
  focus) and 4 laters.
- Combination table, part A/C, L3/L5 coverage, 6 questions; review.sh 2 fail,
  both other areas'.
```

## Status row

Step 9 review r2 (the host, read-only): done, no must + 4 should + 4 later + 6 questions in the report; open: r3, the
should fixes, the scoreboard hold (part C), then the Windows and device checks.

## Delete

- none
