# pr-map-pick — proposal for B-011 (report only)

Job: M14 bugs5 pr-map-pick. No code was changed; the only file written is this one.
Read for it: docs/design/party-night.md §2 (N6) and §7b; docs/PRD-v2.md "Milestone 14" (G10, the
Arena's map picker) and "Milestone 15"; the B-009 proposal in
docs/briefs/m14/bugs3/pr-shape-report.md; the Shape Race picker, the results card and the Arena's
map picker.

## Summary

- **B-011 (random or next after a stage):** today the picker offers a level's "Any Easy puzzle"
  (random, 1 of 6) and one button per puzzle (`games_screen_widgets.dart:176-188`); once a specific
  puzzle is picked, **every** way out of the results replays it — Rematch/Play again
  (`puzzle_screen.dart:230-243, 274-279`) and Change teams (`:281`) keep the same `PuzzleChoice` —
  and Back to the picker is the only way on. Nothing remembers the last stage played, so no "next"
  exists at all (the Arena has both patterns: Surprise me, `arena_map_choice.dart:9-29`, and a saved
  `lastMapId`, `arena_settings_provider.dart:108`). **Pick:** a **Surprise me** button (a bag draw,
  B-009: no repeats in a level's cycle) and a **Next puzzle** button (the level's next in index
  order, wrapping) on the picker's level card, and the same two on the results card after a
  specific pick, with every round recording its stage as the level's last. **Risk:** the results
  card grows from 3 buttons to 5 on an owner-approved mock-up (party-night.md:5: a mock-up change
  goes back to the owner), and "Next" follows the library's index order, which is no difficulty
  ramp (B-012c leaves that to M16).
- Today the automatic pick happens only at a Surprise me round's start, once
  (`puzzle_screen.dart:152-160`, an unseeded `Random()` at `:89`); the Look's **Auto** (Sunny/Night)
  changes colour only, so it chooses no stage and leaves the bag and the last stage alone (B-009).
- Computed values: 6 puzzles a level; Easy in index order house → rocket → tree → sun → fish →
  snowman → house, Medium boat → car → robot → train → castle → butterfly → boat; an "any" round's
  next is 1 of the 5 others (20% each); with the bag the 7th draw differs from the 6th; the results
  card goes from 3 buttons to 5 on a specific-pick round and keeps 3 on a Surprise me round.
- Checks: `tools/check.sh format` — PASS (report only; no Dart changed).

## Decisions (low-usage mode)

- Two names, not one: **Surprise me** draws from B-009's bag (a stage the level hasn't played this
  cycle), **Next puzzle** walks the level's own index order. The owner asked for both words, and a
  single button could only be one of them.
- "Surprise me" replaces "Any Easy puzzle" rather than sitting beside it, because the owner's ask
  ("need a way to pick a random map") reads as not seeing the random button, and the Arena's card
  already says Surprise me, so the two games say the same word.
- The first results button keeps its place, focus and meaning; the new pair comes after it, so a
  child's A press does today exactly what it did before.
- A night is untouched on the results (its one Next to the scoreboard, `puzzle_screen.dart:231-233`):
  a night picks its Shape Race stage on the picker (N6), so it gets both new choices there.
- Every round records its stage, however it was chosen, as the level's last and moves it to the bag's
  end, so Surprise me keeps its no-repeat promise after hand-picked stages (B-009 said a hand-picked
  stage is not drawn from the bag; this only adds the note).

### B-011 — Random and Next after any stage

**Today:** a level card holds "Any <level> puzzle" (random, `games_screen_widgets.dart:176-182`) and a
button per puzzle (`:183-188`); the round draws once if no id was picked (`puzzle_screen.dart:152-160`).
An "any" round's first results button is Next puzzle (another of the level, `:236-238`), but a specific
round's is Rematch/Play again (`:239-241`), which replays the same stage, and Change teams keeps the
same choice (`:281`), so a family that picks Castle can only play Castle again or go Back.
**What changes (player-visible):** (1) **Picker**, on each level card: **Surprise me** (random — a
stage this level has not played this cycle, B-009's bag) and **Next puzzle** (the stage after the last
one played in that level; the level's first if none; wrapping at the end); the puzzle buttons stay.
(2) **Results, outside a night**, after a specific pick: **Next puzzle** and **Surprise me** join the
card beside Play again/Rematch, with the same teams (Change teams still goes to the join screen),
the buttons wrapping on a narrow card; a Surprise me round keeps its 3 buttons.
(3) Every round records its stage as its level's last, so Next continues from any round.
**Options:** **A (pick)** both buttons in both places, the last stage kept in the host's prefs;
**B** one Next meaning a bag draw (half the work, but no set in order); **C** a Change puzzle button
back to the picker (two screens for one choice). Pick A: the owner's words, and it copies the
Arena's Surprise me and `lastMapId` (`arena_map_choice.dart:9-29`, `arena_settings_provider.dart:108`).
**Files touched:** `games_screen_widgets.dart`, `host_text.dart`, a new part `puzzle_continue.dart`
(`puzzle_screen.dart` is 399 of 400 lines, so the choice logic cannot grow it), its `_ResultButtons`
row → `Wrap`, B-009's `puzzle_bag.dart` (the draw, plus `played(level, id)`), tests.
**Tests:** Next with no last stage plays house, after sun plays fish, after snowman wraps to house; 6
Surprise me draws give 6 different Easy stages and the 7th differs from the 6th; a hand-picked house
then Surprise me never returns house before the other five; a specific round's results shows both
buttons, neither playing the stage just played; a night's results keeps one Next; the last stage
survives a restart, an unknown id falls back to the first, and a phone host draws the card without overflow.
**Risk:** the card's new buttons change an owner-approved mock-up (party-night.md:5), so the owner
must approve the card; "Next" in index order is no difficulty ramp until B-012c/M16; the rename
changes words the family has seen since M13 (`join_screen.dart:373-376` follows it).

## Questions

1. Is the results card allowed 5 buttons on a specific-pick round (Play again, Next puzzle, Surprise
   me, Change teams, Back), or does the owner prefer option B's single Next?
2. Should "Next puzzle" follow the library's index order (my pick), or should it draw from the bag
   like Surprise me, so a set is never played in the developer's order?
3. Does "Surprise me" replace "Any Easy puzzle" (my pick), or does the old label stay beside it?

## Self-check (review-rules part A)

1. Every host setup: no code changed; the choice is made on the host's screen and nothing goes over
   the wire, so a TV host, a phone host and joined phones see the same stage.
2. Kept state: the bag and the last stage start empty/first and persist in the host's prefs, written
   once at a round's start; nothing runs between rounds.
3. New state combined: nothing pauses, hides or waits; a draw happens once, when a round's stage is
   chosen, beside the existing night and pause owners.
4. This folder only: the only write is this report.
5. Stop rather than overstep: nothing needed outside `allow:`; no blocking contradiction found.

## Commit message

M14 bugs5: proposal for random and next stage choices in Shape Race

Report only, no code. Answers the owner's idea: after picking a specific Shape Race
stage, the family can only replay it, and the random option is named "Any Easy
puzzle". Proposes Surprise me (a B-009 bag draw: no repeats in a level's cycle) and
Next puzzle (the level's next in index order, wrapping) on the picker's level card
and on a specific pick's results card, with every round recording its stage as the
level's last. Values, files and risks are in
docs/briefs/m14/bugs5/pr-map-pick-report.md.

## Status row

B-011 (Shape Race random and next stage) is proposed in full: Surprise me (bag draw) and Next puzzle (index order) on the picker and on a specific round's results, with the last stage kept on the host. Open: the owner's OK (and the three questions), then the job, which lands with or after B-009's bag.

## Delete

- none
