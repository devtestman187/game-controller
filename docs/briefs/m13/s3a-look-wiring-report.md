# M13 step 3a — both apps run in the look: report

The look is wired in: `toyTheme` puts a toy sky behind every page through the page transition, both apps load the shader at start, register the fonts' licences and sit their `MaterialApp` in a `ToyLookScope` with the look's theme, the palette is worked out at the set moments only, and Look and effects are a setting both apps save and a card both apps show. No screen was restyled; three boxes had to grow so the theme's type fits in them (see below), and that is the one place where rule 7's "change nothing else" and the "existing tests all still pass" rule meet.

## Files changed

Package `packages/toy_look`:

- `lib/src/page_transitions.dart` — new, 31 lines: `ToyPageTransitionsBuilder extends PageTransitionsBuilder`, whose `buildTransitions` hands `ToyBackground(child: child)` to the platform's own transition (`const PageTransitionsTheme()`'s), so each page carries its own opaque sky and a page sliding over another never shows the one below. Exported.
- `lib/src/route_observer.dart` — new, 33 lines: `ToyLookRouteObserver extends NavigatorObserver`; `didPush`/`didPop` of a `PageRoute` call the callback (dialogs and popups are not page routes). Exported.
- `lib/src/toy_theme.dart` — `pageTransitionsTheme: _pageTransitions()` (a private helper for all `TargetPlatform`s), and the import.
- `lib/toy_look.dart` — exports the two new files.
- `test/page_transitions_test.dart` — new, 3 tests: a page under `toyTheme` has a `ToyBackground` under it and a transparent scaffold; a pushed page has its own, mid-transition and settled; a dialog has none of its own.
- `test/route_observer_test.dart` — new, 1 test: a page's push and pop call back; a dialog's push and pop don't.

Package `packages/party_host`:

- `pubspec.yaml` — `toy_look` as a path dependency (the layer builds the theme for both apps).
- `lib/party_host.dart` — exports the four new files, and `export 'package:toy_look/toy_look.dart';` at the end: the phone app's `pubspec` is outside this job's `allow:` and it can't depend on `toy_look`, so it gets the scope, the theme and the look through the layer it already depends on.
- `lib/src/look_settings.dart` — new, 29 lines: `LookSettings` (choice, effects; defaults auto and true), `copyWith`, `==`/`hashCode`.
- `lib/src/look_providers.dart` — new, 105 lines: `toyShaderLoadTimeout` (5 s); `lookSettingsProvider` (`look.choice` as the choice's `.name`, `look.effects`, saved on every change); `lookPrefsProvider`; `toyTvProvider` (false); `toyShadersProvider` (`ToyShaders.none`); `lookClockProvider` (`DateTime.now`); `lookPaletteProvider` with `refresh()`; `toyLookProvider`; `toyLookRouteObserverProvider`.
- `lib/src/ui/look_and_sound_section.dart` — new, 61 lines: the Look card's contents — a `SegmentedButton<LookChoice>` (`Key('lookChoice')`), the line "Auto: Sunny from 7:00 to 19:00, Night otherwise", built from `sunnyFromHour`/`sunnyUntilHour`, and the Effects `SwitchListTile` (`Key('lookEffects')`) in a transparent `Material` (a tile paints its ink on the nearest Material, and a toy card's paper is a `ColoredBox`).
- `lib/src/ui/look_and_sound_screen.dart` — new, 41 lines: the TV's page (`HostScreen(title: 'Look and sound')`, the section in a `ToyCard`), Esc leaves it, and a `Focus(autofocus: true)` takes the focus as it opens, as the other host pages do, so Back works and the arrows start at the choices.
- `lib/src/ui/games_screen.dart` — `_GameCard`'s box is 380 wide with a **minimum** height of 180 instead of a fixed one, so a card grows with its words rather than spilling the subtitle. With the app's real fonts nothing grows: the content is under 140 (the 180 less the 20 px padding) in both cards.
- `test/support/host_harness.dart` — a fixed clock (`harnessNow`, midday) and a `clock` parameter (`lookClockProvider`), and `_HarnessApp`, the apps' root as both of them build it: `ToyLookScope`, `toyTheme(look)`, the look's route observer, and the same builders as before.
- `test/look_settings_test.dart` — new, 4 tests: the defaults; a saved night and effects off; an unknown name reads as auto; a change is saved and a second container reads it back.
- `test/look_palette_test.dart` — new, 5 tests, the palette at the set moments with a fake clock.
- `test/look_providers_test.dart` — new, 3 tests: the TV flag picks the TV's type and sizes; the palette comes from the setting and the clock; effects off takes the shader away and keeps every colour and shape.
- `test/look_and_sound_test.dart` — new, 3 tests: Night saves and the theme's `canvasColor` turns Night; Sunny saves and the Auto line; the Effects switch saves and the look drops its shade.
- `test/games_screen_test.dart` — 1 new test: the picker's cards are 380 wide and open without a layout error in the test's own (wide) font.

Phone app `controller_app`:

- `lib/main.dart` — the shader loaded before `runApp` with the 5 s timeout, `unawaited(registerToyFontLicenses())`, `toyShadersProvider` overridden, and `ControllerApp` is a `ConsumerWidget`: `ToyLookScope` → `MaterialApp(theme: toyTheme(look), navigatorObservers: [the look's observer], builder: HostFocusScope, home: ControllerScreen)`. The seed `ColorScheme` is gone.
- `lib/src/host/host_games.dart` — the host's own `Navigator` gets its own `ToyLookRouteObserver` (a `Navigator` attaches an observer only once, so it can't be the app's: sharing one trips `observer.navigator == null`). `HostGames` is a `ConsumerStatefulWidget` to hold it.
- `lib/src/ui/settings_screen.dart` — the Look and sound card between "Game on this phone" and "Control stats".
- `lib/src/ui/settings_sections.dart` — `_LookAndSoundSection`, the card (`_Section(title: 'Look and sound')`) around party_host's section.
- `test/support/pump_app.dart` — `party.lookPrefsProvider` overridden with the phone's prefs: the phone app only supplies the layer's prefs while it hosts, and the look's settings are read at the root.
- `test/support/test_font.dart` — the fit tests load the look's own fonts (Fredoka and Nunito, from `../packages/toy_look/fonts`, as `packages/toy_look/<family>`) as well as Roboto. The theme now names the look's families, so a test that loaded only Roboto measured every word in the test bundle's box font again.
- `test/settings_test.dart` — 1 new test: the card is in Settings, above the stats, with its choices and the Auto line, and Night saves.
- `test/host_bar_test.dart`, `test/host_own_player_test.dart` — `setUpAll(loadHostFonts)`: both open the join screen at 852 × 393, which is laid out to fit a phone's height and overflowed by 59 px in the test bundle's font.

TV app `tv_test_app`:

- `lib/main.dart` — the same shader load and licence call, `toyTvProvider` and `toyShadersProvider` overridden, `TvTestApp` a `ConsumerWidget` with `ToyLookScope` → `Shortcuts` → `MaterialApp(theme: toyTheme(look), navigatorObservers: …)`. The seed `ColorScheme` is gone.
- `lib/src/ui/home/home_screen.dart` — the "Look and sound" `HostButton` (`Key('openLookAndSound')`) before "Look test"; the header's buttons are a `Wrap` in both layouts and take at most 65 % of the header beside the title, so six of them run onto a second line instead of 200 px off the screen.
- `test/home_screen_test.dart` — 1 new test (the button opens the screen, with the section's choices and switch), and the "remote reaches and presses every button" test now reaches and opens the sixth button.

The report itself is the only file outside those folders. `git status` also lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc/.h` and `generated_plugins.cmake` as modified: running `flutter test` / `pub get` rewrote them with LF endings again (as in 2b). I didn't touch them and can't restore them without a git command.

## Test counts

| | before | after |
| --- | --- | --- |
| `packages/toy_look` | 76 | 80 (+4: 3 page transitions, 1 route observer) |
| `packages/party_host` | 148 | 165 (+17: 4 settings, 5 palette, 3 look providers, 3 section, 1 picker, 1 probe) — 164 once the probe is deleted |
| `controller_app` | 382 | 383 (+1: the Settings card) |
| `tv_test_app` | 35 (+1 skipped) | 36 (+1 skipped: the Look and sound button) |

## Rule 3's check: what a round does with page routes

Nothing in a round pushes or pops a page route. The pause menu is a `showDialog` (a `PopupRoute`: no `didPush`/`didPop` of a page), the away card, the Get ready beat and the results are cards inside the round's screen, and the round's screen only leaves at the end of it (`pause_menu.dart`'s `popUntil(gamesRouteName)`, which is a pop). So a round never changes its palette half-way.

One place replaces a page instead of pushing or popping it: the join screen hands over to the round with `pushReplacement` (`join_screen.dart:276`), and the round's results hand over to the next round, or to the same round again, the same way (`puzzle_screen.dart`). A replacement is `didReplace`, which this observer doesn't hear, so the palette is not worked out again at that moment: a round that starts after 19:00 with a look last worked out in the morning keeps the morning palette until the next push, pop or setting change. That is at most one look behind at a round's start, and no colour inside a round changes. Question 1 asks whether `didReplace` should call back too; I left the observer as the brief describes it (`didPush`/`didPop`).

## The theme's type needed three boxes to give

Wiring the theme in changed every host screen's type (a card's title goes from Material's 24 to the look's 32, a button's label from 14 to 18). Three boxes could not hold it:

- **The game picker's cards** (`party_host`, `games_screen.dart`): a card was 380 × 180 with 20 px of padding, so 140 for a title (86 at the look's 32 in the test bundle's font), a 6 px gap and a subtitle (92) — 44 px too much, which failed every host and phone test that opens the picker. The box now has a **minimum** height of 180: I read the card's height with the look's own fonts in the fit test (180 exactly, probed once and the probe removed), so the app draws what it drew before.
- **The TV home's header buttons** (`tv_test_app`, `home_screen.dart`): six compact buttons instead of five no longer fit beside the title at 960 logical pixels (200 px over, and worse on a TV with the TV's 28 px labels). The buttons are a `Wrap` that takes at most 65 % of the header beside the title, so they run onto a second line. Five buttons were 960 px's fit before; six never can be.
- **The phone tests that measure layouts** (`controller_app/test`): the fit tests loaded Roboto, but the theme now names Fredoka and Nunito, which a test bundle doesn't have, so every word fell back to the bundle's box font and the picker measured 41 px and the join screen's sides 96 px of scrolling where they had measured none. `test_font.dart` now loads the look's two fonts from `toy_look`, and both are zero again. Two tests that open the join screen at 852 × 393 (a screen built to fit a phone's height, m12 bug 1107f) overflowed it by 59 px in that font and now load the fonts too.

None of the three moves a colour, a widget or a word, and with the app's own fonts the first two draw exactly what they drew before; I've listed them here because rule 7 said no screen restyled, and Claude may want them in 3b instead.

## Pinned colours

No existing test pinned a colour that changed: the phone's and the TV's suites passed on the look's theme without a single expectation edited. The new tests pin the look's own colours (Sunny's `background` (124, 200, 248) and Night's (36, 28, 94) through `canvasColor`), and the old seed (`0xFF5AAAFF`) is no longer anywhere: the three `ColorScheme.fromSeed` lines (both apps and the host harness) are gone.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** The look is the same on all of them: a TV host overrides `toyTvProvider` (the TV's type and sizes, `test/look_providers_test.dart`), a phone on "Play on this phone" and on "Show on this device" run the menu look and the host's own navigator's observer (that navigator's palette refresh is wired in `host_games.dart`; the host's screens under it are exercised by the whole phone suite), a joined phone is untouched (no protocol change, no phone screen changed but Settings), and a host one build older never sees any of it.
2. **When kept state starts and ends.** The palette is a value worked out at start, on a setting change and on a page route's push or pop, and never on a clock tick (`a page pushed after 19:00 turns the look to Night`, `Auto at 18:59 is Sunny, and stays Sunny at 19:01 with no page route`); the look settings load with the container and save on every change (`a change is saved under the look keys, and a new container reads it back`); the shader load ends either with the program or with the 5 s timeout (the apps pass `ToyShaders.none` then), and the font licences are not awaited at all.
3. **How a new state combines with the others.** Nothing here pauses, hides or waits on the game: the palette never changes inside a round (rule 3's check above), and the pause menu, the away card, Get ready and the results are dialogs or cards that leave it alone (`a dialog is not a page route: opening one leaves the palette alone`).
4. **Stay in the job's folder.** Only the folders in `allow:` and this report were written (`git status` below).
5. **Stop rather than overstep.** The brief's two rules met in the picker's card and the TV's header (above); I made the smallest box change that keeps every existing test green and reported it here rather than stopping, because neither is a design decision — with the app's fonts both draw exactly as before. Everything else followed the brief. The two readings I had to choose are questions 1 and 2, and the fonts question 3.

## Checks

- `tools/check.sh format analyze look kit host phone tv` — all PASS: format, analyze, kit 48, look 80, host 165, phone 383, tv 36 (+1 skipped).
- `tools/review.sh` — 1 fail, 9 note. The fail is not mine: `settings_sections.dart:19`'s `_HapticsSection.build` is 70 lines, as it was before this job (the file is in my diff only because the Look and sound card was added to it). The notes are the numbers in `games_screen.dart` (180, 20, 64, 6), `settings_screen.dart` (12) and `home_screen.dart` (8), all of them in code that predates this job, and `toyTheme` at 59 lines.

## Questions and suggestions

1. **`pushReplacement` doesn't refresh the palette.** The join screen hands over to the round and the round to the next one with `pushReplacement`, which is `didReplace`; the observer hears `didPush` and `didPop` only, as the brief says. Should `didReplace` call back too (one more `if (route is PageRoute)` in `route_observer.dart`, and a test)? It would make a round's first frame the right palette when it starts just after 7:00 or 19:00.
2. **`lookPrefsProvider`.** The phone app supplies the layer's `prefsProvider` only while it hosts (`phoneHostOverrides`), but the look's settings are read at the root, so I added a one-line seam (`lookPrefsProvider` → the layer's `prefsProvider` by default) that the phone's test harness swaps for the phone's own prefs. The app needs no override, since its root always applies `phoneHostOverrides`. If you'd rather the layer read `prefsProvider` directly, the phone's root has to override `party.prefsProvider` instead, and its hosting tests then trip "overridden twice".
3. **No shader loads under `flutter test`.** `FragmentProgram.fromAsset` returns null outside a device build, so "effects off drops the shader" can only be checked against what the device loaded: the test compares the look's `shade` with `toyShadersProvider.shade`, then with effects off reads null. A test that a real shader is dropped needs a device run.
4. **Should "Defaults" reset the look?** The phone's Defaults button puts every setting back but leaves `look.choice` and `look.effects` alone, since the section lives in party_host and the reset is the phone's own list. If the look's two belong in that reset, that's a 3b/7 decision.
5. **The TV's home header at 960 px.** Six buttons take two lines there now. 3c restyles that header; if it should stay one line, the answer is a smaller compact button, not a narrower wrap.
6. **The TV's tests run the phone look.** `tv_test_app`'s harness leaves `toyTvProvider` at false, so its screens are measured at the phone's type (18 px buttons). The TV's own type (28 px) is only checked in `look_providers_test.dart`. Overriding the flag true in the TV harness would make those tests closer to what a TV draws — for 3c, since several fits would have to be re-tuned.
7. **Suggestion, not done:** the phone's Settings list is long enough that a "Look and sound" card is below the fold on a 393 px-high phone; 3c restyles that list, and the card could move up beside the haptics card there.

## Commit message

Wire the look into both apps, and add the Look and sound setting

toy_look gains ToyPageTransitionsBuilder, so every page carries its own
sky through the platform's transition, and ToyLookRouteObserver, which
refreshes the palette on a page route's push or pop. party_host gains
LookSettings (kept in prefs), the look's providers (TV flag, shaders,
clock, palette at the set moments, the look itself), and the Look and
sound section on a TV page. Both apps load the shader before the first
frame, register the fonts' licences, and run in ToyLookScope and
toyTheme; the phone shows the section in Settings.

## Status row

| 3a | The look wired in: ToyLookScope and toyTheme at both roots, the shaders and font licences at start, a sky behind every page, Look and effects kept and shown on the phone and the TV (s3a-look-wiring.md) | **Done**: look 80 (+4), host 165 (+17), phone 383 (+1), tv 36 (+1); every check green; open: a `pushReplacement` doesn't refresh the palette (question 1), and 3b/3c still restyle the screens |

## Delete

- packages/party_host/test/zz_diag_test.dart

## Claude's review (Nov 8, 2026)

Accepted, with one change by Claude: **a replaced page refreshes the palette too** (question 1, yes). `ToyLookRouteObserver.didReplace` calls back for the new page, so a round started with `pushReplacement` after 19:00 starts in Night. Test, written first and failing: "a page replaced by another calls back, as the join screen hands over to a round". Checks: format, analyze, kit 48, look 81, host 164, phone 383, tv 36 (+1 skipped), all green.

Answers:
- 2: `lookPrefsProvider` is fine.
- 3: the shader drop is checked on a device.
- 4: no, Defaults is the phone's controls; the look stays.
- 5 and 6: in 3c, the TV's tests run with `toyTvProvider` true and the TV header is restyled to fit one line at 960 px if it can.
- 7: in 3c.

The review.sh fail (`_HapticsSection.build`, 70 lines) predates this job; 3c splits it when it restyles Settings.
