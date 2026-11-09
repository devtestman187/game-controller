# M13 s21 — the focus shows on a touch-first host worked by a pad: report

**Status: done.** The owner's case is fixed and reproduced by a test through the phone
app; every host screen a pad can walk shows the focused thing as an outline. Three
causes, all in the drawing or the wrapper, none in the focus logic.

Checks: `tools/check.sh format analyze look host phone tv` passes (look 111, host 270,
phone 436, tv 53 with 1 skipped) and `tools/review.sh` is 0 fail, 0 note.

## The cause, with evidence

Three separate faults, in the order the owner met them.

### 1. The card's ring was painted under the card (the picker in the screenshot)

`HostCardFocus` wrapped the card in `Padding(4)` *outside* the `CustomPaint`, so the
painter's whole box was the card's own box: the ring it drew at `deflate(focusRing / 2)`
lay exactly under the card's ink edge and paper, which paint over it (the paper is a
`Positioned.fill` in `toy_card.dart`). The card's `isLit` was true, the focus was on the
card, the look was on — and nothing of the focus colour reached the screen. Only the
corners of the ring (`cardCorner + focusRing/2`) showed, four 2 px slivers a thumb can't
see.

Measured on the picker (test harness, 1024×768, phone look), pixels read back with
`screenPixels`: the Shape Race card is `Rect.fromLTRB(24, 80, 404, 272)`; a scan at
`y = 176` gives sky `0x89CEF9` up to x = 27, the card's ink edge `0x1E1646` at x = 28–30,
paper `0xFFF6E3` from x = 31. Counting pixels of the look's focus colour `0xFFFFD23F`
within 6 px of the card's box: **0**. The same count round a `HostButton` in the same
frame (the Puzzle settings button): **2182** — so the measure is right, and the buttons
were fine; the cards were not.

After the fix the ring is drawn in the 4 px room the padding leaves round the card, 2 px
outside the card's ink edge, as `ToyButton` draws its own: the same count is above zero
and the old card's is zero. This is `packages/party_host/test/host_focus_ring_test.dart`'s
first test and the reproduction in `controller_app/test/host_focus_pad_test.dart`.

### 2. A thumb remounted the menus, so the next pad press went nowhere

`HostFocusScope` returned `child` when the look showed and `Theme(child: child)` when it
didn't: two different widget types in the same slot, so the first thumb on a touch-first
host rebuilt everything below it with new elements. The `ControllerMenus` `State` was
thrown away and made again — measured with `identityHashCode` of
`tester.state(find.byType(ControllerMenus))` either side of one tap: **743953005 →
930461894**; with the fix, **782815561 → 782815561**. The new menus start with an empty
`_before`, spend their first reading recording what the phone holds, and the change that
reading carried (the press) is dropped: after a thumb, the next pad press did nothing at
all, not even `padUsed`, so the focus look never came back. That is brief item 4 broken.

The fix keeps the `Theme` in the tree always and changes only its `focusColor` (the look's
own `focus` at alpha 0 while the look is hidden, as before). Same tree shape, no remount,
the press arrives: the test asserts the menus' `State` is the same object after the thumb.

### 3. The Material controls' focus look is a 35 % wash, not an outline

The theme's `focusColor` is `_focusWash(look)` = `focus` at `toyShadowAlpha` (0.35):
`0x59FFD23F`. A focused `SwitchListTile` on a `ToyCard`'s cream paper changes 55,626 of
its 71,280 pixels, every one by **57** in one channel (a pale cream-yellow tint). The toy
ring is 4 px of solid `0xFFFFD23F`, a gap of **255** to the same paper. On the cream and
the sky the wash is a tint, not an outline: it does not say "this one" from where a
player sits, which is what the owner asked for ("an outline of some kind"). So the
switches, sliders, the palette's segments and the title bar's back arrow now draw the
toy's ring as well (`ToyFocusRing` in `toy_look`, `HostFocusRing` in `party_host`, which
follows `hostFocusLookProvider`). The wash is left in place: it is the Material control's
own ink, and removing it would take the only focus mark from the phone app's own dialogs,
which this job may not change.

### Which of the brief's candidates it was not

- **No `padUsed`**: no — `padUsed()` runs on the press; the look was on.
- **A different provider container or scope**: no — the menus and the cards read the same
  container, and the same `HostFocusLookNotifier` instance (checked by identity).
- **The focus on something not drawn** (off-screen, title bar): no — `pickArena` had the
  focus, on screen, and its `HostCardFocus.isLit` was true.
- **A pointer event calling `touched`**: not spuriously; a thumb does hide the look by
  design, and cause 2 is what made the pad unable to bring it back.
- **The ring drawn but not visible**: **this** (cause 1), plus a faint look on the
  Material controls (cause 3).

## Files changed

- `packages/party_host/lib/src/ui/host_card_focus.dart` — the painter wraps the padding
  instead of sitting inside it, so the ring paints in the room left round the card.
- `packages/party_host/lib/src/ui/host_focus_scope.dart` — the `Theme` stays in the tree
  and only its `focusColor` changes, so a thumb no longer remounts the app below it.
- `packages/toy_look/lib/src/toy_focus_ring.dart` — **new** `ToyFocusRing` and
  `ToyFocusRingPainter`: the look's 4 px `focus` ring round a control that keeps the focus
  itself, drawn over the control's own edge (its box and layout don't move), with
  `showFocus` for a host that hides the look.
- `packages/toy_look/lib/toy_look.dart` — exports it.
- `packages/party_host/lib/src/ui/host_focus_ring.dart` — **new** `HostFocusRing`: the
  ring following `hostFocusLookProvider`, for the host's Material controls.
- `packages/party_host/lib/party_host.dart` — exports it.
- `packages/party_host/lib/src/ui/host_screen.dart` — the title bar's back `IconButton`
  wrapped in `HostFocusRing`.
- `packages/party_host/lib/src/ui/puzzle_settings_screen.dart` — the drop-ready highlight
  switch wrapped.
- `packages/party_host/lib/src/ui/look_and_sound_section.dart` — the palette's
  `SegmentedButton`, the effects and Mute switches and both volume sliders wrapped.
- `packages/party_host/test/host_focus_ring_test.dart` — **new**, 14 tests (below).
- `controller_app/test/host_focus_pad_test.dart` — **new**, the reproduction: the phone
  app, "Show on this device", a phone joined over a socket on this machine, reading the
  screen's pixels.
- `packages/party_host/test/zz_ring_diag_test.dart` — the measurement test used to find
  the three numbers above; it has `debugPrint`s and goes (see Delete).

## Every host screen, and what shows its focus

| Screen | What the pad can reach | What shows the focus |
| --- | --- | --- |
| Game picker | `pickShapeRace`, `pickArena`, `openPuzzleSettings` | card: 4 px `focus` ring round the card, outside its ink edge (fixed); Puzzle settings: `ToyButton`'s ring |
| Shape Race level and puzzle lists | `random-<level>`, `puzzle-<id>` | `ToyButton`'s ring (broken outside the pill, under the paper) |
| Puzzle settings | the ten rows' two step buttons; the drop-ready highlight switch | row buttons: `ToyButton` ring; the switch: `HostFocusRing` (new). The screen has no slider; the sliders are on Look and sound |
| Look and sound (the host's settings) | the palette segments, Effects, Mute, Sounds and Music volumes | `HostFocusRing` on all five — the toy ring where the wash used to be the only mark |
| Title bar | the back arrow, where there is something to go back to | `HostFocusRing` on the `IconButton` |
| Join screen | `joinStart`, `joinBack` (and the sides' rows are text, not focusable) | `ToyButton`'s ring |
| Results | Play again / Rematch / Next, `changeTeams`, `resultsBack` | `ToyButton`'s ring |
| Pause menu | `pauseQuit`, `pauseResume` | `ToyButton`'s ring; the menu is a dialog over the round |
| Host dialogs | the consent dialog's `consentNo` / `consentYes`, the pause card | `ToyButton`'s ring — no host dialog uses a Material button |
| Rating card | none | The rating prompt is the phone's own dialog (`controller_app/lib/src/ui/rating_prompt.dart`): taps, a 20 s timeout, toy faces, no focusable, and the pad is released while it shows. Not a host screen and not pad-worked; unchanged |
| Phone start sheet | none | `host_start_sheet.dart` is the phone's hosting choice, touched before a host runs; no `ControllerMenus` is up, so no pad works it. Unchanged |

The brief also says "any dialog": every dialog a host screen shows is a `Dialog`/`AlertDialog`
whose buttons are `HostButton`s (the pause card and the consent prompt), so it shows the
toy's ring; the controller app's own dialogs (Settings, the stick and gyro help, the rating
prompt) are outside this job's `allow:` and are touched, not panned.

## Tests: before and after

`tools/check.sh` suites, tests passed: **look 111 → 111**, **host 254 → 270** (268 once
`zz_ring_diag_test.dart` goes), **phone 435 → 436**, **tv 53 → 53** (1 skipped).

Failing first, and why:
- `controller_app/test/host_focus_pad_test.dart`: `a joined phone's pad rings the card it
  moves to on "Show on this device"` — failed with 0 focus pixels round the card before
  cause 1 was fixed (re-checked by putting the old `HostCardFocus` back and running it),
  and its last part failed before cause 2 was fixed (the look stayed on after a thumb).
- `host_focus_ring_test.dart`: `the picker rings the card that has the focus` and the six
  Material rows (`puzzle settings switch`, `effects switch`, `mute switch`, a volume
  slider, the palette segments, the title bar's back arrow) — all failed with `0` before
  their fix.

Already passing, kept as regression cover for the brief's screen list (they draw with the
`ToyButton` ring, which worked): `Shape Race's level and puzzle buttons show the ring`,
`the join screen's buttons…`, `the pause menu's buttons…`, `the results' buttons…`,
`a touch hides the ring, and the next pad press brings it back`, `a TV shows the ring from
the start, and a pointer does not take it away`.

`a touch hides the ring…` also pins cause 2: it takes the `ControllerMenus` `State`
before the thumb and requires the same object after the next press.

## Self-check: docs/review-rules.md part A

1. **Every host setup.** TV and PC: `a TV shows the ring from the start, and a pointer
   does not take it away` (a pointer is a mouse there, so the look stays). Phone on
   "Show on this device": `a joined phone's pad rings the card it moves to on "Show on
   this device"` (real overrides, a real socket). Phone on "Play on this phone": the same
   `HostFocusScope`, the same screens and the same look rule; the phone suite's own-player
   and top-bar tests pass (436). A joined phone: the same test. One build older: not
   affected — the change is drawing and a widget shape, with no protocol, saved file or
   provider shape touched.
2. **When kept state starts and ends.** The only kept state here is
   `HostFocusLookNotifier`'s flag: it starts at `!hostTouchFirst` (false on a phone host,
   true on a TV or PC), `padUsed()` sets it, `touched()` clears it, nothing times it and
   nothing but those two calls changes it — `host_focus_look_test.dart`'s existing tests
   and the new `a touch hides…` / `a TV shows…` cover each end. What used to end at every
   touch, undeservedly, was the menus' memory of the phones' buttons; the new test asserts
   the `State` survives the thumb (`same(menus)`).
3. **How a new state combines with the others.** Not affected: the focus look is a drawing
   flag and owns no round state. It shows over the pause menu and the results as over any
   screen (both tested in the ring table with the pause/results rows), a thumb on a paused
   round hides it as anywhere else, and it never gates input — `ControllerMenus` presses
   regardless of it. The host suite's pause, away and get-ready tests all pass (270).
4. **Stay in the job's folder.** Every file is in `allow:` (`packages/party_host`,
   `packages/toy_look`, `controller_app/test`, and this report); nothing else was touched
   (`git status` shows only pre-existing `docs/design/*.png` and `tv_test_app/windows`
   changes this job didn't make).
5. **Stop rather than overstep.** Nothing outside `allow:` was needed. Left alone on
   purpose, and reported instead: the phone app's own dialogs (Settings, stick/gyro help,
   rating prompt) still show Material's wash, and `host_start_sheet.dart`'s `TextButton`
   too — they are outside `allow:` and no pad works them (see the table).

## Questions and suggestions

1. Should the wash go where a ring now draws? Both show today (the ring over the control's
   edge, the wash under its ink). Turning `focusColor` off globally would also take the
   only focus mark from the controller app's dialogs, so I left it.
2. The phone app's own dialogs (Settings, the stick and gyro help, the rating prompt) could
   take `HostFocusRing` too, but they are outside this job's `allow:` list and are touched,
   not panned; a follow-up job if Claude wants them ringed.
3. Cause 2 is a trap worth a rule: any wrapper that returns its child on one state and a
   wrapper widget on another (in a `MaterialApp.builder`) remounts the app below it. A grep
   for `? child :` in the apps' builders would say whether any other one does it.
4. The ring's size and colour are `ToySizes.focusRing` and `look.colors.focus` for the
   Material controls too; if a row should look different from a button, the painter is the
   one place to say so.

## Commit message

Ring the focused control on every host screen a pad works

The picker's cards drew their focus ring under the card's own paper, so nothing
showed what a joined phone's pad had selected; the ring now paints in the room
the padding leaves round the card.
HostFocusScope swapped a Theme in and out of the tree, which remounted the
controller menus on every touch and threw away the next pad press; the Theme
stays and only its focusColor changes.
Switches, sliders, palette segments and the title bar's back arrow now show the
toy ring instead of Material's 35 % wash, a tint on the cream and the sky.

## Status row

s21 host focus: done — the picker's card ring, the touch-then-pad press and the toy ring on every Material control are fixed and tested (host 270, phone 436); open: the controller app's own dialogs still show Material's wash (outside allow).

## Delete

- packages/party_host/test/zz_ring_diag_test.dart

## Claude's review

Accepted. The three causes are measured, not guessed (focus pixels round the card 0 vs 2182 round a button; the menus' `State` identity across a thumb), and each fix is at the cause: the painter outside the padding, a `Theme` that stays in the tree, and a toy ring where Material only washed. Checks pass (look 111, host 268, phone 436, tv).
- Q1 (drop the wash where a ring draws): no, keep both. The wash is still the only mark in the phone app's own dialogs, and under a ring it does no harm.
- Q2 (ring the phone app's own dialogs): not now. No pad works them; revisit if one ever does.
- Q3 (other wrappers that swap their child): checked, a grep for `? child :` in every app and package `lib` finds none.
- Device test: on the iPad in "Show on this device", moving through the picker with a joined phone's D-pad should now ring the cards.
