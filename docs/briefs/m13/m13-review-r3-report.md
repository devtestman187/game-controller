# M13 review R3: the apps

Read-only pass over `git diff d06f88a HEAD -- controller_app tv_test_app` (lib and tests) against review-rules A to D,
coding-guidelines, design/look-and-sound (sections 4–8 and the "decided at" blocks), the m12 design docs and PRD-v2 L3 and
L5; the code above the apps was read where a claim needs it. Only this report was written; nothing was fixed, and no suite
was run (this pass writes nothing). Checks: `tools/review.sh --base d06f88a` 2 fail, 151 note (below).

## Findings

- **must** · `tv_test_app/lib/src/ui/shader_spike_rows.dart:117` · review-rules C row 1 · `Color(playerColors[...])` builds
  a colour outside `toy_look`, the only one in either app's lib and one of the two review.sh FAILs: the Look test's stress
  shapes never follow the palette (they match `look.colors.player` today only because of D6).
- **should** · `controller_app/lib/src/ui/controller_screen.dart:194` · design section 6 and the brief's "the sky held on
  ControllerScreen" · `ToyStillSky` wraps the whole screen, `widget.background` included, and a hosting phone passes its
  `HostGames` in there (`host/host_screen.dart:80`); every page of that navigator stands on the transition's
  `ToyBackground`, so the picker, join screen, Shape Race list and stats are held still where design line 152 names only
  the round's screens and "a phone's pad and joined view". The phone's lobby never drifts where the TV's does, and
  `sky_holds_test` passes either way.
- **should** · `controller_app/test/support/pump_app.dart:110` · the brief's prefs swap, review-rules A1 · the harness
  overrides `party.lookPrefsProvider` itself, so no phone test runs the production link (`host/host_overrides.dart:22` into
  `party_host/lib/src/look_providers.dart:21`). Delete that override and all 428 phone tests still pass while the app throws
  `UnimplementedError` on its first frame, hosting or joined.
- **should** · `packages/toy_look/test/toy_font_licenses_test.dart:9` · design D13, "a test that would still pass if its
  rule broke" · the loader is fake, so renaming or dropping `packages/toy_look/fonts/{fredoka,nunito}/OFL.txt` passes the
  suite. The apps register unawaited (`controller_app/lib/main.dart:29`, `tv_test_app/lib/main.dart:22`), so the first
  symptom is an unhandled async error at start and a licences page without the OFL; `rootBundle` in that test, where both
  files exist (`packages/toy_look/pubspec.yaml:41`), would prove they ship.
- **should** · `tv_test_app/lib/src/ui/home/home_screen.dart:152` · the brief's "the TV at 960 × 540 and 1280 × 720" · with
  `compactWidth = 1100` the full-label header is a branch no test runs: `tv_fit_test` measures the header's rows, the title
  and the two tiles only at 960 (and the narrow home at 700), so a third row or an overflowing tile at 720p is invisible,
  and step 3d's "seen at 1280 × 720" is a manual sighting.
- **later** · `controller_app/lib/src/ui/controller_top_bar.dart:111` · design D1 ("never in the middle of a round") ·
  mid-round, Settings from the bar is a page route and `ToyLookRouteObserver.didPush` (`route_observer.dart:20`) refreshes:
  at 19:00 the pad, the bar and the joined view turn Night during a round. The observer cannot tell a menu from a round,
  and nothing tests a joined phone's Settings over a running view.
- **later** · `tv_test_app/lib/src/ui/home/controllers_panel.dart:113` · coding-guidelines §35 · `type.body.fontSize!`,
  set by `ToyType` always (`toy_type.dart:46`) but shown by nothing on that line.

## The D11 check

Sizes, hit areas and opacity are unchanged. `layout.dart`, `sticks.dart`, `ui/pad.dart`, `ui/controls_layer.dart`,
`ui/pad_mode_view.dart` and `ui/top_bar_metrics.dart` are identical to d06f88a; in the three painter files every number of
the old file survives except three permitted restyles (the press radius `0.94` now the 4/3 px squish, the edge
`max(1.5, r * 0.075)` now the look's outline, the centre dot's `0.15` alpha now ink at `toyShadowAlpha`). The arm 0.34, the
arrows 0.40 / 0.30 / 0.06, the arm round 0.06, the centre dot 0.34 · 0.28, the `FaceGeometry` radius, `SmallButton`
96 × 44, the knob `max(14, r * 0.42)` and the stick's 0.4 / 0.55 / 0.42 carry over; `pad_look_test` paints each in both.

## Combination table (A3)

| State | Verdict |
| --- | --- |
| Connect and Settings, Sunny / Night | Connect by phone_look_test "the address field … at night too" and sky_holds_test "the Connect screen's sky drifts"; Settings by settings_test, phone_look_test's two and phone_fit_test's 3 sizes × 2 palettes |
| Diagnostics and the cards over the pad and the bar, Sunny | tested by phone_look_test's four; **Night not tested** for any of them (phone_fit_test checks the fit only) |
| pad, D-pad, Sunny / Night | tested by pad_look_test (faces, D-pad, sticks, small button, PressFlash) and pad_badge_test's three; **the gyro and sticks modes are not tested** for the look — their tests check which widget shows, never its colours |
| pad at 20–100% opacity over a game | **not tested**: the mechanism is pinned at 0.3 and 0.6 (controls_layer_test, joined_view_test); nothing paints the toy pad at the lowest opacity (step 9's list) |
| joined view in a round (sky held) | tested by sky_holds_test "the pad holds its sky still" and joined_view_test's badge and dot |
| phone hosting, both modes (pad over the game, or the screen only) | pad and modes by host_own_player_test and host_gyro_test, music by sound_test, no pad by host_mode_test; **the sky not tested** (finding 2), Night not tested in the apps (s3b covers the screens' palettes) |
| effects off, either app | **not tested** end to end: look_and_sound_test taps the Effects switch and toy_look's tests draw with `effects: false`, but no app test runs with effects off |
| TV home at 960 × 540, Sunny / Night; at 1280 × 720 | tested at 960 by tv_fit_test's two and home_look_test (tiles, states, statuses, code, log); **1280 not tested** (finding 5). The test screens are Sunny only (tv_fit_test, shader_spike_screen_test) |

## Part A, job by job

| Job | Its self-check | True? |
| --- | --- | --- |
| 3a the look's wiring | scope, theme, shaders and licences at start, the Look kept and applied at set moments | yes: `main.dart` of both apps (timeout `party.toyShaderLoadTimeout`, `main.dart:24`); the set moments in look_palette_test's five. The prefs swap is right and untested (finding 3) |
| 3c the phone's screens and cards | every screen and card in the look, the strings in `PhoneText`/`SettingsText` | yes, but the look of Diagnostics and of the cards and bar at Night has no assertion (table) |
| 3d the TV home and test screens | the theme only, layouts kept, title whole, header at most two rows, two controllers in view at 960 × 540 | yes at 960 and 700 (tv_fit_test); 1280 is a manual sighting (finding 5) |
| 4c the badges | the bar's badge wears the character, the TV's tiles use `ToyBadge` | yes: pad_badge_test's three, home_look_test "the controllers panel shows a tile per controller" |
| 6 the shaders and the sky, apps' side | both shaders loaded at start, a round's sky still, menus drift | load yes (`main.dart:24`, 5 s then `ToyShaders.none`); the pad and joined view yes, the host phone's menus no (finding 2) |
| 7 sound, apps' side | the host phone plays the lobby music, a joined phone never; the rows are there | yes: sound_test's three, with the loop and the countdown's own behaviour in party_host |
| 8 the pad | every size and hit area unchanged, no colour literal left | yes, line by line (the D11 check); one colour outside the look in tv_test_app (finding 1) |

## Part C, weighed against M14 G1–G8 and streaming

- **The host phone's sky (finding 2).** Now: ~10 lines to move the hold to the controls and the joined view, plus a test.
  M14 G1's pop-ups and G2's scoreboard add screens over a round (hold wanted) and menus (not); with one hold at the
  screen every new screen has to be reasoned about, and a lobby that never drifts becomes the phone's normal.
- **The look prefs swap (finding 3).** Now: one test that pumps the real root overrides; M14's points and scoreboard
  settings read the same prefs, and a broken link would move every one of them onto the host's.
- **Nothing else here is worth doing for the future:** the pad, the bar and the joined view take everything from the look,
  the strings are in the two tables, and streaming a TV (v3) needs no work in either app.

## PRD coverage

- **L3** "every menu, card and screen in the same look, on the TV and on phones, with an easy-to-see focus highlight":
  done on the phone (phone_look_test, settings_test, pad_look_test, phone_fit_test) and on the TV (home_look_test,
  tv_fit_test, party_host's in r2); the focus ring is `colors.focus` on `ToyButton` (toy_button_test) and reaches the
  phone host's menus through `ControllerMenus` (host_focus_look_test). Open: no look test for Diagnostics or the cards and
  bar at Night (table); the grey Material focus is r2's, the 1280 case finding 5.
- **L5**'s settings rows: Sound volume (0–100, default 80) and Music (on/off) are in both Settings screens
  (`settings_sections.dart`, party_host's `LookAndSoundSection`; sound_test, home_screen_test), saved with the device's
  other settings (`sound.volume`, `sound.music` via `lookPrefsProvider`), and only the hosting device plays music
  (sound_test's first two). **"A mute switch"**: there is none — step 7 says "Mute is volume 0", which silences everything
  but takes a drag, not a tap. Question 1.

## review.sh

```
FAIL func     packages/test_game/lib/src/arena_hud_widgets.dart:132 69 lines (>60): Widget build(BuildContext context)
FAIL color    tv_test_app/lib/src/ui/shader_spike_rows.dart:117 a colour outside toy_look
review: 2 fail, 151 note
```

## Not checked

- Nothing on a device: the pad at the lowest opacity over a game, the badge on a small phone, the licences page, the
  shaders on a cold start and the fonts are STATUS's step-9 list, and `flutter test` never loads a shader.
- The 151 notes were not triaged; the colour FAIL is finding 1 and `_PlayerRow`'s 69-line build is r1's. Every file in
  the apps' lib is under the 400 line limit (longest changed: diagnostics_screen 363, haptic_panel_screen 354,
  pad_widgets 346). `debug_start.dart`'s launch-in-a-game path and the Windows runner were read but not exercised: a game
  screen opened by `START_GAME` gets no test of its look. Git is blocked here, so "unchanged from d06f88a" rests on
  `git diff`/`git show` alone.

## Questions and suggestions

1. Does L5's "a mute switch" want a one-tap mute row, or is "Mute is volume 0" the answer (r2's question 1)?
2. Was holding the sky under a hosting phone's menus intended (finding 2), or should only the pad and joined view hold it?
3. Should a joined phone freeze the palette for a round, so the bar's Settings can't turn it Night mid-round (finding 6)?
4. Add a 1280 × 720 case to tv_fit_test (finding 5), or is the manual look enough for M13?

## Commit message

```
M13 review r3: the apps

- Read d06f88a..HEAD for controller_app and tv_test_app; no fixes.
- 1 must (a colour outside the look in the Look test screen) and 4 shoulds: the
  hosted lobby's sky held still, the prefs swap no test runs, the font licences
  proved by a fake loader, no test at 1280 × 720.
- D11 verified line by line; table, part A/C, L3/L5, 4 questions.
```

## Status row

Step 9 review r3 (the apps, read-only): done, 1 must + 4 should + 2 later + 4 questions in the report; open: the must
one-liner, the should fixes, r1's and r2's findings, then the Windows and device checks.

## Delete

- none
