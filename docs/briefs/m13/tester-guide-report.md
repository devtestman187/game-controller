# M13.4 tester guide for build 345 — report

Done at the gate. `site/index.html` now describes 0.13.0 (build 345) only, section by section, and
opens with six pictures of the real screens, drawn by a widget test from the apps' own widgets and
checked byte for byte between runs. Two tests guard the page (its links, and the picture row), and
all checks pass.

**One thing to delete by hand:** an early run of the picture test used the wrong relative path and
wrote six PNGs to `E:\AI\game-controller-m13-jobs\site\shots\` — one folder *above* this job's
folder, outside `allow:`. The working directory was fixed (`../site/shots` from `controller_app`)
and every picture since is in `site/shots/`, but the stray copies are still there and I can't reach
or delete them (my tools are limited to this job's folder). Please delete that folder:
`E:/AI/game-controller-m13-jobs/site/shots` (it holds only `dpad.png`, `join.png`, `menus.png`,
`results.png`, `sticks.png`, `tilt.png`, all written 2026-11-10).

## The pictures

All six are TV frame + phone frame side by side on the Sunny background (`#7CC8F8`), 1440×576, with
the TV screen rendered at 960×540 and scaled to 720×405 and the phone at 852×393 scaled to 486 wide.
Each is drawn twice per run and the bytes compared, and each screen is captured twice and compared,
so a change in layout or fonts fails the test rather than drifting the picture.

| file | shows | caption | bytes | md5 |
| --- | --- | --- | --- | --- |
| `join.png` | the TV's Join screen (train, Left/Right sides) and the phone's code entry typing 0427 | Players join by pressing A, with no TV remote needed. | 208727 | d163a7682b826dad0562e9481e4406e4 |
| `dpad.png` | a live two-player race on the TV, the phone in D-pad | Shape Race on the TV, with the D-pad on the phone. | 197465 | c7183a8e255294598e56fa171ddd28ad |
| `tilt.png` | the same race, the phone in Gyro | The same race, steered by tilting the phone (Gyro). | 201633 | 4acd65f6dbf8d3044776e53b7296991d |
| `sticks.png` | the same race, the phone in Sticks | The same race again, with the two sticks. | 207050 | cd6e7fa60f83dec625b4483b34254f21 |
| `menus.png` | the TV's Play screen (Shape Race + Arena cards), the phone showing OK/Back | The TV's menus work from the phone: A says OK, B says Back. | 245023 | 512fe21c3ad500ce35eca3b5a32e9868 |
| `results.png` | the results card with both sides' times and Rematch, the phone's controls | When a round ends, the TV shows the times and a Rematch. | 193755 | 21b39ae2944896841faa14ac7f15bf29 |

Every file is under 300 KB (largest 245 KB) and 1440 px wide. Four runs gave the same six hashes.
The page shows them in a `repeat(auto-fit, minmax(300px, 1fr))` grid, one column at phone width,
each with alt text.

**Alt text**, in page order: "The TV's Join screen with a Left and a Right side, beside a phone
typing the TV's four-digit code.", "A two-player Shape Race on the TV, with the D-pad on the phone.",
"The same race on the TV, with the phone held up to steer by tilting it.", "The same race on the TV,
with two analog sticks on the phone.", "The TV's Play screen with a Shape Race card and an Arena
card, while the phone above it shows OK and Back.", "The TV's results card with both sides' times
and a Rematch button, beside the phone's controls."

## Guide text: every change and why

The page is for families, so the new text stays short and plain. What the code says:

1. **Lead**: now names the build ("The pictures are of **0.13.0 (build 345)**"), as the brief asks.
2. **Picture row** above the first setup step, six figures (see above).
3. **"Install TestFlight" is no longer a link.** `apps.apple.com/app/testflight/id899247664` is not
   named by any doc (docs/release.md gives only the public join link), and the link test allows only
   `site/` files and addresses the docs name. The words stay; the join link does the work.
4. **New "What's in this build"**: twelve puzzles, six Easy and six Medium (`packages/puzzle_game/
   puzzles/*.json`: fish, house, rocket, snowman, sun, tree / boat, butterfly, car, castle, robot,
   train — there are no Hard puzzles; Easy outlines are coloured, Medium grey, `Level.
   colouredOutlines`); the Arena (`HostText.arenaLine`, one player, needs a paired
   phone to steer, arrow keys + Space on a PC); music (`MusicLoop`: lobby on the picker and join
   screen, round/hurry/final in a round); Sunny/Night/Auto (`HostText.look*`); tablets
   (`wholeMatchProvider` is true on a tablet, `gyro.dart` makes sticks a tablet's first layout);
   buzzes (haptics, with the flash fallback for iPads and motorless tablets, project notes).
5. **Step 3, "On the TV, open Test game" is wrong and gone.** The TV home's button is **Play**
   (`openPlay` → `GamesScreen`), which offers **Shape Race** and **Arena**; the sentence now says
   that, and a new line says the phone's **A** does the same as the remote.
6. **"a 4-digit code" → "a Pairing code of four digits"**, the TV's own words (`TvText.pairingCode`,
   `_codeFrom` pads to four).
7. **Discovery names**: "a TV, a PC, or a phone or tablet that hosts" (`PhoneText.kindTv/Pc/
   Phone/Tablet`), and each player now joins on their own phone.
8. **Modes**: "**D-pad**, **Gyro** (tilt the phone to steer) or **Sticks**. Everyone can pick their
   own." (`PhoneText.dpad/gyro/sticks`; the mode is saved per phone).
9. **Joining**: new last step — pick a level and a puzzle (or any puzzle of a level), each player
   presses **A** on their phone to join, left/right picks a side, **A** or **Start** begins
   (`JoinScreen._tap`, `HostText.hint`).
10. **New "No TV remote?" paragraph**: the phones work every TV menu (`ControllerMenus`, `menuLayout`:
    A says OK, B says Back; the D-pad or left stick moves).
11. **Step 4**: the tablet exception on "Play on this phone" (a tablet host draws the whole match,
    `host_overrides.dart`), and a new step that the host's **Play** works the same as on a TV.
12. **Sounds sentence**: "In a round, the game's sounds play on every phone" — a joined phone plays
    each frame's sounds (`joined_view.dart`, the party sound player).
13. **New "Settings" section**: the phone's sections with their real names (`SettingsText`: Look and
    sound, Haptics with Try, Gyro, Sticks, Game on this phone, Control stats, About, Defaults reset),
    and the TV's **Look and sound** plus the test buttons it sits beside (`home_screen.dart`
    `_headerButtons`).
14. **"If something doesn't work"**: a new bullet for a phone without the motion sensor
    (`PhoneText.gyroUnavailable`).
15. **"Tell us how it went"**: the version is **under the pairing code on the home screen**
    (`pairing_panel.dart` shows `TvText.buildLine` at the panel's foot) — the old "at the top of the
    home screen" was wrong. The Diagnostics path is now the heart-with-a-pulse button on the connect
    screen and on the controller bar (`connect_screen.dart`, `controller_top_bar.dart`), and the
    buttons are named as the app names them: **Copy report** and **Share log** (`SettingsText`).
16. **Privacy**: a closing line and a link to `privacy.html` in the feedback section too.
17. Kept as they were (checked): iOS 26 / Android 12 (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`,
    `minSdk = 31`), the firewall and SmartScreen steps, the manual address, the 30-second host lock,
    and all working links (`docs/release.md`, the GitHub Release).

## What doesn't exist in build 345

- **"Test game"**, the old step 3 destination: no screen has that name. The picker is **Play**.
- **A mode called "tilt"**: the phone calls it **Gyro**. There is no fourth mode.
- **Arena party play**: one player only, and it needs a paired phone to steer.
- **Hard puzzles**: none of the twelve is Hard, though the level list has the level.

## Tests

- `controller_app/test/site_shots_test.dart` (6 widget tests) with
  `controller_app/test/support/site_shots.dart`: pumps the TV screens from `party_host`
  (`JoinScreen`, `PuzzleScreen` over a seeded `PuzzleMatch`, `GamesScreen`) and the phone from
  `ControllerApp`, captures each through a `RepaintBoundary`, draws the two frames into one picture
  and writes `site/shots/<name>.png`. Each test asserts both captures match, both drawings match,
  and the file is under 300 KB. First run: all six failed (nothing written, then a wrong folder,
  then a RangeError on the Sun's four pieces — the round moved to `train`).
- `controller_app/test/site_guide_test.dart` (2 tests): every `href`/`src` opens a `site/` file or an
  address `knownLinks` lists with its doc (and a `#jump` has its id, a `mailto:` writes to
  `mrman187@gmail.com`); and the page's figures number 4–6, each with a non-empty one-line caption
  and alt text, all before the first `<h2>`. First run: both failed — the App Store link was not
  allowed and the page had 0 figures.

| check | result |
| --- | --- |
| `format` | PASS |
| `analyze` | PASS |
| `host` | PASS (270 tests) |
| `phone` | PASS (446 tests, was 444) |

## Decisions

- **Six pictures** (join, three modes, menus, results): the brief's five bullets, with one picture
  per input mode; the cap allows 4–6.
- **The join picture's TV half is `party_host`'s Join screen**, not the TV home's pairing-code panel:
  the panel lives in `tv_test_app/lib/src/ui/home/pairing_panel.dart` and this job may only add
  tests in `controller_app/test` and `packages/party_host/test`. The phone half is the real code
  entry with 0427 typed, so a phone joining is in the picture; the pairing code itself is not.
- **The three mode pictures show the same live two-player race** (`train`, `Random(7)`): it gives
  gameplay with 2+ players in every picture, and each phone layout is the one the running round
  sends (`fake.gameHost.layouts['p1']`), not a hand-made one.
- **Effects off in the pictures** (`LookSettingsNotifier.effectsKey: false` seeded in the test's
  preferences): the puzzle view reads a real `Stopwatch` for `nowMs`, so piece bounces and worker
  blinks differed between runs. With effects off every run's bytes match.
- **1440×576, not 1600 wide**: at 1600 `menus.png` was 322 KB, over the brief's limit; at 1440 the
  six are 193–245 KB.
- **Sunny only**, as the brief says.
- **The App Store TestFlight link was dropped** rather than allowed: no doc names that address.
- **Music wording** names the hosting device, because the picker and round music are shared by both
  apps (`LobbyHold`, `RoundHold` in `party_host`), so a phone host plays it too.

## Self-check (docs/review-rules.md part A)

- **4. Stay in the job's folder.** Changed only `site/index.html`, `site/style.css`,
  `site/shots/*.png` and the three new test files under `controller_app/test` (and this report).
  One mistake, disclosed above: a first run with the wrong relative path wrote six PNGs to
  `E:/AI/game-controller-m13-jobs/site/shots`, outside the job; it was fixed immediately and no
  later run wrote outside `site/shots`. `git status` also lists the three
  `tv_test_app/windows/flutter/generated_plugin*` files, which `flutter pub get` (run by `flutter
  test`) rewrote: `git diff` shows no content change, only line endings.
- **5. Stop rather than overstep.** Nothing outside `allow:` was edited. Where the brief's picture
  (a) needed a `tv_test_app` screen, I chose the nearest screen this job can pump and said so here
  rather than editing another folder; the tag's notes were not read (`git tag` is off limits), so
  the build's content came from the code, and the one fact only the tag could settle is a
  question below.

## Questions

1. May the stray folder `E:/AI/game-controller-m13-jobs/site/shots` be deleted? It is outside this
   job's `allow:` and outside my tools' reach; it holds six PNGs from the first, wrongly-pathed run.
2. Do you want the TV home's pairing-code panel in `join.png`? That needs a screenshot test in
   `tv_test_app/test`, which this job's `allow:` does not cover.
3. Should the App Store link for TestFlight come back? Then `apps.apple.com/app/testflight/
   id899247664` needs a line in a doc (docs/release.md or store-listing.md) so the link test can
   name its source.

## Suggestions

- `tools/check.sh` (`format`) prints "Changed …" when it *would* change files: running
  `dart format` on the job's files first saves a failing round.
- A small `tools/site_check.host` step (the two guide tests) would catch a broken published link
  before Pages publishes it, not only in the phone check.
- The Arena's "one player" line is the only place the guide promises less than the game will do:
  worth revisiting when M14's Bumper Round lands.

## Commit message

```
Tester guide: build 345 text, six real pictures at the top

site/index.html now describes 0.13.0 (build 345) only: Play and its two
games, the twelve puzzles, the pairing code, D-pad/Gyro/Sticks, both host
setups, Settings, Diagnostics and privacy.
Six pictures (join, three modes, menus, results) are drawn from the apps'
own widgets by a widget test and written to site/shots/, byte-identical
between runs, each under 250 KB, in a responsive grid with alt text.
Two tests guard the page: every link resolves to site/ or a doc's address,
and the pictures come first with one-line captions.
```

## Status row

- **Nov 10:** the tester guide is rewritten for m13.4 build 345 with six rendered pictures at the top and two guard tests (phone 446); open: the six stray PNGs in `E:/AI/game-controller-m13-jobs/site/shots` need deleting by hand, and whether `join.png` should show the TV home's pairing panel (needs a `tv_test_app` test).

## Delete

- none
