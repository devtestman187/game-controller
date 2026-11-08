job: M13 step 3a — both apps run in the look: ToyLookScope and toyTheme at the root, the shaders loaded and the font licences registered at start, a toy background behind every page, the Look setting kept and applied, and the Look and sound settings on the phone and the TV
stop: after it.
read: docs/design/look-and-sound.md sections 2 (D1, D5, D8), 4, 7 and 8 (the settings bullet) · docs/briefs/m13/s2a-tokens-and-theme-report.md and s2b-toy-widgets-report.md (what toy_look has, and Claude's reviews at their ends) · packages/toy_look/lib · tv_test_app/lib/main.dart · controller_app/lib/main.dart · packages/party_host/lib/src/providers.dart · packages/party_host/test/support/host_harness.dart · controller_app/lib/src/ui/settings_screen.dart and settings_sections.dart · controller_app/lib/src/host/host_games.dart · tv_test_app/lib/src/ui/home/home_screen.dart · docs/review-rules.md · docs/coding-guidelines.md

Step 3 moves both apps to the look in three jobs: 3a (this one) wires the look in; 3b restyles the host's screens and cards in party_host; 3c restyles the phone's menus and cards and the TV's home and test screens. In 3a no screen is restyled: buttons and cards stay as they are, they just get the theme's colours and fonts.

Claude's rules:
1. **A background behind every page, through the page transition** (toy_look): `ToyPageTransitionsBuilder extends PageTransitionsBuilder` whose `buildTransitions` hands `ToyBackground(child: child)` to the platform's default transition (`const PageTransitionsTheme().buildTransitions(...)`), and `toyTheme` sets `pageTransitionsTheme` to it for every `TargetPlatform`. The scaffold stays transparent. So each page carries its own opaque background and a page sliding over another never shows the one below through it. Dialogs and popups are unchanged (they're not page routes).
2. **The Look settings** (party_host, shared by both apps through `prefsProvider`): `LookSettings` (value: `LookChoice choice`, `bool effects`, defaults auto and true) and a `lookSettingsProvider` Notifier that loads them from prefs (`look.choice` as the choice's `.name`, `look.effects`) and saves on every change (`setChoice`, `setEffects`).
3. **The look in a provider** (party_host): `toyTvProvider` (bool, default false; the TV app overrides it true), `toyShadersProvider` (`ToyShaders`, default `ToyShaders.none`; each app overrides it with what it loaded), `lookClockProvider` (`DateTime Function()`, default `DateTime.now`; tests override it) and `toyLookProvider` building `ToyLook.build(palette: …, tv: …, shaders: …, effects: …)`. The palette is `paletteFor(choice, clock())`, but **only worked out again at set moments** (D1: never in the middle of a round): at start, when the Look setting changes, and when a page route is pushed or popped. Keep the resolved palette in a small Notifier (`lookPaletteProvider`, with `refresh()`), and add `ToyLookRouteObserver extends NavigatorObserver` (a `didPush`/`didPop` of a `PageRoute` calls `refresh()`). Both apps put it in their `navigatorObservers`, and the phone host's own `Navigator` in host_games.dart too. Check whether a round ever pushes or pops a page route while it runs (pause, results, away and ready are cards, as far as Claude knows) and say in the report what you found; if one does, stop and say so rather than working round it.
4. **Both apps' roots**:
   - `main()` loads the shaders before `runApp` (`await ToyShaders.load().timeout(const Duration(seconds: 5), onTimeout: () => ToyShaders.none)`: a slow TV box shows its splash a little longer rather than a stalled first menu) and overrides `toyShadersProvider` with them; the TV app also overrides `toyTvProvider` with true.
   - `main()` calls `registerToyFontLicenses()` (not awaited; it only fills the licence page).
   - The `MaterialApp` sits inside a `ToyLookScope` with the provider's look and takes `theme: toyTheme(look)`. The `ColorScheme.fromSeed(...0xFF5AAAFF...)` lines go (in both apps and in party_host's test harness, which gets the same scope and theme with a phone look).
   - Keep every `builder:` the apps have now (ControllerMenus, HostFocusScope) and the TV's `Shortcuts`.
5. **The Look and sound settings** (party_host): a `LookAndSoundSection` widget with **Look** (three choices: Auto, Sunny and Night, as a `SegmentedButton<LookChoice>`, with a line under it: "Auto: Sunny from 7:00 to 19:00, Night otherwise") and **Effects** (a `SwitchListTile`, "Shaders and menu motion. Turn off on an older device."). It reads and writes `lookSettingsProvider`. Step 7 adds the sound rows to it.
   - The phone: the section goes in SettingsScreen, in the same card style as the other sections, titled "Look and sound", above the stats section.
   - The TV: a `LookAndSoundScreen` in party_host (a page with a title and the section) and a "Look and sound" HostButton on the TV home screen's header buttons, before "Look test".
   - Both are worked with the remote and the phones like every other host screen (focus order top to bottom; the TV's activate shortcuts).
6. Strings: the new texts are plain literals for now; 3b brings in the string table and moves them.
7. Change nothing else: no screen restyled, no colour moved (the `color` check fails on any new colour literal outside toy_look: use the look's tokens), no game painter touched.

tests (each failing first):
- toy_look: a page pushed under a toyTheme has a ToyBackground under it and the scaffold is transparent; a dialog has none of its own.
- party_host: LookSettings load and save (defaults with empty prefs; a saved night and effects off read back; an unknown saved name reads as auto).
- The palette at the set moments, with a fake clock:
  - Auto at 18:59 is Sunny, and stays Sunny at 19:01 with no route change.
  - It turns Night when a page route is pushed after 19:00, or popped, and when the setting changes.
  - A dialog's push doesn't change it.
- toyLookProvider: the TV flag picks the TV type; effects off drops the shader.
- LookAndSoundSection: tapping Night saves night and the app's theme turns Night (a screen's `canvasColor`); the Effects switch saves.
- tv_test_app: the home screen has the Look and sound button and it opens the screen.
- controller_app: the settings screen has the section.
- The existing tests all still pass; fix any that pinned the old seed theme's colours, and list them in the report.

in the report: test counts before and after (look, host, phone, tv); the files changed; what rule 3's check found about page routes during a round; any test whose pinned colour changed.
self-check: docs/review-rules.md part A, items 1–5, one line each in the report with the test that shows it.
rules: no lib file over 400 · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s3a-look-wiring-report.md · packages/toy_look · packages/party_host · tv_test_app/lib/main.dart · tv_test_app/lib/src/ui/home · tv_test_app/test · controller_app/lib/main.dart · controller_app/lib/src/ui/settings_screen.dart · controller_app/lib/src/ui/settings_sections.dart · controller_app/lib/src/host/host_games.dart · controller_app/test
check: format analyze look kit host phone tv
report: docs/briefs/m13/s3a-look-wiring-report.md
