## Summary

small fixes

must 1 · should 1 · could 3

- **must** three of the seven new tests pass on the old code (the brief's item 1 forbids it) and repeat pins that already exist.
- **should** the card's comment and the report's decision 2 give the join screen's button order backwards, so the stated reason for Back's place is false.
- **could** the TV card's ready line moved right of the card's centre while the report says it "reads as before"; `_cardBody` is 56 lines; one self-check line cites a test that never looks at `arenaBack`.

Checks I ran: `arena_back_test.dart` + `arena_row_touch_test.dart` 7/7 pass; the five named Arena files 27 tests, `arena_touch_solo_night_test.dart` 1, all pass; `tools/check.sh host` PASS (489 tests, 46 s); `dart format` on the four changed files, 0 changed; `flutter analyze` in party_host, no issues.

## Findings

- **must** packages/party_host/test/arena_row_touch_test.dart:73, :84, :94 three of the seven new tests (the card's Ready button, a joined phone's A on the focused row, the remote's OK/Enter on it) pass on the old code and repeat pins that already exist (arena_touch_ready_test.dart:69 and :93, arena_waiting_test.dart:73), against the brief's item 1 "each must fail on the old code" → keep only the own-row rule in the new file and leave those three paths to the existing pin files, so every test in it fails without the fix.
- **should** packages/party_host/lib/src/ui/arena_waiting_card.dart:273-274 the comment says Back stands first "as the join screen's does before its Start", but the join screen puts its Start left of its Back (join_screen_widgets.dart:275-287), and the report's decision 2 quotes that order and then places Back first → give the comment and decision 2 a reason that matches the code (Back left of Ready, which keeps the Ready button where a thumb expects it).
- **could** packages/party_host/lib/src/ui/arena_waiting_widgets.dart:110 the doc says the TV line "stays centred" and the report says the TV card "reads as before", but the line is now centred in the `Expanded` right of the Back button (112 px plus the 12 px gap, by the report's own values), so it moves about 62 px right on every TV card → say so in the doc, or pin the line's place in a TV test.
- **could** packages/party_host/lib/src/ui/arena_waiting_card.dart:262 `_cardBody` is 56 lines, up from 52, against the guidelines' about 40 per function → split the roster, Robo and map rows into their own widget, or record the length as debt in code-health.md.
- **could** docs/briefs/m14/bugs13/arena-waiting-report.md:117 the self-check says a "Show on this device" phone shows Back, citing "arena_touch_ready_test.dart 'a phone that only shows the game has no Ready button'", but that test (arena_touch_ready_test.dart:144-156) never looks for `arenaBack` → cite arena_back_test.dart:40-52, which renders the same no-own-player card and asserts the key.

## Decisions to confirm

- Decision 3, Back on every host: it is a visible change to frame 8's TV card, not only the touch host's, so the owner may want it gated on `hostTouchFirst`.
- Decisions 1–2, Back under the mode row and left of Ready: the place is workable, but the join-screen precedent quoted for it is reversed; confirm which side of Ready is wanted.
- Decision 4, `IgnorePointer` around the own row (the owner's option A): it also makes the whole row dead to a thumb, so the Ready button is the only touch path to ready and unready; confirm that is "a status label".
- Decision 7, no pin rewritten: true (no test taps the own row; `tester.tap` on `arenaPlayer` appears only in the new file), but three kept paths were re-pinned inside the new file instead; confirm they belong there.

## Could not check

- Whether each of the three kept tests really passes on the old code: no checkout is allowed, the runner's proof is per file (run.log:6–7), and I reasoned from arena_touch_ready_test.dart:69/:93 and the row's unchanged `HostCardButton` activation.
- `tools/check.sh phone` (the report's 484 tests): I ran `host` only.
- A device: the tap falling through the own row to the scroll view, any press flash, and the Back button's look on a TV.
- `tools/review.sh`'s "0 fail, 4 notes".
- A touch card with an own player at a width below 852 (e.g. the 600 px window): the wrapped Ready line there is untested.

## Commit message

Review: the Arena card's Back button and own-row rule

Reads job arena-waiting (c6d18ce) against the guidelines, the review
rules, its brief, the tests and the runner's log.
One must: three of the seven new tests pass on the old code and repeat
existing pins in arena_touch_ready_test.dart.
One should: the card's comment and decision 2 give the join screen's
button order backwards.
Three could: the TV line's centre moved, `_cardBody` growth, and a
self-check citation naming a test that never looks at `arenaBack`.
Checks: 7 new tests, 28 Arena tests, host suite 489, format, analyze.

## Status row

Review of arena-waiting (B-024, B-025) written: 1 must, 1 should, 3 could — open: the kept-path tests in arena_row_touch_test.dart and the Back comment's join-screen reason.

## Delete

- none
