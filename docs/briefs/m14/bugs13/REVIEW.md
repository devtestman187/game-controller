## Summary

**one fix batch** — the run has one job (arena-waiting, c6d18ce) and no later job touched it, so every per-job
finding still holds in the final code (none was fixed afterwards). Hand-fixes: **none** — `run.log` has no
`HAND-FIX` line, and the job has both its tests-first proof (`run.log:6-7`, per file) and its worker review
(`run.log:9`).

must 0 · should 3 · could 3 · open questions 8. The per-job review's one `must` (three of the new tests pass on the
old code) is carried as a **should**: the runner proves a *file*, not a test (`tools/run-jobs.sh:179-192`), and the
brief's own item 1 asks for exactly those kept paths inside `arena_row_touch_test.dart`, so the two sentences of
the brief conflict; the cost is a doubled pin, not a broken rule.

The five that matter most:
- `arena_row_touch_test.dart:73, :84, :94` repeat pins that already exist in three other files; one rule, four files.
- `arena_waiting_card.dart:273-274` and the report's decision 2 give the join screen's button order backwards.
- the TV card's ready line moved 62 px right, while `arena_waiting_widgets.dart:110` and `arena-waiting-report.md:31`
  still say it "stays centred" / "reads as before".
- `arena_row_touch_test.dart:15` measures its above-the-fold guard without the look's real fonts.
- `arena-waiting-report.md:118` cites a test that never looks at `arenaBack`.

Fixed by this job with no device proof (the batch must mark them **Fixed, unverified: needs device check**): the
own row's tap falling through to the card's scroll view, and "shows no press feedback"
(`arena-waiting-report.md:132-137`).

Nothing in the change would be pinned by controller_app (phone) tests: the two test findings are
`packages/party_host/test` files, so the fix job carries `check: format analyze host`.

## Findings

- **should** packages/party_host/test/arena_row_touch_test.dart:73, :84, :94 three of the seven new tests (the Ready button, a joined phone's A, the remote's OK/Enter on the focused row) pass on the old code and repeat pins that exist at `arena_touch_ready_test.dart:68-93`, `arena_phone_card_test.dart:59` and `arena_waiting_test.dart:104`, so one rule now lives in four files → move the three kept cases back to those files (or write in the brief that kept-path tests in a new file are exempt), leaving the new file with only the own-row rule (from: arena-waiting review).
- **should** packages/party_host/lib/src/ui/arena_waiting_card.dart:273-274 the comment says Back stands first "as the join screen's does before its Start", but the join screen puts Start before Back (`join_screen_widgets.dart:271-288`), and `arena-waiting-report.md:100-101` repeats the same reversed reason → give the comment and decision 2 the true reason (Back left of Ready keeps the Ready button where a thumb expects it) (from: arena-waiting review).
- **should** packages/party_host/lib/src/ui/arena_waiting_widgets.dart:110 the doc says the line "stays centred" and `arena-waiting-report.md:31` says the TV card "reads as before", but `_ReadyRow`'s `Center` now centres inside the `Expanded` right of Back (`arena_waiting_card.dart:287-293`), so the TV card's ready line moves (112 px + 12 px) / 2 = 62 px right on every TV card → say so in the doc, and pin the line's x on a TV card if the place matters (from: arena-waiting review).
- **could** packages/party_host/test/arena_row_touch_test.dart:15 the file never calls `loadLookFonts` (`arena_back_test.dart:17` does), so its "the row is above the fold" guard at :49-50 is measured with the test font, not the look's → add `setUpAll(loadLookFonts)`, as the report's own question 2 asks (from: across jobs / this run's report).
- **could** packages/party_host/lib/src/ui/arena_waiting_card.dart:262 `_cardBody` is 56 lines against the guidelines' about 40 per function, and these two card files have now grown for B-013, B-024 and B-025 with no split planned → record the card split (ready row, roster, maps) in `docs/code-health.md` as *before a milestone*, so the next card job carries it (from: arena-waiting review / across jobs).
- **could** docs/briefs/m14/bugs13/arena-waiting-report.md:118 the self-check says a "Show on this device" phone shows Back, citing `arena_touch_ready_test.dart` "a phone that only shows the game has no Ready button", but that test (:144-156) never looks at `arenaBack` (`arenaBack` appears only in `arena_back_test.dart`) → cite `arena_back_test.dart:40-52`, which renders the same no-own-player card and asserts the key (from: arena-waiting review).

## Open questions

- Back on every host, including the TV card (report decision 3, `arena_waiting_card.dart:280-285`): keep as it is — the brief asks for a TV card's Back and guideline §6 wants one card for both hosts.
- Back left of Ready (decisions 1-2): keep the place, fix only the comment (finding 2).
- The own row dead to a thumb, so the Ready button is the only touch path to ready/unready (decision 4): keep — the owner chose option A explicitly.
- The own row stays focusable on a touch-first host, where no pad exists (report question 1): keep focusable — no test and no owner statement asks for the row to leave the focus order, and removing it would make the row's activation shortcuts dead code.
- Three kept paths re-pinned inside the new file (report decision 7, review decision 4): accept as is for now — the file failed on the old code as a whole, so the tests-first rule holds; finding 1 is the cheaper follow-up.
- The look's real fonts in later card tests (report question 2): yes — done in the same batch through finding 4.
- `_tick` is 43 lines (report question 3, pre-existing review note): defer with finding 5 to the card-split debt entry, not a job of its own.
- The Back button's look on a TV (frame 8) is a design change no test sees: the owner should look at it on a TV before the next card job.

## Numbers against targets

- `packages/party_host` suite: 489 tests, all pass (I ran `flutter test` there); the two new files: 7/7 pass. The report's 484 `phone` tests and `tools/review.sh`'s "0 fail, 4 notes" I did not re-run.
- `arena_waiting_card.dart` 365 lines and `arena_waiting_widgets.dart` 353 lines: inside the brief's 380 cap and the guidelines' 400 hard limit, over the ~300 aim.
- `_cardBody` 56 lines against the guidelines' about 40 per function (inside the 60-line `build` budget); `_tick` 43 lines, pre-existing.
- The ready line's 62 px shift on a TV card is against the report's "reads as before"; no brief states the line's target x.
- The report's "4 of the 7 new tests failed on the old code" is a per-test claim; the runner's proof is per file (`run.log:6-7`), so it cannot be checked from here.

## Could not check

- `tools/review.sh` and `tools/check.sh host phone` needed approval in this session, so I ran the two new test files and the whole `packages/party_host` suite with `flutter test` instead; `format`, `analyze` and the `phone` suite were not run by me.
- Whether each of the three kept tests really passes on the old code: no checkout is allowed and the proof is per file.
- A device: the tap falling through the own row to the card's scroll view, whether anything flashes on a press, and the Back button's look on a TV.
- A touch card with an own player at a width below 852 (the 600 px window): the wrapped Ready line beside Back is untested.

## Commit message

Fix: the Arena card's Back comment and its doubled test pins

Corrects the card's comment and the report's decision 2, which give the
join screen's button order backwards (Start, then Back).
Records the TV ready line's 62 px shift beside Back, notes the card's
size as debt, and fixes the row-touch test's font setup.
Moves the three kept Ready/A/OK paths back to the files that already
pin them, so one rule lives in one place.
Checks: 7 new tests, host suite 489.

## Status row

Run review of bugs13 (one job, arena-waiting c6d18ce) written: 0 must, 3 should, 3 could, 8 questions — open: the doubled test pins, the card's Back reason and the TV line's shift.

## Delete

- none

## Claude's verdicts (Nov 15, 2026)

1. Doubled pins (arena_row_touch_test.dart:73/84/94): real, minor (a doubled pin, no broken rule) -> docs/code-health.md.
2. Comment and decision 2 give the join screen's order backwards: real (join_screen_widgets.dart:271-288 puts Start first) -> fixed by hand.
3. TV ready line shifted 62 px, doc says "stays centred": real -> doc and report corrected by hand; no x-pin (no owner statement on the place).
4. No loadLookFonts in arena_row_touch_test.dart: real -> fixed by hand (setUpAll added, 7/7 pass).
5. `_cardBody` 56 lines: real, minor -> code-health.md (card split).
6. Report line 118 cites a test that never looks at arenaBack: real -> citation corrected (arena_back_test.dart:40-52).
Open questions: kept as the review proposes; the Back look on a TV is for the owner's eyes. No code-sized finding: the fix brief f1 carries only the owner's consent decision.
Not touched: the review's "could not check" items (device only).

## Claude's verdicts on the f1 review (Nov 15, 2026)

1. must, two new tests pass on the old code: real but not a defect; the report states them as guards (Decisions 4, "guards the default path"); the brief asked for both behaviours. Kept in the new file.
2. should, real-socket join without the §9 exception written down: real, trivial -> comment added to the test's setUp (fixed by hand).
3. should, `ThumbOnly` exported for one caller: real -> moved private into stats_screen.dart as `_ThumbOnly` (fixed by hand; analyze, review.sh, stats/menus/consent tests pass).
4. could, report says joinPhone "lives" in host_app.dart: real -> report reworded; the two older copies stay (already in code-health.md).
5. could, self-check claims Settings/TV prompts tested: real -> reworded to "not affected, touchOnly defaults to false".
Decisions to confirm: empty `Controls.only` meaning nobody stays (no Controls.none yet); remote back stays a guard; held-A latch is a device check. No code-sized finding.
