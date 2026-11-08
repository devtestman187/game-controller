# M12 bugs 1108c and 1108d — G4 report: a phone host says what begins the match, and neither host choice is lit

Done at G4, the gate the brief names ("stop: after both"). 1108c: the join screen's status line now says what can
actually begin the match on this host — the TV's "Press A or Start to begin." is unchanged, a phone that plays here
says "Tap Start to begin.", and a phone that only shows the game says "Tap Start, or press A on a phone, to begin."
1108d: both choices in the "Host a game" sheet are the same outlined button with the line under its name, nothing
takes the focus, so nothing is lit when the sheet opens; a choice lights only under a thumb (the button's own ink).
No other file was touched.

## Files changed

- `packages/party_host/lib/src/ui/join_screen_widgets.dart` (178 → 192 lines) — new `_beginText({touchFirst,
  hasOwnPlayer})`, the three wordings in one place; `_JoinButtons` is a `ConsumerWidget` now, takes the host phone's
  `ownPlayerId` and reads `hostTouchFirstProvider` where the words are chosen; the format line is
  `'${formatName(...)}. $begin'`.
- `packages/party_host/lib/src/ui/join_screen.dart` (363 lines, one line changed) — the `_JoinButtons` call passes
  `ownPlayerId: ownHere`. (Passing two extra flags instead put the call on seven lines and the screen's `build` at
  63, past the 60-line rule; `tools/review.sh` said so, so the flag is read in the widget that uses it.)
- `controller_app/lib/src/host/host_start_sheet.dart` (103 → 93 lines) — `_Choice` loses `primary` and picks one
  button: `OutlinedButton.icon`, no `autofocus`; its doc comment says both ways look the same, neither is focused
  (the phone has no remote), and a press's own ink is the only light. Cancel unchanged.
- `packages/party_host/test/join_screen_test.dart` (302 → 344 lines) — the group "the status line says what begins
  the match (m12 bug 1108c)": three tests, TV, Play, Show.
- `controller_app/test/connect_screen_test.dart` (195 → 204 lines) — the sheet test now asserts two `OutlinedButton`s
  in the dialog, no `FilledButton`, and neither choice focused (replacing the old "the phone one has the focus"
  check); `choiceFocused` is the helper for the last two.
- `docs/briefs/m12/bug-1108c-fix-report.md` — this report.

## 1108c: the status line, in the three cases

| Host | Words after the format | Test |
| --- | --- | --- |
| TV, PC, Windows app (`hostTouchFirstProvider` false) | `. Press A or Start to begin.` | 'a TV host keeps "Press A or Start to begin"' |
| Phone, "Play on this phone" (touch first, own player here) | `. Tap Start to begin.` | 'a touch-first host that plays here says "Tap Start to begin"' |
| Phone, "Show on this device" (touch first, no own player) | `. Tap Start, or press A on a phone, to begin.` | 'a touch-first host that only shows the game says "Tap Start, or press A on a phone"' |

- "Nobody has joined yet." and the hint line above are untouched (the hint's own test, 'the own player is on the
  left on entry, marked, and Start begins the match', still passes unchanged).
- "An own player" is the same signal the hint uses, `ownHere` (the own player is present and plays here). In "Show
  on this device" `shareView` is false, so `_ownPlayer` is null and the line is the third one; so is a "Play on this
  phone" host whose own player is away (Question 1).
- The format words still come from `formatName(MatchFormat.of(teams))`, so "1 player", "1 vs 1", "A team of 2 on one
  board", "2 vs 1" and "2 vs 2" all read as before. The tests read `1 player` because one player on a side is
  `MatchFormat.solo`.

## 1108d: the sheet

- Both choices: `OutlinedButton.icon` with the same `ButtonStyle` (left-aligned, 16/12 padding), the icon, and the
  title with its line under it. No `primary` flag is left.
- No `autofocus` anywhere in the sheet, so when it opens the focus stays on the dialog's own scope and neither
  choice draws a focus colour; previously the phone choice was a `FilledButton` with `autofocus: true`, which is the
  filled, lit button the owner saw. The phone's `HostFocusScope` also keeps Material's focus overlay transparent
  until a pad moves it, so nothing is lit there either.
- A choice lights only while a finger is on it, from Material's own pressed state; no focus look is added.
- Cancel is unchanged; the sheet still returns the tapped `HostChoice`, or null on cancel or a tap outside.

## Tests, each failing first

| Test | Before the fix | After |
| --- | --- | --- |
| join_screen 'a TV host keeps "Press A or Start to begin"' | passed (guard: the TV's words must not change) | passes |
| join_screen 'a touch-first host that plays here says "Tap Start to begin"' | **failed** — `Expected: '1 player. Tap Start to begin.'` / `Actual: '1 player. Press A or Start to begin.'`, differ at offset 10 | passes |
| join_screen 'a touch-first host that only shows the game says "Tap Start, or press A on a phone"' | **failed** — `Expected: '1 player. Tap Start, or press A on a phone, to begin.'` / `Actual: '1 player. Press A or Start to begin.'`, differ at offset 10 | passes |
| connect_screen '"Host a game" is offered with no TV, and asks how to host' | **failed** — `Expected: exactly 2 matching candidates` / `Actual: … Found 1 widget with widget matching predicate descending from widget with key [<'hostStartSheet'>]` (one outlined; the other was the filled, focused one) | passes |

Both 1108c "Actual" lines above are from a run with the `hostTouchFirstProvider` read taken out of `_beginText`'s
input (`touchFirst: false`), which reproduces the old wording exactly.

The tests' values, so the review can check them against the rules:

- The three lines are the whole strings, not prefixes: `'1 player. Press A or Start to begin.'`,
  `'1 player. Tap Start to begin.'`, `'1 player. Tap Start, or press A on a phone, to begin.'` — each is
  `formatName(MatchFormat.solo)` + `'. '` + the brief's words.
- The Play test mounts the host with `ownPlayerIdProvider` = `'p1'` and `fake.shareView = true` ("Play on this
  phone"), so `_ownPlayer` is `p1`; the test checks "P1 iPhone 3F1C (you)" is on `side-left` as well, so the own
  player is in the match. The Show test overrides only the touch-first flag, so there is no own player at all (as in
  "Show on this device"), and it checks the joining phone is plain "P1 iPhone 3F1C" (no "(you)").
- The sheet test counts 2 `OutlinedButton`s and 0 `FilledButton`s inside the dialog's subtree. It uses a
  `w is T` predicate, not `find.byType`: `OutlinedButton.icon` builds a private `_OutlinedButtonWithIcon`, which
  `find.byType(OutlinedButton)` does not match.
- `choiceFocused` reads `Focus.of(...).hasFocus` at the first `Text` inside each keyed choice (the button's own
  focus node), as `packages/party_host/test/support/host_harness.dart`'s `focused` does; both are false after the
  fix and `hostOnPhone` was true before it.

## Test counts, before and after

Measured with `tools/check.sh` on this machine (before: run at the start of the job, all green):

| Check | Before | After |
| --- | --- | --- |
| host (`party_host`) | 135 | **138** (the three status-line tests) |
| phone (`controller_app`) | 382 | **382** (the sheet test's assertions changed; no test added) |
| tv | PASS | PASS |
| format, analyze | PASS | PASS |

## Checks run

- `tools/check.sh format analyze host phone tv` — PASS, all five (format 2 s, analyze 9 s, host 138 in 19 s, phone
  382 in 36 s, tv 11 s).
- `tools/review.sh` — `review: 0 fail, 1 note`: `join_screen.dart` at 363 lines (lib limit 400, aim 300), the same
  count it had when the job started. The first version of the fix had `build` at 63 lines (`FAIL func`); the call
  now passes `ownPlayerId` and the flag is read in `_JoinButtons`.
- `tools/review.sh --strings` — 1 removed, 4 added: the old `'… Press A or Start to begin.'` is replaced by the three
  wordings and the `'. $begin'` join; nothing else moved.
- `git status` still lists `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h` and
  `generated_plugins.cmake` as modified: a line-ending change from a Flutter tool run, outside `allow:` and not
  edited by this job.

## Questions

1. **A "Play on this phone" host whose own player is away** reads "Tap Start, or press A on a phone, to begin."
   (the line follows `ownHere`, as the hint does, and an away player has left the match). If you want it to stay on
   "Tap Start to begin." there, the signal would be `shareView` alone; I kept the two lines consistent instead.
2. **No pressed-state test for the sheet.** The brief asked for two sheet checks (neither focused, both the same
   kind of button), and both are in; a press's ink is Material's, so I did not add a third test for it.
3. Suggestion for `docs/project-notes.md` (not in `allow:`): `find.byType` does not match `OutlinedButton.icon`'s
   private subclass, so a widget test that counts button kinds needs `find.byWidgetPredicate((w) => w is X)`.

## Self-check (review rules, part A)

1. **Every host setup.** TV/PC: the words are unchanged — join_screen 'a TV host keeps "Press A or Start to begin"'
   plus the file's other 10 unchanged tests; phone "Play on this phone": 'a touch-first host that plays here says
   "Tap Start to begin"', and the real app still walks a solo round through that screen in `host_mode_test` and
   `host_own_player_test`; phone "Show on this device": 'a touch-first host that only shows the game says "Tap Start,
   or press A on a phone"'; a joined phone: the line is the host's screen only, its `joinedLayout` and the menu
   labels are untouched (`joined_view_test`, the join screen's first test); a build one older: only text changed, no
   message or field, so nothing to test.
2. **When kept state starts and ends.** Nothing is kept: the line is computed each build from the team map, the
   own player and the touch-first flag, with no timer, cache or flag added — the three tests re-read it as a phone
   joins and the own player joins. The sheet holds nothing either: nothing focused when it opens
   (connect_screen test), the ink ends with the finger, and the dialog answers once — 'cancelling the sheet starts
   nothing' still passes.
3. **How a new state combines with the others.** Neither change pauses, hides or blocks anything: one is a `Text`,
   the other removes an `autofocus`, so the pause menu, the host away, a player away, Get ready, a dropped link,
   the results and leaving behave as before. The pairs that can happen together — a phone joining while the host
   plays here (line follows the format and keeps "Tap Start": the own-player group's 'a tap on a side moves only
   the own player there, and the format follows'), and the own player away while showing (Question 1) — are covered
   by tests that still pass.
4. **Stay in the job's folder.** Five files under `controller_app/lib`, `controller_app/test` and
   `packages/party_host`, plus this report; the job's worktree is the only place anything was written.
5. **Stop rather than overstep.** Both bugs done as the brief says and nothing else; the only judgement calls are
   Question 1 (already reported, not decided) and reading the touch-first flag inside `_JoinButtons` to keep
   `build` under 60 lines, which the review script can be pointed at.

## Commit message

Say what begins the match on a phone host, not a pad

- The join screen's status line says what can begin the match on this host: the TV keeps "Press A or Start
  to begin.", a phone that plays here says "Tap Start to begin.", and a phone that only shows the game says
  "Tap Start, or press A on a phone, to begin." (m12 bug 1108c).
- "Nobody has joined yet." and the hint above are unchanged, as is the TV's wording.
- Both choices in the "Host a game" sheet are the same outlined button with its line under the name, and
  neither takes the focus, so nothing is lit when the sheet opens; a choice lights only under a thumb
  (m12 bug 1108d).
- Three host tests for the three wordings and the sheet test's two checks.

## Status row

Bugs 1108c and 1108d fixed at G4: a touch-first host's join screen names the Start tap (and the joining phone's A
when it only shows the game), the TV's words are unchanged, and the "Host a game" sheet draws both choices as the
same outlined button with nothing focused or lit, with three new host tests and the sheet test's checks green.

## Delete

- none

## Claude's answers

1. Keep it: an away own player has left the match, so the line follows `ownHere` like the hint does.
2. Agreed, no press test: the ink is Material's.
3. Noted for project-notes (Claude adds it).
