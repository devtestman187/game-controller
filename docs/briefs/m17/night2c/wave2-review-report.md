# night2c wave 2 review (v2, t2, d1)

## Summary

Verdict: needs Claude (one must, three should; the must is an open conflict with the owner's "saved settings keep their value").
Counts: must 1, should 3, could 4.
1. must: `isKids` is `this == kids`, and Kids now has the director picker, so a Kids night saved by an older build (picker host) no longer counts as Kids (the Kids button and the puzzle's Chaos cap change).
2. should: the "no picker key" case in `night_settings_test.dart` passes whether or not the rest of the save survives.
3. should: the new app-default test runs on the menu look only, and `pumpHostLook` cannot pass `hostPicks` (the brief asked for every look).

## Findings

- **must** packages/party_host/lib/src/night/night_settings.dart:81 `isKids` is `this == kids`; Kids now has `picker: director`, so a Kids night saved by an older build (picker `host`) loads as not Kids, which unselects the setup Kids button (night_setup_screen.dart:56) and drops the puzzle Chaos cap (puzzle_screen.dart:258), against "saved settings from older builds keep their saved value" → compare every field except `picker` in `isKids` (or the owner decides otherwise), and add a test for a saved Kids night with `picker: host`.
- **should** packages/party_host/test/night_settings_test.dart:136 the no-picker-key case asserts only `picker == director`, which holds even when `tryFromJson` drops the whole save (night_settings.dart:131-135 return null when `picker` is missing); the test cannot tell the two apart → also save a non-default `length` in that JSON and assert what happens to it, so the drop is pinned, not hidden.
- **should** packages/party_host/test/night_setup_screen_test.dart:300 the app-default test uses `pumpHost` and so checks the menu look only, though the start card is a look-sized screen (review A.6); `pumpHostLook` (test/support/all_looks.dart:32, outside the allow list) does not forward `hostPicks` → run it through `forEachLook` and forward `hostPicks` in all_looks.dart, or record the gap as an open item.
- **should** tools/mine.sh:162 `--untracked-files=all` lists every file, but a new untracked non-.dart file (for example a `.md`) still prints a green `RESULT: ok: 0 file(s) formatted` while an untracked file exists, which is the literal t2 rule ("never print a green 0 files when untracked files exist") → owner decides: literal (print a note or fail for any untracked non-.dart file) or the .dart reading the worker used.
- **could** packages/party_host/lib/src/text/night_setup_text.dart:84 the host help text was changed to "You choose each game yourself, every time.", which the brief did not ask for ("update only what reads wrong") → revert to "You choose each game yourself." unless the owner wants it.
- **could** tools/mine.sh:1-16 the header's list of outputs does not mention the new `FAILED untracked folder <path>` line or its exit 1 → add one line to the header.
- **could** docs/driver-kit.md:43 the bullet ends "This replaces the old 'no protocolVersion bump' rule", but no such rule is in driver-kit.md or any other docs/*.md (grep finds only briefs) → name where the old rule lived, or drop the sentence.
- **could** docs/briefs/m17/night2c/v2-report.md:1 and docs/briefs/m17/night2c/d1-report.md:1 have no `## Summary` block in their first 40 lines (run.log:110 and :113 flag the same) → add one (report format only).

## Decisions to confirm

- packages/party_host/test/support/host_harness.dart:79 `pumpHost` gets a new `hostPicks = true` parameter, not the brief's "override before the caller's" order; the default keeps about 21 tests on host picks, so the director default is exercised only by the new tests. Listed in the v2 report (question 1), but the default's effect on the other tests is not stated. Why: it changes what the default harness tests.
- night_settings.dart:81 `isKids` (see the must): the worker left it for the owner. Why: it decides whether an older saved Kids night is still Kids.
- Kids now sets the director picker on tap (`useKids`, the Kids preset at night_settings.dart:46-54). The brief asked for it, but it changes what a Kids tap does for a host who had picked host. Why: owner-visible.
- tools/mine.sh:162 non-.dart untracked files (see the should). Why: the brief's literal wording and the worker's reading differ.
- The Kids test seed `_kidsShapeRaceSeed = 1` (night_round_test.dart:17-18) was "found by running" (v2 report). Why: a derived value, not a rule.

## Could not check

- Test results: I did not run flutter, dart or mine.sh (no installs, no scratch files). The v2 count "124 tests" and t2 "17 of 17" are the workers' claims; run.log shows only that the resumed combined check passed (11:27-11:36). The cause of the first combined-check failure (run.log:85) is not in the log.
- Whether the two `setMockInitialValues`/`getInstance` pairs in night_settings_test.dart:127-135 really give fresh prefs for the second half (a cached instance would make the second assert read `host`). Needs a test run.
- The d1 claim "the 1h cache has been on since Nov 23" and the City Rush pointer (E:/AI/m17-scoping/city-rush-plan.md) were not opened.
- The night_round_test kids path (tap of `nightStartPick`, then 500 ms) was checked by reading only.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

docs: review report for night2c wave 2 (v2, t2, d1)

Adds the review of the three wave 2 commits (5a2e4e05, c5b5834d,
880b275e) against the coding guidelines, the review rules and their
briefs. No code changed. Findings: one must (Kids saved by an older
build loses isKids), three should (the no-key settings test, the
app-default test on one look, the untracked non-.dart green line),
and four could.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2c wave 2 review: done, verdict needs Claude (1 must: isKids for older saved Kids nights; 3 should: no-key test, app-default test on one look, untracked non-.dart green line); open: Claude's decision on those and on the hostPicks default.

## Delete

- none
