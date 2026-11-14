# pr-shape review — the two proposals, checked against the code

## Summary

**small fixes.** The picks are safe and the arithmetic holds (20% / 36%, 1.0 s and 0.5 s, 120/150/210 s, 12/8 = 1.5), but four claims do not match the code: the repeat odds cover the rematch path only, "no report change" contradicts the body, "Medium's limits" do not stay, and the timing Files point at the wrong line.
- must 0 · should 6 · could 2
- `avoidPuzzleId` is passed only by `_rematch` (`puzzle_screen.dart:277`); `join_screen.dart:293` starts the next round with none, so after "Change teams" the puzzle just played can come back at 1 in 6 (`pr-shape-report.md:53`).
- The Summary says the timings need "no report change" while the body adds report columns and a row group, and nothing in `packages/metrics` reads `gameStats` keys (`pr-shape-report.md:18`, `:90-92`).
- "What does not change: Easy's and Medium's limits" sits one line below Medium's clock going to 150 s (`pr-shape-report.md:119`).

## Findings

- **should** docs/briefs/m14/bugs3/pr-shape-report.md:53 says the pick "excludes only the puzzle just played" with a repeat by the third round of 20% and by the fourth of 36%, but the guard is passed only by `_rematch` (`party_host/lib/src/ui/puzzle_screen.dart:277`) while the round after "Change teams" is built with no `avoidPuzzleId` (`join_screen.dart:293`), so that next round repeats at 1/6 and three rounds after one hold a repeat 1 − (5/6)³ = 42% → say the guard covers rematches only, give the join-path odds, and fix the Decision at :40 that leans on the guard.
- **should** docs/briefs/m14/bugs3/pr-shape-report.md:18 says both timings "reach the report through `gameStats` with no report change", but :90-92 adds "moving" and "placing" columns and a derived share to "the per-player report table", and no code reads `gameStats` keys today (only `session_player.dart:111-115` writes them) → say the summary JSON gets them for free and name the table and report work, or drop the table claim.
- **should** docs/briefs/m14/bugs3/pr-shape-report.md:119 heads its list "What does not change: Easy's and Medium's limits and every existing puzzle file", while item 3 at :115-117 raises Medium's clock from 120 s to 150 s → reword to "Medium's pieces, turn rules and files stay; only its default clock changes".
- **should** docs/briefs/m14/bugs3/pr-shape-report.md:96 names "the carry step (`puzzle_carry.dart:103`)", but line 103 is `p.rotatingS += dt` inside `_turn` (`puzzle_carry.dart:90-109`); the per-step walk and carry that would add `moveS`/`placeS` are `puzzle_tick.dart:26-35` → cite `puzzle_tick.dart:26-35` and add that file to Files.
- **should** docs/briefs/m14/bugs3/pr-shape-report.md:88 claims "the two sum to the round's clock for that player", which fails for a player dropped mid-round (the dot leaves the field and its steps stop while the side's clock runs, as `docs/briefs/m12/bug-1107d-triage-report.md:26` describes) → state that an away or dropped player's pair stops at the drop and no longer matches the round.
- **should** docs/briefs/m14/bugs3/pr-shape-report.md:158 (self-check onward) has no line giving the result of the brief's `check: format`, where the a1 and pr-arena reviews both asked for one → add a checks line with pass or fail.
- **could** docs/briefs/m14/bugs3/pr-shape-report.md:10 lets each Summary item run four or five lines where the brief asks "at most 30 lines: one line per item (the pick and the risk)" → one line each, keeping the conflicts and computed-values lines after them.
- **could** docs/briefs/m14/bugs3/pr-shape-report.md:161 answers part A1 for a TV host, a phone host on both settings and a joined phone, but not the "phone or host one build older" that `docs/review-rules.md:16` names → add "not affected: no new field on the wire" for it.

## Decisions to confirm

- Medium keeps its 6–8 pieces, 1–2 big and its start angles; only the clock moves to 150 s (`pr-shape-report.md:44-46`, :115-117). If the owner's "Medium should be easy" means today's Medium becomes the easy set, the Hard rules and content jobs change shape.
- Hard's blanket rule — every non-circle turned, half starting 90° off (`pr-shape-report.md:110-114`) — sits against PRD M15's "remaining puzzles … with tuned starting angles" (`docs/PRD-v2.md:787`); confirm the rule, not tuning, decides Hard.
- The `level_easy|medium|hard` round tag and its report row (`pr-shape-report.md:92-95`) go beyond the brief's "what to measure, where in the stats"; confirm it belongs in the metrics job.
- `moveS` counting walking with empty hands is still the owner's call (`pr-shape-report.md:155-156`, Question 4); the split is the whole point of B-012a.

## Could not check

- The change itself: `git diff f862d68..af81053` and `git show --name-only` both needed approval, so the brief's fallback (read the report whole) was used; whether the commit touched only the report is unverified.
- Whether the `format` check ran and passed: the report names no result.
- Whether 10–12 pieces with 3–4 big fit on the board at every tray start: it needs `check` run on a hard file that does not exist yet; the report's own risk names the 8.5 mm floor and the tray rules, which is the right pair.

## Commit message

Review pr-shape: proposals hold, three lines in the report do not

Report only, no code: the review is of the report's claims against the code.
The odds and values check out (20%/36% on rematches, 1.0 s / 0.5 s, 120/150/210 s,
12/8 = 1.5, six puzzles a level and six Medium files). Corrections: the
just-played guard is passed only on rematch, so the repeat odds understate the
join path; "no report change" contradicts the report's own columns and row
group; "Medium's limits" do not stay with its clock at 150 s; the timing Files
cite the rotation line in `puzzle_carry.dart` instead of `puzzle_tick.dart`.
The format-check result is missing. Details in
docs/briefs/m14/bugs3/pr-shape-review-report.md.

## Status row

pr-shape reviewed: B-009 and B-012a/b/c stand with four claim fixes and the format-check result added (0 must, 6 should, 2 could); open: the owner's OK on Medium and Hard, Claude's call on the level tag, then the metrics, Hard-rules and Hard-content jobs.

## Delete

- none
