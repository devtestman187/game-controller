## Summary

Two bugs on the Arena's waiting card, one job, tests first.

**B-024 — a Back button.** The card now carries a `HostButton` (Icons.arrow_back, `HostText.back`) keyed `arenaBack`
that pops the card with `Navigator.maybePop`, as Shape Race's `joinBack` does. It sits first in the row under the mode
buttons, beside the Ready button and the card's line of words, so a phone in landscape (852x393) shows it without
scrolling; the mode row already fills a small window (600 wide) without it. It joins the focus order (down from the
card's opening mode focus reaches it) and leaves the opening focus alone: a TV card still opens on its chosen mode.

**B-025 — the own row on touch (owner's option A).** The host device's own `_PlayerRow` keeps its `HostCardButton`
and its focus handling untouched and is wrapped in `IgnorePointer`: the pointer never reaches the row's gesture
detector, so a tap does nothing and shows no press, while the `FocusableActionDetector` above it still answers
`ActivateIntent` — a pad's A, the remote's OK, Enter and Space still toggle ready through `_toggle`. Every other
player's row keeps its tap. `_PlayerRow.onTap` became `onPressed` because it is now a focus activation as well.

**Tests.** Two new files, 7 tests. On the old code 4 of them failed for the bug's reason (3 Back tests, and the
own-row tap readied the player); the other 3 are the kept B-013 paths and passed before and after. After the change:
the 7 new tests pass, the six named Arena test files pass (28 tests), `game_screen_test.dart` passes (9).
`tools/check.sh format analyze host phone`: PASS / PASS / PASS (489 host tests) / PASS (484 phone tests).
`tools/review.sh`: 0 fail, 4 notes, all of them notes the files already carried (`_tick` 43 lines, `_cardBody` 52→56
lines, and both files' sizes, each over the 300-line aim and inside the 400 limit).

**Fixed, unverified: needs device check.**

## What changed

### B-024: the Back button (`arena_waiting_card.dart`)

`_cardBody` builds a `Row` of the Back button, a `space12` gap, and the existing `_ReadyRow` in an `Expanded`. On a
TV (`onReady == null`) `_ReadyRow` still centres its line inside that `Expanded`, so the TV line moves about 62 px right of the card's centre.

Why not the mode row: with Back there, the card at 600x800 (a small laptop window, pinned by
`game_screen_test.dart`'s "fills a small laptop window without overflow") overflowed by 112 px on the right —
the mode row's fixed content (Back 112 + Bumper + Race + the code chip) needs 616 px in the 504 px the card has
(600 − 2x24 menu padding − 2x24 card padding). The row under it has an `Expanded` line that absorbs the space.

The button is `HostButton(label: HostText.back, icon: Icons.arrow_back, onPressed: () => Navigator.of(context).maybePop())`
— the join screen's style and its pop, no new text and no new look. It is not gated on host type: a TV remote can
reach it with the arrows (the brief asks for that), and Escape still leaves the card through `GameScreen`.

### B-025: the own row is a label for touch (`arena_waiting_widgets.dart`)

```dart
child: own ? IgnorePointer(child: row) : row,
```

`IgnorePointer` keeps the whole `HostCardButton` — its `FocusableActionDetector`, its own activation shortcuts
(Enter, numpad Enter, Space, select, gameButtonA) and its focus ring — and only takes the row out of the hit test, so
`GestureDetector.onTap` is never called and the pressed state never shows. A phone's A works the row the way the menus
work every other control (`Actions.maybeInvoke(ActivateIntent)`), which does not go through the pointer at all.

The doc comments on `_PlayerRow`, on `_toggle` and on `ArenaWaitingCard` now say which presses do what.

Card files: `arena_waiting_card.dart` 336 → 365 lines, `arena_waiting_widgets.dart` 343 → 353 lines (limit 380; the
map grid moved into `_mapPicker` so `_cardBody` stays at 56 lines).

## Changed pins

No existing test tapped the own player's row to ready it, so no pin needed rewriting: every existing path goes through
`focusRow` plus the pad's A, the phone's A or the remote's OK, and all of them are still pinned —
`arena_touch_ready_test.dart` (Ready button readies and takes back, landscape fold), `arena_phone_card_test.dart`
(A on the focused row, mode/map walk), `arena_waiting_test.dart` (A on the row toggles, B leaves),
`solo_arena_card_test.dart`, `arena_night_test.dart`, `arena_touch_solo_night_test.dart` (Ready on a night card).
`test/support/host_harness.dart` is unchanged: `readyUp` still readies a joined phone by focusing its row and pressing
A, and a local player by its pad.

## Tests

### `packages/party_host/test/arena_back_test.dart` (new, 3 tests)

1. "the card shows a Back button, which leaves the Arena, as the join screen's does" — key and word present; a tap
   lands on `GamesScreen` and `GameScreen` is gone. Failed on the old code.
2. "the focus walks onto the Back button, and the remote's or keyboard's select pops the card" — primary focus is
   `arena waiting mode` at open; one `arrowDown` puts the focus on `arenaBack`; `select` pops it. Failed on the old
   code.
3. "a phone in landscape shows its Back button, taps it, and reaches it with the arrows" — 852x393 with the own
   player: no exception (no overflow), the Back rect is inside the screen (top ≥ 0, bottom ≤ 393, right ≤ 852), the
   arrows reach it, the tap pops it. Failed on the old code.

### `packages/party_host/test/arena_row_touch_test.dart` (new, 4 tests)

1. "a tap on the own player's row does not ready it, where a tap on another player's row readies that one" — the row's
   rect is above the fold, so the `tapAt(row.center)` really lands on the row; `notReady-p1` stays and the card stays;
   a tap on P2's row still readies P2 and leaves P1 alone. The own-row half failed on the old code.
2. "the card's Ready button readies the own player and takes it back" — kept behaviour, passed before too.
3. "a joined phone's A on the focused own row still readies that player" — kept B-013 path, passed before too.
4. "the remote's OK and Enter on the focused own row still ready it, and take it back" — kept path, passed before too.

### Values

- Mode row needed 616 px in 504 px at 600x800: the 112 px the failed run reported, before Back moved down.
- `arenaReady` bottom and `arenaBack` bottom are both asserted ≤ 393 px on an 852x393 screen.
- Card paddings used: `hostMenuPaddingPx` 24 per side, `ToySizes.space24` per side inside `ToyCard`.

## Decisions

1. **Back sits under the mode row, not in it**: the mode row overflows a 600-wide window by 112 px with a 112 px
   button added, and the row under it has an `Expanded` line that absorbs the width.
2. **Back is leftmost in that row, before the Ready button**: Back left of Ready keeps the Ready button where a thumb expects it (the join screen puts Start first), and the
   line keeps `_ReadyRow`'s own layout.
3. **Back is shown on every host, not only touch hosts**: the brief asks for it on a TV card too, and one card that
   reads the same on a TV and a phone is the guideline's rule 6.
4. **The tap is suppressed with `IgnorePointer` around the existing `HostCardButton`** (the brief's preferred
   option): it keeps one focus implementation, its shortcuts and its ring, and only removes the pointer.
5. **`onTap` renamed to `onPressed`**: the callback is a press of the row (pointer or activation), and "tap" is no
   longer what the own row does.
6. **The map grid moved into `_mapPicker`**: it keeps `_cardBody` at 56 lines after the new row went in.
7. **No test pin rewritten**: no existing test tapped the own row (checked by grep over `test/`), so pins 4 asked for
   had nothing to change.

## Self-check (review-rules part A)

1. **Every host setup** — TV: Back by arrows/OK, no own row exists so no row changes
   (`arena_back_test.dart` tests 1–2, `arena_row_touch_test.dart` test 1's P2 half on a phone); phone "Play on this
   phone": own row is a label, Ready button and Back work (`arena_row_touch_test.dart` 1–2,
   `arena_back_test.dart` 3); phone "Show on this device": no own player, no Ready button, Back shown
   (`arena_back_test.dart:40-52`, which renders the card with no own player); joined phone: its A still
   readies the focused own row (`arena_row_touch_test.dart` 3); one build older: no protocol, storage or route change.
2. **When kept state starts and ends** — no new state: `_ready`, `_before`, `_picked`, `_started` and the 16 ms timer
   are unchanged and end in `dispose` as before; Back pops the card and `dispose` cancels the timer
   (`arena_back_test.dart` 1–3 leave the card and the test ends with no pending timer).
3. **How a new state combines** — Back only acts while the card is up (before "Get ready"); it does not touch
   `_ready`, so a player who readied and then went Back leaves nothing running; a phone's B still leaves the Arena
   (`arena_waiting_test.dart` "a phone's B leaves the Arena from the waiting card"); no pair with pause, away,
   Get ready or results exists yet, because the card is gone by then.
4. **Stay in the job's folder** — only `docs/briefs/m14/bugs13/arena-waiting-report.md`, the two
   `arena_waiting_*` files and two files under `packages/party_host/test` were written.
5. **Stop rather than overstep** — nothing outside `allow:` was needed; the one layout decision (Back's place) was
   made here and is above, since the brief leaves it to the worker.

## Fixed, unverified: needs device check

- The own row's tap falls through to the card's scroll view, so a drag that starts on that row should still scroll
  the card; no test drags, and this needs a thumb on a device.
- "Shows no press feedback" is shown only by the pointer never reaching the button (`HostCardButton` draws no press
  look of its own); a device check should confirm nothing flashes when a thumb lands on the own row.

## Questions and suggestions

1. Should the own row keep taking the focus on a touch-first host, where no pad exists to press it? The brief says it
   stays focusable, so it does; on a phone host the row is a stop the D-pad can reach and A can press.
2. `arena_touch_ready_test.dart`'s doc claims the card is "measured with the look's real fonts"; its tests now matter
   for width again (the Back button) — worth keeping the fonts loaded in any later card test.
3. The card is at 365 lines and `_tick` at 43 lines (review note, pre-existing); a later card change should split
   `_tick`'s local-player reading into a method.

## Hand-over

- Read `arena_back_test.dart` and `arena_row_touch_test.dart` first: they are the failing-first proof.
- The Back button's place is the only visible layout change; check it on a TV mock-up (frame 8) and on a phone in
  landscape before the next card job.
- Nothing else in the round start, the maps, Robo's row or the join screen was touched.

## Commit message

Arena waiting card: a Back button, and the own row is a label for touch

B-024: the card has a Back button (arenaBack, HostText.back) under the
mode row, shown without scrolling on a phone in landscape and leaving the
opening focus alone; it pops the card as the join screen's Back does.
B-025 (owner's option A): the host device's own player row is wrapped in
an IgnorePointer, so a tap does nothing, while a pad's A, the remote's OK
and Enter still ready it through the row's focus. Other rows keep taps.
Two new test files (7 tests, 4 of them failing on the old code).

## Status row

B-024 and B-025 done (Back button on the Arena waiting card; own row is a tap-free label, focus activation kept) — open: device check of the tap fall-through and of the Back button's look on a TV.

## Delete

- none
