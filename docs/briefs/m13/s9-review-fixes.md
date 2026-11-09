job: M13 step 9: fix what the full review found (m13-review-r1, r2 and r3 reports), as Claude decided below
pub: no
stop: after it.
read: docs/briefs/m13/m13-review-r1-report.md, m13-review-r2-report.md, m13-review-r3-report.md (each finding's file and line) · docs/design/look-and-sound.md sections 2 (D1, D13), 4, 6, 7 and 8 · docs/review-rules.md · docs/coding-guidelines.md

Where it stands: the three reviews are read-only and fixed nothing. The owner has since changed the sound settings (commit a531f80): Mute, a Sounds volume and a Music volume. That settles r2 Q1 and r3 Q1; leave the sound settings as they are.

Claude's decisions (do each, test-first where a behaviour changes):

From r1 (the look and the games):
1. **must:** split `_PlayerRow.build` in `test_game/lib/src/arena_hud_widgets.dart` under 60 lines (the avatar, the name line, the cell), with no change to what it draws.
2. **The shader per draw stays** in `toy_shape.dart`: one shape, one `FragmentShader`, its uniforms set before its own draw. That's safe on every backend whenever the uniforms are read, and Windows measured 1.2 ms frames. Make the two comments agree with that, in `toy_shape.dart:64-66` and `toy_background.dart:216-224`: the sky has one shader because it has one draw per frame.
3. **The glint:** the shader's must match the fallback's (design 1: "one small white glint"), 8 % × 5 % of the bounds at alpha 0.75. Change `packages/toy_look/shaders/toy_shade.frag` lines 49-52 to that size and alpha, and say in the report what you changed. Claude checks it on Windows.
4. **The moments' clock stays local** (the view's `Stopwatch`): a boing or sparkle must finish after the round's clock stops (the last piece, time up). Add a "Decided at step 9" line to design section 6 saying so: moments under 0.5 s age on the view's clock, and anything longer, including M14's pop-ups, ages from the snapshot. No code change.
5. **`defaultArenaLook` goes.** A screen without a `ToyLookScope` throws, as the puzzle's views do. Fix its doc, and any test that leaned on it.
6. **Hint glow:** a test that paints a hint target and finds its glow (the focus fill), and finds none without the hint.
7. **One dash:** `puzzle_painter.dart:226` and `arena_painter.dart:234` use toy_look's `paintDashedEdge`, and their private helpers go. Keep the drawn dash lengths; if they differ from `toyDashOn`/`toyDashOff`, pass the old ones.
8. **`match_hud.dart`'s numbers** become named constants with a doc line each.
9. **Later, do now (cheap):**
   - `mirror_painter.dart` uses the `px` it already holds;
   - the arena mat's dot colour comes from a token: add `matDot` to `ToyColors` if needed, with its value per palette as today;
   - remove the stale `_mark` doc comment;
   - `arena_character_test` checks the accessory is the player's (compare with `ToyCharacter.forPlayer`'s silhouette as toy_look's test does), not just "some ink".
10. **Reduce-motion in the games:** no change. The design binds reduce-motion to the widgets and the sky, and the games follow the effects setting.

From r2 (the host):
11. `away_card.dart:19`: `'OK'` becomes `HostText.ok`.
12. **The countdown stops at once when the host app is hidden**, as the music does. Stop it from `Pausable`'s host-away listener (`_noteHostAway`), not only from `_beat`. Test: host away during the beat calls `stop('countdown')` with no tick in between.
13. **`LobbyMusic.dispose` stops the loop** if it wants one (it calls `stopLoop()`). Test: dispose the host scope with the loop playing, and the fake's loop is null. Fix the doc at line 144.
14. **The focus wash:** `toyTheme` sets `focusColor` to the look's `focus` token at a strength that reads from the couch (`toyShadowAlpha` or stronger; say which), so the Material controls (choices, switches, sliders, the back arrow) light in the look. Test it in `toy_theme_test`, in both palettes.
15. **assets/CREDITS.md:** move the six puzzle audio rows into the table under the heading, keeping their order after the arena's four.
16. **The scoreboard hold** waits for M14 G2's design. Add one line to docs/briefs/m14 (the touchpoints report's sound row, or a short note file) saying a scoreboard between rounds needs a lobby-music hold of its own.

From r3 (the apps):
17. **must:** `tv_test_app/lib/src/ui/shader_spike_rows.dart:117` takes `look.colors.player(n)`, not `Color(playerColors[...])`.
18. **The phone's sky holds only in a round.** Move `ToyStillSky` off the whole `ControllerScreen`: it wraps the pad (the controls over a game) and the joined view only. A hosting phone's picker, join screen, Shape Race list and stats drift like the TV's. Its own round is held by `PuzzleScreen`/`GameScreen` already. Tests: a hosting phone's picker drifts; the pad and the joined view hold it.
19. **The prefs link runs in a test:** one phone test pumps the app with the real root overrides (`host/host_overrides.dart` and `main`'s), not the harness's own `lookPrefsProvider`. It shows Look and sound reads and saves this phone's prefs, hosting and joined. Keep the harness override for the rest.
20. **The font licences ship:** `toy_font_licenses_test` loads both `OFL.txt` files through `rootBundle` (the package's assets), not a fake loader.
21. **The TV at 1280 × 720:** `tv_fit_test` gets the 1280 × 720 case for the header (at most two rows), the title in full, and the tiles in view, beside the 960 × 540 one.
22. **A round's palette is frozen on every device** (D1: never mid-round; r3 Q3):
    - `LookPaletteNotifier.refresh` does nothing while a round is on;
    - on the host, a round is on while `PuzzleScreen` or `GameScreen` is mounted (`RoundHold`'s count, shared with the lobby music, or a hold of its own);
    - on a joined phone, while its joined view or pad over a game is shown;
    - the first route change after the round refreshes as usual.
    Tests: at 18:59 a round is on, Settings pushed at 19:01 keeps Sunny; back at the menu after the round, the next push turns Night. Do it on the host and on a joined phone.
23. `controllers_panel.dart:113`: say why the `!` is safe (ToyType sets every size), or read the size without `!`.

tests: each above that changes behaviour, failing first. All existing tests pass (look, puzzle, arena, host, phone, tv, kit). List any you change, and why.

in the report:
- test counts before and after;
- the files changed;
- each numbered item: done, with its test, or why not;
- the shader change (lines before and after);
- the focus strength chosen.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder.
allow: docs/briefs/m13/s9-review-fixes-report.md · docs/design/look-and-sound.md · docs/briefs/m14 · assets/CREDITS.md · packages/toy_look · packages/puzzle_game · packages/test_game · packages/party_host · controller_app/lib · controller_app/test · tv_test_app/lib · tv_test_app/test
check: format analyze look puzzle arena host phone tv kit
report: docs/briefs/m13/s9-review-fixes-report.md
