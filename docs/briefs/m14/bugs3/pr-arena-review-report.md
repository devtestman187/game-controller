# pr-arena review — the three proposals, checked against the code

## Summary

**small fixes.** The three proposals stand: B-005's lockout is real (`arena_bumper.dart:106`), B-006's visit
maths is right (85.2 / 42.6 / 28.4 s), and B-015's "no code needed" is true (`arena_map_choice.dart:9-27`).
The corrections are in the test plan and in a few numbers, not in the picks.
- must 0 · should 4 · could 6
- The cat test the report says changes (a Party count in a 40 s round) cannot change to 3: only 10 s of a
  40 s round is left after the grace and tail, so `_due` drops the third 4.8 s visit (`pr-arena-report.md:58`).
- The Spinning Tops "no" rests on a start at x 0.075 being inside the carousel's sweep; the bar reaches
  x 0.3-0.7 at most and the map has no walls, so a race there would pass `check` (`pr-arena-report.md:68`).
- Party's on-screen line still says "knocks one placed piece back to the tray" (`host_text.dart:210`), and the
  report's file list for B-006 does not name it (`pr-arena-report.md:58`).

## Findings

- **should** docs/briefs/m14/bugs3/pr-arena-report.md:58 says `cat_test.dart`'s Party count in a 40 s round and its prose change with 3 visits, but a 40 s round leaves 10 s between `CatRules.graceS` and `tailS` and three 4.8 s visits need 14.4 s, so the plan is 20 / 21.7 / 23.5 s and `_due` (`cat_chaos.dart:197`) drops the third: the test still sees 2 → say the 40 s test keeps 2 visits and pin the new count with a 120 s-round test.
- **should** docs/briefs/m14/bugs3/pr-arena-report.md:68 rejects Spinning Tops because "a start at y 0.5 on the west edge sits in its sweep", but a spin mover's bar is ±`length`/2 round its pivot (`arena_pieces.dart:218`) so 0.3556 of the 90-unit field reaches x 0.3-0.7 at most, the map has no walls, and a start at [0.075, 0.5] is ~0.4 units clear, so `checkMap` would pass a race → give the real reason (the only sane finish is the post at [0.5, 0.5], and a goal there is inside the carousel's sweep, which no rule checks).
- **should** docs/briefs/m14/bugs3/pr-arena-report.md:58 lists `host_text.dart` for B-006 but not the line that becomes false: `chaosLine` says "on Party it also knocks one placed piece back to the tray" (`host_text.dart:210`), while Lively gives up to 2 knocks → name that line in Files and in the Change.
- **should** docs/briefs/m14/bugs3/pr-arena-report.md:28 gives the brief's check (`tools/check.sh format`) without its result → state pass or fail, as the a1 review asked of the same job line.
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:47 expects the take-back "at step 120 (2.0 s)", but a dropped coin is aged in the step it lands (`arena_bumper.dart:53`), so its `ageS` reaches 2.0 after 119 standing steps → either expect it at 119 or say "by step 120".
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:52 calls A little "default ... in a night", but it is the default in and out of a night (party-night §5) while `PuzzleSettings.defaults` is `Chaos.off` (`settings.dart:24`) and only the host's defaults set little (`puzzle_settings_provider.dart:16`) → say "the host's default, in and out of a night".
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:66 puts the press's sweep at x 0.75-0.93 and the crates' at x 0.622-0.838; a slide bar is ±16.2 px round its place (x 0.649-0.851) and the hazard radius is a shorter-side 0.038 (x 0.6386-0.8214) → correct the two ranges; the goal stays clear either way.
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:57 cites `party_host/lib/src/providers.dart:74` for how a define is read, but that line is a doc comment and `SHARE_VIEW` is read in `tv_test_app/lib/src/debug_start.dart:21`; the ready model for a debug-only preset is `HostingSettings.fromEnvironment` (`game_kit/lib/src/hosting_settings.dart:25`, `kReleaseMode`) → cite that and say the guard.
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:57 puts a "Cat" row "beside Chaos", but the Chaos card is itself titled 'The cat' (`host_text.dart:206`) → give the new row a different name ("Cat visits").
- **could** docs/briefs/m14/bugs3/pr-arena-report.md:82 answers the five part-A checks in one sentence, where guidelines §11 asks one line each with its test → five one-line answers ("not affected, report only" is fine).

## Decisions to confirm

- B-006's "Lively (new default)": it changes Party for every family that never touches the setting, and Question 1 still offers a fourth Chaos level instead — the owner should pick before code.
- B-015 reopens the owner's own Nov 9 answer in party-night §7b ("a corridor makes a dull bumper arena … the race stays on the Playroom"); the two races also need the owner's eye on renders before the map files change.
- B-005's 2 s is the report's pick, not the owner's: "allowed" may mean at once, and `dropLockS` is the only place that differs.
- B-006's `--dart-define=CAT_PRESET`: a build flag in the host's shipped settings path settles a playtest need that a preset in tests covers, unless the owner wants on-device tuning.

## Could not check

- Whether `tools/level.sh check` and `render` pass with the two proposed race sections: it needs the map files edited and the tool run, which a review may not do; the gate (2.23 marbles), gap, goal and piece numbers I recomputed by hand from the two files do hold.
- Whether the two races are good to play, and whether Block Castle's keep floor is the right finish: renders and play.
- The "0.456" clearance for the bumper starts in report:68: I could not reproduce it from `spinning-tops.json` (the nearest figure I get is 0.34-0.44, to the carousel and to an orbit hazard).
- Whether `tools/check.sh format` was run and passed: the report names it without a result.

## Commit message

Review pr-arena: proposals hold, the cat test plan and one reason do not

No code in the diff, so the review is of the report's claims against the
code. The B-005 lockout at `arena_bumper.dart:106`, B-006's 85.2 / 42.6 /
28.4 s and B-015's map picker are as stated. Corrections: the Party count in
a 40 s round cannot rise to 3 (three visits do not fit), the Spinning Tops
"no" rests on a carousel sweep that does not reach the start, the Party text
in `host_text.dart` still says one knock, and the format check has no result.

## Status row

pr-arena reviewed: B-005, B-006, B-015 proposals stand with fixes to the cat test plan, the Party text and the Spinning Tops reason (0 must, 4 should, 6 could); open: the owner's OK on the three decisions, then the code jobs.

## Delete

- none
