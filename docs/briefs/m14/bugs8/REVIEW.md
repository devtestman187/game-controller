# M14 bugs8 run review

## Summary

Verdict: **one fix batch**. 0 must, 4 should, 9 could.

The run's four things (three redone Hard pictures, the one-off Medium best-times clear, the tray
edge fix plus its test, the pins and sheets) are sound and tested; the four checks I ran pass, and
the three JSONs match the bugs7 candidates except `notes`.

The five that matter most:
1. The clear covers the six Medium boards only, so the Hard dragon, tower and tractor this run
   redraws keep best times measured on pictures that no longer exist (`best_times.dart:21`).
2. A host whose saved `bestTimes` does not decode never gets the marker, so the first Medium time
   it records afterwards is removed on the next start (`best_times.dart:156`).
3. The `_fitSlack` fix in `tray.dart` landed inside b012c-1's commit although that job's report
   calls it Blocked and says it did not edit `lib/`, and the commit message calls it open; no
   report in the run describes the change.
4. Six puzzle ids sit as literals in `party_host` (guideline §2, review-rules C-table).
5. `docs/code-health.md:107` and `docs/briefs/m14/STATUS.md:7` are now stale.

Only the owner can answer: should the three redone Hard best times be cleared too, and does the
owner do the device look at the three new sheets and a real-host check of the clear?

Checks I ran: `flutter test test/split_layout_test.dart test/tray_edge_fit_test.dart
test/tray_packing_test.dart test/hard_swap_test.dart` in `packages/puzzle_game` — all passed (the
tower seed 15/18 wrap b012c-1 left open is fixed); `diff -I '"notes"'` of each shipped puzzle
against its bugs7 candidate — identical. The host suite is unchanged since the b012c-2 review
verified it at 453 green.

## Findings

- **should** packages/party_host/lib/src/best_times.dart:156 the decode throw leaves `_clearRedoneBoards` before `setInt(_versionKey)` at :162, so a host with unreadable saved times never gets the marker and the first Medium time it records afterwards is cleared on the next start, which the doc comment at :144 ("does no harm") denies → write the marker before decoding (or in `build`'s catch) and add the test "unreadable times, record a Medium time, rebuild, the time stays" (from: b012c-2 review)
- **should** packages/party_host/lib/src/best_times.dart:21 `redoneMediumPuzzleIds` clears only the Medium boards, but b012c-1 replaces the Hard dragon, tower and tractor in the same run, so those kept Hard times now measure pictures that no longer exist — the exact problem the clear was written for → bump `bestTimesVersion` to 2 and clear those three Hard boards too (rename the const, update the library-equality test at best_times_medium_clear_test.dart:102), or record the owner's decision to leave them (from: across jobs)
- **should** packages/puzzle_game/lib/src/tray.dart:14 the `_fitSlack` fix and `test/tray_edge_fit_test.dart` are in commit 11a9619, but b012c-1's report lists the tower tray as Blocked, says "I did not edit `lib/`", and the commit message says the bug is open — no report in the run describes the change, so Claude cannot tell whose it is → say who made it, put it in the commit message and the milestone status, and have Claude read these 9 lines (from: across jobs)
- **should** packages/party_host/lib/src/best_times.dart:21 six puzzle ids as literals in `party_host` break guideline §2 (hard-coded identity) and the review C-table row "puzzle types or names inside `party_host`", and the b012c-2 review raised it and it was not answered → read the redone boards from the puzzle data (party_host already depends on `puzzle_game`, providers.dart:375) or add a "redrawn at version" field to each puzzle JSON; otherwise write the exception into the brief and the guidelines (from: b012c-2 review)
- **could** docs/code-health.md:107 still says the old Medium times "stay beside the redone boards" and are an open owner decision, which b012c-2 closed → rewrite it as "cleared once by `bestTimesVersion` 1" or delete the entry (from: across jobs)
- **could** docs/briefs/m14/STATUS.md:7 says the dragon, tower and tractor Hard redo proposals "await the owner, shipped library unchanged" and (line 9) asks "clear old Medium best times?" — both are false after this run → replace the bugs7 paragraph with the Status row below (from: across jobs)
- **could** packages/party_host/lib/src/best_times.dart:17 `bestTimesVersion` and `redoneMediumPuzzleIds` are public only so `best_times_medium_clear_test.dart` can read them, widening the package's surface for two test values (guideline §3) → make both private and pin the literal 1 and the six ids in the test (from: b012c-2 review)
- **could** packages/party_host/test/best_times_medium_clear_test.dart:66 `jsonDecode(prefs.getString('bestTimes')!) as Map<String, Object?>` casts decoded data without validation (guideline §2 type escapes) → `expect(jsonDecode(...), isA<Map<String, Object?>>())` and read the keys through the checked local (from: b012c-2 review)
- **could** packages/puzzle_game/test/tray_edge_fit_test.dart:12 the new edge-fit test loops `seed < 40` where every other layout test uses 20 and checks only the tower, although `_fitSlack` changes the wrap for every puzzle (review-rules B9) → use 20 or say why 40, and run the one-row assertion over the library (from: across jobs)
- **could** packages/puzzle_game/test/hard_swap_test.dart:61 pins the Hard order `[dragon, windmill, lighthouse, dinosaur, tractor, tower]` that `hard_library_test.dart:20` and `library_test.dart:31-36` already pin, so an index change needs three edits → keep the order pin in one test and let this one check piece ids only (from: b012c-1 report)
- **could** packages/puzzle_game/test/split_layout_test.dart:235 "Every Hard puzzle but the lighthouse overlaps on every seed (b013)" is now false for the tower, two lines before the sentence added in b012c says so → "every Hard puzzle but the lighthouse and the tower" (from: b012c-1 report)
- **could** docs/decisions.md:97 the table has no row for the `bestTimesVersion` prefs marker, a saved-format change with its reason (guideline §10; review-rules "targeted look before the first tag"), raised by the b012c-2 review and left open → add one row with the reason and the rule for a later redo (from: b012c-2 review)
- **could** docs/code-health.md:106 and packages/party_host/lib/src/best_times.dart:145 the three redone Hard trays and the one-off Medium clear are unmeasured on a device → mark them "Fixed, unverified: needs device check" and keep the device-look recommendation (from: b012c-1 and b012c-2 reports)

## Open questions

1. Clear the Hard dragon, tower and tractor best times as well? Suggested: yes, in the same batch — the pictures ship together, so the times are as meaningless as the Medium ones.
2. A later redo: extend `redoneMediumPuzzleIds` or replace it? Suggested: extend it, bump the version, and state that rule in the const's doc comment (`best_times.dart:18`).
3. Is the literal Medium id list an accepted exception to §2? Suggested: no — read it from the puzzle library, which `party_host` already imports.
4. Should the marker be written when the saved times don't decode? Suggested: yes; the b012c-2 report's "does no harm" is wrong.
5. b012c-1's Q1: is a follow-up needed for `_packedTray`'s slack? Suggested: no — the tolerance went into `packTray` instead and the 20-seed split test is green; nothing left to re-verify but the device tray.
6. b012c-1's Q2: should `docs/levels.md` note that a tray row (127 units) may be wider than the board? Suggested: one line the next time `levels.md` is touched; not worth a job now.
7. Do the `bestTimesVersion` marker and the redo rule go into `docs/decisions.md`? Suggested: yes, one row.
8. Who does the device checks (three new Hard sheets on the smallest phone, a real host's clear)? Suggested: the owner, with the list in `docs/code-health.md:106`.
9. Should `lib/src/split_layout.dart` (389 lines) be split? Suggested: with its next change; it is under the 400 hard limit but over the 380 the briefs allow.

## Numbers against targets

- Test result target (b012c-1 left one failing): the four affected puzzle test files now pass; the tower seed 15/18 one-row wrap is fixed.
- Tray edge tolerance: measured overflow 1.4e-14 units (`b012c-1` report) vs `_fitSlack` 1e-9 — about 7×10^4× the error, and the same 1e-9 the packing test already uses for its box checks.
- Visible-share floor 0.50 against the stated minimum 0.518: passes with 0.018 to spare (the 0.518 value itself was not re-measured, see below).
- Tower phone tray 127.24 units wide in a world of 131.24 × 102.00: matches the suite's printed `tower: world 131.24 x 102.00`, aspect 1.287 under the 1.3 overlap threshold, so `overlaps['tower'] = [0.0]` is right.
- Design sheets: git shows dragon.png 81724, tower.png 46891, tractor.png 54738 bytes — the three numbers in the b012c-1 report.
- File sizes against the briefs' 380-line lib limit and guideline §3 (300, hard 400; tests 500): `best_times.dart` 195, `tray.dart` 174, `split_layout.dart` 389 (untouched by this run, over 380), `split_layout_test.dart` 454.
- Device checks: none of the three run targets (three Hard trays, the Medium clear) has a device measurement.

## Could not check

- That 0.518 is still the lowest visible share after the `_fitSlack` change: it needs a probe of the minimum, and I may not leave a scratch test behind; the floor test passes, so the true minimum is at least 0.50.
- Who wrote the `tray.dart` change: it has no report and no commit of its own, so only Claude or the runner knows.
- That the new tests fail on the old code (the runner's evidence, not mine): I cannot revert files to reproduce it.
- Device behaviour of the clear and of the three trays.
- The full puzzle suite: I ran only the four files the run touches, because a whole-suite run rewrites `docs/design` sheets I may not change.

## Commit message

Review b012c-1 and b012c-2 as one change

The swap and the Medium clear are right and the tests pass, but the
clear misses the three Hard boards this run redraws, so their best times
still measure pictures that no longer exist. A host whose saved times do
not decode never gets the version marker, so it loses the first Medium
time it records on the next start. The tray edge fix in tray.dart sits in
b012c-1's commit while that job's report calls it blocked and unedited;
its author needs recording. Six puzzle ids stay as literals in
party_host, and code-health and STATUS still describe the old state.

## Status row

B-012 puzzles: three Hard pictures swapped, six Medium best-time boards cleared once, tray edge fix in, tests green — open: the three redone Hard best times, the marker on unreadable data, the literal id list, stale code-health/STATUS lines, and device checks.

## Delete

- none
