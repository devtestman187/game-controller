# race1a f1a: MatchFormat for 3v3, 4v4 and uneven sides

## Summary

MatchFormat gains `threeVsThree` ('3v3'), `fourVsFour` ('4v4') and `uneven` ('uneven'), with `split` true for all three.
`MatchFormat.of` now gives: 3 and 3 → threeVsThree; 4 and 4 → fourVsFour; 2 and 1 (either order) → twoVsOne; any other
unequal split → uneven. Solo, team, 1v1 and 2v2 are unchanged. `HostText.formatName` labels them "3 vs 3", "4 vs 4" and
"uneven sides". The doc comment now says "up to four players" instead of "at most two".

Tests first: the new cases were added and `tools/mine.sh` failed on the base (undefined constants, test load failed in both
packages). After the change, `tools/mine.sh` passes: 20 tests in puzzle_game, 6 in party_host.

Computed test values (`MatchFormat.of`, left vs right):
- 3v3 → threeVsThree; 4v4 → fourVsFour
- 2v1 → twoVsOne; 1v2 → twoVsOne
- 3v2 → uneven; 4v1 → uneven; 4v2 → uneven; 1v3 → uneven

## Files changed

- `packages/puzzle_game/lib/src/match.dart`: three enum values, the new `of` rules, doc comment fixed. 309 lines.
- `packages/party_host/lib/src/text/host_text.dart`: three `formatName` arms. The file was 381 lines (over the 380 gate
  before this job), so four two-line doc comments near `formatName` were reflowed to one line each (text unchanged):
  "The same in a title…" (anyPuzzleTitle), "A joining player's row…" (playerLabel), "A player whose phone dropped…"
  (awayLabel), "The button that takes a series on to…" (continueTo). Net: 381 → 380 lines.
- `packages/puzzle_game/test/match_test.dart`: split expectations for the three new formats, and a new test
  "a side of three or four has its own format, and any other unequal split is uneven" with the 8 cases above.
- `packages/party_host/test/host_text_test.dart`: three `formatName` expectations ('3 vs 3', '4 vs 4', 'uneven sides').

`match_round_test.dart` is unchanged: no existing round test broke.

## Checks

- `tools/mine.sh`: RESULT ok (4 files formatted, 2 packages analyzed with no findings, 2 packages tested, 6 + 20 tests pass).
- Before the change, `tools/mine.sh` failed on the new cases (undefined enum constants), as the tests-first step requires.

## Decisions

- The new test is one `test()` with a local `sidesOf(left, right)` map builder, so each split is one line.
- Reflowing comments, rather than deleting text, was the way to hold the file at 380 lines.

## Questions

1. The three new formats have `split` true, so 3v3, 4v4 and uneven boards use the split-screen race layout. Is the split
   layout sized for three or four players a side? Nothing here checks that; it needs a look on the TV and on a phone.
2. The `uneven` label is "uneven sides" as the brief says. Is that the wording the design wants for a 3v2 race?

## Suggestions

- A UI check of the join screen and split screen at 3v3 and 4v4 (review-rules item 6) belongs in the next wave, since this
  job changes text and enum only.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

race1a f1a: MatchFormat for 3v3, 4v4 and uneven sides

Add MatchFormat threeVsThree, fourVsFour and uneven so a 3v3 or 4v4 race no longer
reads as 2 vs 1. Any other unequal split is uneven. formatName labels them "3 vs 3",
"4 vs 4" and "uneven sides". Four doc comments near formatName are reflowed so
host_text.dart stays at 380 lines. Tests were added first and failed on the base.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- race1a f1a: MatchFormat has 3v3, 4v4 and uneven with labels, tests pass (mine.sh ok). Open: split-screen layout at 3v3/4v4/uneven not checked on a TV or phone.

## Delete

- none
