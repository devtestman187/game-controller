# Wave 3 (S8j) review — the join screen in the host frame

## Summary
**small fixes** — 1 must, 2 should, 5 could.
- must: the brief's "three seats each" / "six players (three a side)" is not built; the cards still seat two.
- should: a phone host now gets the "Start on a phone: pause · Back: leave" pill on the join screen, where Start begins the match (bug 1107f had removed it there).
- should: the body redraws itself at 392 px and scales down below the 20 px type floor for the one unframed caller, puzzle_continue_test.
Checks: frame 17, rewritten party_host 47, untouched join tests 45, puzzle_continue 11, picker/join 20, host_mode 13, host_menu_fit 2 — all pass; `dart format` and `dart analyze` clean on the changed files.

## Findings
- **must** packages/party_host/lib/src/ui/join_screen.dart:59 `maxPerSide` stays 2, so the brief's side cards of "three seats each" and its "six players (three a side)" are not built (the six-player case joins four and leaves two on the notJoined line) → get Claude's decision on whether three seats a side is in scope (it needs a six-player `MatchFormat`; Shape Race seats four) or the brief is amended; the report states this openly but the brief asked for it.
- **should** packages/party_host/lib/src/ui/join_screen.dart:347 `_keyboard` is passed on every host now that the `tight` mode is gone, so a phone host draws the PlayHint pill "Start on a phone: pause · Back: leave" on the join screen, where Start begins the match (bug 1107f hid it there, and s8j-report.md:60 still says `_JoinHint` is unchanged) → pass null when `hostTouchFirstProvider` is true and add a case that the phone host's join hint has no keyboard pill.
- **should** packages/party_host/lib/src/ui/join_screen_widgets.dart:202 the body is drawn at 392 px and scaled with a `FittedBox` whenever a host gives it less room, which shrinks 20 px type to about 12.5 px (852x393 unframed) and runs only for `puzzle_continue_test`, a test outside `allow:` → let that test pump the frame (needs an allow entry) or stop and report it, instead of a scale-down path in shipped code.
- **could** docs/briefs/m16/phonehost2/s8j-report.md:47 the report says a seat's name is ellipsised at `scoreRowNameWidthPx` 190, but join_side_panel.dart:202 gives the name the card's remaining width through `Expanded` and that constant is not used on this screen → say the name takes the row's remaining width, ellipsised.
- **could** packages/party_host/test/join_screen_frame_test.dart:204 the "13.3 dp" check multiplies the 20 px style by the case's own scale constant (0.6667), so it can only fail if the styles change and would pass with a wrong frame scale → measure the rendered scale (the frame's transform or the text's box) or rely on the body-height assertion and name the check for what it proves.
- **could** packages/party_host/lib/src/ui/join_screen.dart:70 `_frameBodyFloorPx = 392.0` repeats the frame's 540 - 64 - 84 arithmetic as a literal though `hostFrameHeaderHeightPx`/`hostFrameFooterHeightPx` are public (host_frame_screen.dart:10, 14) → derive the floor from those so a header change cannot leave it stale.
- **could** packages/party_host/lib/src/ui/join_side_panel.dart:5 `_awayRowOpacity = 0.45` duplicates the exported `scoreRowAwayOpacity` (score_row.dart:58) that this part already has in scope → use the shared constant.
- **could** packages/party_host/lib/src/ui/join_side_panel.dart:169 `height: 1.2` is a bare magic number in `_SideHeader` → name it (e.g. `_sideHeaderLineHeight`) with the 28 px band math in its doc.

## Decisions to confirm
- Three seats a side (must above): raise `maxPerSide` with a six-player format, or keep two and amend the brief; the card's 196 px for three seats fits the 392 px body either way.
- The floor guard (should above): accept the scale-down in lib, or allow editing `packages/party_host/test/puzzle_continue_test.dart` to pump the join screen in the frame.
- The phone host's join hint: should it show the pause/leave pill at all before the round? Bug 1107f said no; the brief said only to drop the `tight` mode.

## Could not check
- The report's sides-row heights (209/240 px) and its 40 px hint lines: no test asserts them and I did not re-measure; the frame tests assert containment only.
- The rest of controller_app/test and the full party_host suite: I ran only the files named under Summary.
- No run-findings.md exists in docs/briefs/m16/phonehost2/, so there are no runner entries for this job.

## Commit message

Review wave3 S8j: frame join screen, seat count, phone hint

Reviewed the S8j diff against its brief, the coding guidelines and the
review rules; the join screen is a HostFrameScreen with 144 px side
cards and its 17 frame tests pass. Findings: the brief's three seats a
side is not built (maxPerSide stays 2), a phone host now shows the
pause/leave pill on the join screen, and the body scales below the type
floor for one unframed test.

## Status row

S8j reviewed (wave 3): the frame join screen, 144 px side cards and the 17 frame tests pass — open: three seats a side was not built (maxPerSide 2), the phone host's join hint shows the pause/leave pill, and the body's scale-down guard needs a decision.

## Delete

- none
