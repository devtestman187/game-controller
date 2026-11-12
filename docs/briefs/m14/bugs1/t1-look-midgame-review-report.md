# Review of t1-look-midgame (read-only)

## Summary

`small fixes` — 0 must, 2 should, 3 could.
- The code does what the brief asks: the hold is gone, both painters compare `look`, and all suites pass (party_host 389, controller_app 464); I found no code bug.
- The report says `round_palette_hold.dart` was "emptied" and lists it under Delete, but commit `ebd8ed7` deletes it (63 lines gone), so the Delete step targets a missing path.
- The report's doc follow-up names D1 but not `docs/design/look-mockups.html:189`, which repeats the old mid-round rule; fixing D1 alone leaves that stale.
- The Bumper Round test never checks the round's clock or scores, though the brief and the report claim coins and points stay untouched.

## Findings

- **should** docs/briefs/m14/bugs1/t1-look-midgame-report.md:54 the report says `round_palette_hold.dart` was emptied to a single newline and tells the reader to delete it (also lines 19 and 149), but `git show ebd8ed7` shows the file deleted, so the Delete step points at a path that does not exist and the file list is untrue → say the commit deletes it and remove the Delete entry (or leave it only if a delete is still pending).
- **should** docs/design/look-mockups.html:189 the mock-up still reads "The palette only changes between screens, never mid-round", and report:117 names only D1 and "the mock-ups' section 8" without file or line → name `docs/design/look-mockups.html:189` in the follow-up so the doc fix covers both places.
- **could** packages/party_host/test/look_midgame_test.dart:84 the Bumper Round test checks only `round`, `mode` and `players.length` after the look change, so the brief's "no lost … time, coins or points" and report:44's claim are unproven for the Arena → assert the round's clock (and a coin or point figure) are the same before and after.
- **could** packages/party_host/test/look_midgame_test.dart:35 the Shape Race test asserts the painter's `look.palette`, not a colour drawn, while the brief asks for "the new look's colours on the next frame" → assert a pixel or a drawn colour through the palette the painter is actually handed.
- **could** controller_app/test/round_palette_test.dart:24 the rewritten joined-phone test drops the old case that ended the view and opened a page, so nothing now checks the palette after a joined game ends → keep that final step in the same test.

## Decisions to confirm

- Removing `RoundHolds` outright, rather than keeping a hold for some screen: it matches the brief and the owner's report, and no screen is left stale, but it also lets Auto's hour reach a round on any page push or pop (report question 2) — the owner should say whether that is wanted.
- Deleting the exported widget `RoundPaletteHold` (and its `party_host.dart` export) instead of keeping an unused class: fine inside this repo, but it is a public-surface removal the report lists as "emptied".
- Rewriting the two tests that asserted the old freeze (`look_palette_test.dart`, `round_palette_test.dart`) to assert the opposite: legitimate under the brief, but it means D1 and the mock-ups are now the only places that still say the old rule.

## Could not check

- That the new test file fails on the code as it was (no checkout allowed, read-only job); from the diff it would: `build()` returned the stored palette while a round screen held it.
- Behaviour on a real TV, phone host and joined phone (no device run here), including the owner's own reproduction.
- The `tv` part of the original check list (tv_test_app tests were not run).

## Commit message

```
Review: t1 look mid-game, findings only

Read-only review of ebd8ed7 against the coding guidelines, review rules
and the brief. The code matches the brief and every suite passes; the
findings are in the report: it misstates the deleted
round_palette_hold.dart, the doc follow-up misses the mid-round line in
look-mockups.html, and the Bumper Round test does not show the round's
clock or scores untouched.
```

## Status row

`t1 look mid-game: reviewed (small fixes) — code clean, suites pass (party_host 389, controller_app 464); open: report must say round_palette_hold.dart is deleted (not emptied), the doc follow-up must name docs/design/look-mockups.html:189 and D1, and the Bumper Round test should assert the clock and scores are untouched.`

## Delete

- none
