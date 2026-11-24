# Owner questions for M16 items 7, 8, 9

Only the ones that block a decision. The recommended answer is applied if you say "go".

## Q1. Item 7: how much awards work now?
The host already shows and scores three awards, ties included (M14). Options:
- **A (recommended):** host side only: a pinning test and the device check; final scores stay as they are. Joined phones keep the place and standings from B-040; if their final place leaves out the +3, fix that number only (no new message). The 3rd-to-1st ceremony, awards on joined phones and Skip go with Thumby (M17).
- **B:** also put awards on joined phones: a new additive `awards` field on the result card behind the existing `view` capability, an older-peer test, `docs/protocol.md`. About 3 more jobs, and it touches `providers/view.dart` (380, at cap).
- **C:** also build the 3rd to 2nd to 1st reveal of the final scores now (new timing that M17 would re-time for speech).

## Q2. Consent and coach marks on first launch
Today the crash and stats questions appear on the first frame of Connect (or of the pad when paired).
- **A (recommended):** Home asks both first, and the coach marks begin only after the answers, so a dialog never sits under the dim overlay.
- **B:** coach marks first, the questions after (two overlays compete).

## Q3. Testers who already have the app
- **A (recommended):** show the coach marks once to everyone after this update (Home is new to all).
- **B:** only fresh installs see them; others can turn on Show-tips.

## Q4. "Auto-join last screen" switch
APP-START.md lists it; PRD item 8 does not. The app already reconnects to the last screen and prefers a live one.
- **A (recommended):** keep today's behaviour, add the switch later; item 8 ships roles, marks, Show-tips and strings.
- **B:** add the switch and the "Join a Game waits for a tap" state now (one more job, touches the reconnect path).

## Q5. First-time-host flag (M17 hook)
- **A (recommended):** build it now as a saved yes/no plus a provider, no UI (about half a job inside 8a).
- **B:** leave it to M17 Phase 0.

## Q6. The "no lib/ file over 380 lines" acceptance test
Five files are over 380 today (gyro.dart 398, game_session.dart 399, arena_map.dart 395, split_layout.dart 389, layout.dart 386); the coding guideline's hard limit is 400.
- **A (recommended):** keep 380 for M16 and add behaviour-free split jobs (9f), cheap Haiku work.
- **B:** change the acceptance to the guideline's 400 and split only what new work pushes over.

## Q7. A paired phone on relaunch (added by the main session)
- **A (recommended):** a phone that is still paired opens straight on the pad as today; Home shows when not paired, and from the pad's menu.
- **B:** Home always opens first.
