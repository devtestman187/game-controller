## Summary

needs Claude: one brief item was not applied, and the docs still disagree on the file-size limit.
Counts: must 1, should 3, could 0.
1. docs/PRD-v2.md:880 is unchanged: the d3 brief's item 1 (400-line limit, 92.8%) is not done.
2. docs/HANDOFF.md:136 still says 380 lines, which contradicts the 400 the owner chose (Q6 B).
3. home_text.dart:33 and :36 declare `next` and `done`, which nothing in lib or test uses; their docs describe a button that does not exist.

## Findings

- **must** docs/PRD-v2.md:880 The d3 brief's item 1 is not applied: the line still reads "coverage not below 92.9%, and no `lib/` file over 380 lines" (the d3 report says a write was denied; the file is not in the diff) → apply the edit to 92.8% and 400 lines, or have the owner accept the deferral in writing.
- **should** docs/HANDOFF.md:136 The rule still says "no `lib/` file over 380 lines", which the PRD line (once fixed) would contradict → change it to 400 in the same commit, or record why it stays at 380.
- **should** controller_app/lib/src/home/home_text.dart:33 and :36 `HomeText.next` and `HomeText.done` are used nowhere in controller_app/lib or controller_app/test, yet their dartdocs say the coach marks' buttons use them → delete both constants, or wire them to the coach marks and say so in the doc.
- **should** packages/party_host/lib/src/controls.dart:16 `final bool menus;` and controller_app/lib/src/providers/game_feedback.dart:49 `void set(bool shown)` have no dartdoc; guidelines §10 wants every public member documented → add a one-line dartdoc to each.

## Decisions to confirm

- Coverage baseline (docs/HANDOFF.md:67 and :135, docs/dev-tools.md:130 now say 92.8): 19797/21311 = 92.896% and 19778/21295 = 92.879%, which both round to 92.9; 92.8 is only the truncation. The d3 brief asked for 92.8; the owner should confirm which figure is the baseline.
- docs/decisions.md:14 is a dated row (2026-10-24). d3 changed "Android 16 (minSdk 36)" to "Android 12 (minSdk 31)", which goes beyond the brief's "number only". Keep the rewrite, or add a new dated row and leave the old one.
- Which file-size limit the docs state: the owner's 400 (QUESTIONS.md Q6 B, per the d3 brief) against the 380 that HANDOFF.md:136 and the d3 brief's PRD line still carry. Pick one number everywhere.

## Could not check

- The d3 report's claim that the PRD write was denied by the permission settings: the diff shows no change to docs/PRD-v2.md, which is all I can confirm.
- The d2 and d3 check results (d2: controller_app 150 OK, party_host 1 OK, puzzle_game 1 OK; d3: tools/mine.sh ok): docs/briefs/m16/close/run.log has only "finished" and "committed" lines for them, and no check output.
- run.log line 75: d2's usage row covers 2 turns and 0 min but the job ran 8 min wall; the runner flags it as a resumed session, so the turn count is unknown.
- `Controls.only` is called "player numbers" (controls.dart:6, :18): the type is `Set<String>` from `resumers(players)` (pause_menu_widgets.dart:55); I did not trace whether those strings are numbers or ids.
- d2 Question 2: I did not open `PieceMoments`, so "lifts, drops" in puzzle_painter.dart:15-16 is not verified.
- Wording of `foundNearby`, `noScreenFound` and `searchAgain` matches their call sites in home_view.dart:212 and :225; the owner's intent for those words is not checked.
