# d2d report: NightDirector picks the next variant and says why

## Summary

Added the pure-Dart `NightDirector` with `DirectorPick` and `DirectorReason`. No provider, no UI, no hook (`nightNextVariantProvider` stays null until B8), no caption text, no change to `Variant` or `NightSettings`. Tests: 13 in the new file, all passing under `tools/mine.sh`.

## Files changed

- `packages/party_host/lib/src/night/night_director.dart` (new): `enum DirectorReason`, `final class DirectorPick` (with `==`, `hashCode`, `toString`), and `final class NightDirector` with const named params `lopsidedShare = 0.5` and `closeShare = 0.2`, and `pick(...)` following rules (a) to (g) in the brief's order.
- `packages/party_host/test/night_director_test.dart` (new): one test per rule, plus the min/max, preference and determinism cases.
- `docs/briefs/m17/night2a/d2d-report.md` (new): this report.

## How the rules were built

- (a) Candidates are the pool variants with `tier.index` in `min..max`. None gives `null`.
- (b) `played.last` is dropped unless that leaves no candidate.
- (c) No rounds played: target is `min`, reason `opening`, and the (d) kind filter is skipped because the table is not lopsided.
- Otherwise the mood comes from `totals`. Leader is the max, lead is leader minus the min. Leader ≤ 0 or empty totals give steady. Lead ≥ leader × 0.5 gives lopsided, so the target is one tier easier and not below `min`. Lead ≤ leader × 0.2 gives close, so the target is one tier harder and not above `max`. Otherwise the target is the last played tier.
- (d) Lopsided keeps only `isKind` candidates when any exist.
- (e) The target tier is taken from the candidates. If none sits there, the nearest tier wins, and a tie goes to the easier.
- (f) Variants not in `played` are preferred; if all were played, any is allowed.
- (g) `random.nextInt` chooses.
- Reason: opening for the first round; kindForLastPlace when lopsided and the pick is kind; easedAfterLopsided when lopsided otherwise; raisedAtCloseTable when close and the pick is above the last tier; else steady.

## Computed values used in the test expectations

- Lopsided `[10, 2]`: leader 10, lead 8, threshold 10 × 0.5 = 5, 8 ≥ 5, so lopsided.
- Close `[10, 9]`: leader 10, lead 1, threshold 10 × 0.2 = 2, 1 ≤ 2, so close.
- Steady `[10, 6]`: leader 10, lead 4, lopsided threshold 5 (not met), close threshold 2 (not met), so steady.
- All-zero `[0, 0]` and empty `[]`: steady by the leader ≤ 0 / empty rule.
- Kids (min = max = easy): the candidate list is only the easy variants, so every pick is easy across all four totals scenarios and both last-played tiers (easy and hard), seeds 1 to 5.
- Seeds 1 to 20 were used for the "never twice", "kind only", "eased", "raised", "steady" and "preferred" loops.

## Check results

- `tools/mine.sh`: `OK 13 tests packages/party_host` and `RESULT: ok: 2 file(s) formatted, 1 package(s) analyzed, 1 package(s) tested`. The analyzer reported no findings for `packages/party_host`.
- Tests-first: exempt (a new type; the test cannot compile on the base).
- Churn and `tools/check.sh` were not run by me; the script runs `format analyze` afterwards.

## Questions

1. The brief's `pick` takes six parameters (`pool`, `played`, `totals`, `min`, `max`, `random`), but the coding rules cap a function at five and say to use a value object beyond that. I kept the brief's signature. A value object such as `DirectorInput` would fix it; say if you want that instead.
2. A single-player table has lead 0 with leader > 0, so it counts as close and the next round is raised a tier. This follows the rules as written. Say if a solo night should stay steady.
3. "Kind" is `tier == easy` through `Variant.isKind`, because no co-op or catch-up variant exists yet. The kind filter will therefore always pick easy variants.

## Suggestions

- The night bots should tune `lopsidedShare` and `closeShare`; the defaults are first guesses.
- Once B8 hooks the director in, the caption can map `DirectorReason` to text.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

party_host: NightDirector picks the next variant and says why

Adds the pure-Dart NightDirector (d2d). It returns a DirectorPick with a
DirectorReason code, so the night can explain each pick. The rules follow
M17 plan 1.2: never the same variant twice in a row, ease one tier after a
lopsided round, raise one tier at a close table, give the last-place player
a kind variant first, and stay inside the host's min and max.
No provider, no UI and no hook yet; nightNextVariantProvider stays null
until B8. The lopsided and close shares (0.5 and 0.2) are first guesses.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- d2d done: NightDirector, DirectorPick and DirectorReason are pure Dart with 13 passing tests; open: the six-parameter pick signature vs the five-parameter rule, the solo-table rule, and tuning the shares (night bots); the director is not yet hooked in (B8).

## Delete

- none
