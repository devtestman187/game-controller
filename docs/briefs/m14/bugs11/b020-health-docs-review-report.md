# b020 health docs: the review

## Summary

- Verdict: small fixes. 0 must, 3 should, 3 could.
- docs/code-health.md:99 still records `game_screen.dart 373/380`; at this job's commit (e50cd4a) and its parent (4440477) the file is **378** lines (`git show e50cd4a:… | wc -l`); 373 is the `f11c4b1` size, and b020-solo-both (4440477) added 5.
- b020-health-docs-report.md:7 repeats it as a checked fact ("`wc -l` … is 373"), so the one self-check claim the job makes is false.
- docs/code-health.md:120's carry list `373 / 381 / 370` carries the same 5-line error (the file gives 378 / 386 / 375 today).
- docs/code-health.md:117 points at `solo_arena_card_test.dart:52`, which is now a bare `findsOneWidget,`; the Surprise-me line is :56 after b020-solo-both rewrote the file.
- The brief's two deletions, the heading, the CRLF/Windows-1252 bytes and section placement are all as asked; `tools/check.sh format` PASS.

## Findings

- **should** docs/code-health.md:99 the bullet says `game_screen.dart` is `373/380 (before bugs11's next change)` while the file is 378 lines at this commit and at its parent, so the tracked headroom is 5 lines short and "before bugs11's next change" names no commit → say `378/380` (or `379/380 (d4b8731)` if the pre-b020 figure is wanted).
- **should** docs/code-health.md:120 the next-map carry list `373 / 381 / 370 (not 379 / 387 / 376)` applies the old −6 to 379, but the file went 379 → 373 → 378, so the same deltas give `378 / 386 / 375` today → carry `378 / 386 / 375`.
- **should** docs/briefs/m14/bugs11/b020-health-docs-report.md:7 the line claims `wc -l` on `packages/party_host/lib/src/ui/game_screen.dart` "is 373", which is false at the commit that report documents (378) → correct the figure and say where 373 came from.
- **could** docs/code-health.md:117 `solo_arena_card_test.dart:52` lands on a bare `findsOneWidget,` inside the race-mode expect; the "opens on Surprise me" assertion is `:56` → change the reference to `:56` and say "the next change to the file" instead of "rewritten by b020-solo-both", which 4440477 already did.
- **could** docs/code-health.md:120 the `Wrap` "at `:68`" names no file and no `Wrap` sits at `arena_results.dart:68` (it is `arena_results.dart:174`, inside `_ResultsBody`) → write `b020-next-map-report.md:68`.
- **could** docs/briefs/m14/bugs11/b020-health-docs-report.md:11 the report has no part-A line (review-rules.md:13, coding-guidelines §11), so "is each claim true" can only be asked of the size claim → add the five one-liners, each "not affected" for a docs-only job.

## Decisions to confirm

- Keeping the file's Windows-1252 and CRLF bytes (report:17): safe; `git diff` shows only the two deletions, the one rewording and the new section, and `file` still reports CRLF, so no unrelated line was rewritten.
- Placing `### M14 bugs11 leftovers` after the B-019 bullet (report:19): it is a sibling of the bugs6 heading, so it reads correctly; no action.
- Quoting "for two" without the apostrophe (report:20): the fix ("for two or more") is intact; safe.
- The "before bugs11's next change" wording on :99: which commit it means is undecided in the brief and in the doc — Claude should pick the wording along with the size finding above.

## Could not check

- `docs/briefs/m14/bugs11/run-findings.md` does not exist, so there is no runner evidence for this job; it has no tests, so the tests-first question does not arise.
- Whether the head/tail/printf rebuild left every byte outside the changed lines identical cannot be proved from git; the diff shows no unintended change, which is the strongest available evidence.
- The report's "7s" for the format check (report:13): I re-ran it and got PASS (4s); the figure is cosmetic.

## Commit message

b020 health docs review: report, verdict small fixes

docs/code-health.md still records game_screen.dart at 373 lines,
but the file is 378 at the job's commit (b020-solo-both added
five), and the next-map carry list is short by the same five.
The solo_arena_card_test.dart:52 reference moved to :56 in that
rewrite. The two deletions, the new heading, the CRLF bytes and
the placement match the brief. Findings and fixes above; format
check re-run, PASS.

## Status row

- M14 bugs11 health docs review: done — verdict small fixes, 3 should (the game_screen sizes on :99 and :120, the report's `wc -l` claim) and 3 could (line :52 → :56, the bare `:68`, no part-A line); open: those fixes, none applied here.

## Delete

- none
