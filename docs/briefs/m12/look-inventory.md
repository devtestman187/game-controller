job: read-only — inventory how the apps look today, and fetch Flutter's shader facts, for Claude's look-and-sound design
stop: after the report.
read: packages/puzzle_game (Shape Race) · packages/party_host (menus, join, pause, results) · packages/game_kit · tv_test_app (Arena, TV screens) · controller_app (phone screens, host sheet) · packages/protocol/lib/src/messages.dart (playerColors) · every pubspec.yaml · docs/code-health.md "Look-and-sound" row · docs/review-rules.md row C1

What to do:
1. Screens: list every screen and overlay a player sees, by app (TV app, phone controller, phone host): file, one-line purpose, and whether it's a game board, a menu, a card/overlay or a pad. Include Shape Race's board and HUD, the Arena, home/game picker, join screen, lobby, pause menu, results, settings, host start sheet, cards (away, waiting).
2. How each is drawn: every CustomPainter (file, what it paints, the colours/strokes/shadows it uses and whether they're literals or come from a theme or constant); the ThemeData each app builds (colours, font, text sizes); shared constants (playerColors, any palette or style file). Count colour literals (`Color(0x`, `Colors.`) per package.
3. Existing motion: animations, the confetti, transitions, glow; where they live.
4. The Flutter version this repo builds with (pubspec environment, .fvmrc, CI files, codemagic.yaml), and any Impeller setting (AndroidManifest `io.flutter.embedding.android.EnableImpeller`, Info.plist `FLTEnableImpeller`, run flags). Fonts bundled (pubspec `fonts:`) and images/assets. No web fetching.

in the report: one table per part; then a 10-line summary: where the look lives today (scattered or central), the biggest obstacles to a re-skin, and every place a re-skin must touch for Shape Race and for all menus. Keep the report under 300 lines.
rules: change no file but the report.
allow: docs/briefs/m12/look-inventory-report.md
report: docs/briefs/m12/look-inventory-report.md
