# Thumb Party M16 — UX proposal: the player flow, end to end

Status: **proposal** (owner decides; nothing is implemented). Evidence: live capture on the
Pixel Tablet + Sony BRAVIA TV plus a 10-size logical matrix (`findings/`), and six competitive
digests (`research/`). Mockups: `mockups/proposal-mockups.html` (source) and
`mockups/proposal-*.png` (rendered, Sunny + Night). Every recommendation traces to a measured
finding (`findings/_gap-inventory.md`, "CC n" = its cross-cutting item) or a cited digest.

## The five changes to make first

1. **Put the round's state on the phone.** During a round the joined phone shows only the pad —
   no clock, score, coins, round number or winner (CC 1; `vf-2dev-round`). Every phone-as-controller
   peer studied gives the controller real state (Jackbox, AirConsole). Mockup frame 0.
2. **Make a drop visible, and restore the side on re-entry.** A dropped player's slot vanishes in
   0.9 s with no away state; re-entry loses the side (stage 13; `vf-2dev-lifecycle`). The field holds
   the seat (Mario Party/LEGO CPU-fill, AirConsole `device_id`, Jackbox host pause). Mockup frame 1.
3. **Show the pairing code on the join screen.** The 4-digit code lives only on the host shell and the
   Arena card, never on the join screen a player is looking at (CC 3). Mockup frame 2.
4. **Fix the sub-3:1 contrast.** `good`-on-`paper` "Ready"/"+43" 1.97:1, dashed face circles 1.82:1,
   state dot 1.00:1, D-pad disc 2.16:1, knob 2.57:1 (CC 12). These are recolours inside the existing
   token system. Mockup frame 3.
5. **Give players a real identity.** Today the only identity is device-derived "P1 Phone 1719". Add
   nickname + colour + accessory (already planned, look-and-sound §5b) and show it on the TV.
   Mockup frames 4–5.

## The flow, stage by stage

Notation: **now** = measured current behaviour; **proposed** = the change; **why** = evidence.

1. **Launch / first run** — now: phone paints the pad 4 s after start, TV paints the host shell.
   proposed: keep, but the connecting pill's 2 px outline is the only thing separating it from the sky
   (fill is 2/255 off `background`); give it a real fill and fix the a11y string
   ("Connecting…" vs "Not connected"). why: CC 1, 13; no peer gates launch behind a tutorial.
2. **Host setup** — now: three TV surfaces + a phone Settings page with 5 of 7 slider a11y values
   wrong. proposed: one consistency pass on "selected" fill (caution vs focus, CC 7) and slider values.
   why: measured (`vf-tab-01`); LEGO/AirConsole keep host setup to one surface.
3. **Party join** — now: 4-digit code on the host shell only; the phone's first tap targets a stale
   remembered host and fails. proposed: show the code on the join screen and prefer live discovery.
   why: CC 3; 5/6 games put the code where players look.
4. **Player creation / colour & accessory** — now: none live (nickname field clipped to 4 px).
   proposed: nickname + colour + accessory on the phone, shown on the TV. why: stage 4; every peer has
   some identity (name/character/Mii); Thumb Party's planned colour+accessory is ahead of the field.
   Thumby: each colour+accessory combination needs a stable ID and a spoken name ("the Red Bow");
   nicknames are caption-only.
5. **Lobby & waiting** — now: join-screen footer or the Arena waiting card; no ready-check, no map
   name. proposed: a per-slot ready state with a readable "Ready" (contrast) and the code on-screen.
   why: CC 12; LEGO per-slot ready, AirConsole "Has everyone joined?", Jackbox VIP start — none auto-start.
   Thumby: expose player joined / look picked / game chosen as events; a host-side first-time-host flag.
6. **Game selection** — now: "Pick round 1" sits 466 px below the fold; card text truncates. proposed:
   move the action above the fold and stop the ellipsis. why: `vf-tv-01`; Wii Party shows count+duration
   before commitment.
   Thumby: Party night is the first, highlighted card; the three-role home stays.
7. **Round intro / countdown** — now: TV 3-2-1 card, phone shows nothing; HUD band jumps 108→284 px.
   proposed: stable band; the phone shows the countdown. why: CC 1; Mario Party/LEGO give a rules/controls
   beat; AirConsole owns a 3 s resume countdown.
8. **In-round controls** — now: phone carries no clock/coins/dash state; clock never turns `bad`.
   proposed: surface state on the phone; turn the clock red in the final 15 s (spec §3 says it should).
   why: CC 1, stage 8; Jackbox/AirConsole put live state on the controller.
9. **Round end** — now: results card overlaps the HUD and clips a row; phone shows nothing.
   proposed: card clears the HUD; phone shows its result. why: `vf-2dev-round`; Mario Party/LEGO
   announce a payout/result beat.
10. **Results / scoreboard** — now: coins→points are never reconciled; "Round 1" drawn twice;
    `+43` at 1.97:1. proposed: one numbering ("Round 2 of 3"), convert coins→points visibly, fix `good`
    text. why: CC 2, 12; Mario Party/LEGO have a clear ranking + tiebreak.
    Thumby: scoreboard cards must fit a phone host and leave the caption strip free.
11. **Next round / Play again** — now: one press picks *and* starts the next game, no confirm.
    proposed: a confirm, or a distinct "Play again". why: `vf-2dev-round`; Wii Party offers "replay the
    same game".
12. **End of night** — now: the three awards are promised on setup but never appear. proposed: deliver
    them at the end. why: CC 21; Mario Party/LEGO/Wii Party all end with a ceremony; none has a
    cross-game summary, so skip that.
    Thumby: leave a caption/bubble slot, ceremony order 3rd -> 2nd -> 1st, timing that tolerates speech.
13. **Re-entry after a drop** — now: slot vanishes in 0.9 s, no away state; host-away shows no card.
    proposed: "away" state + grace period + side restore; host-away card on the phone. why: stage 13;
    AirConsole reserves `device_id`; Jackbox pauses 5 min on host drop.

## Recommendations at a glance

| # | Change | Impact | Effort | Depends on owner scope? |
|---|---|---|---|---|
| 1 | Round state on the phone | Very high | Med–High | **Yes** (additive protocol field) |
| 2 | Visible drop/away + side restore | High | Low–Med | No |
| 3 | Code on the join screen | High | Low | No |
| 4 | Sub-3:1 contrast fixes | Med–High | Low | No |
| 5 | Nickname + colour + accessory | Med–High | Med | **Yes** (§5b customisation) |
| 6 | End-of-night awards | Med–High | Med | **Yes** (what the night ends like) |
| 7 | Consistency pass (numbering, map name, clock, Resume) | Med | Low | No |
| 8 | 48 dp targets + truncation | Med | Low | No |
| 9 | Accessibility (slider values, a11y strings) | Med | Low | No |

## Thumby integration (M17)

The AI host "Thumby" is settled (`docs/briefs/m17/ux-review/PROPOSAL-v2.md`, owner answers Nov 20)
and is built in M17 on top of M16. M16 changes no behaviour for it, but must be built so it slots in:

- **Picker.** Party night is the **first, highlighted card** in the game picker (`games_screen.dart`).
  The three-role home (Join / Play here / Display here) stays unchanged.
- **Phone host first (prerequisite).** The night cards (start, scoreboard, reveal, results) are
  fixed-width for 1280x720 (`nightStartCardWidthPx` 1040, `nightScoreCardWidthPx` 900,
  `nightRevealCardWidthPx` 860). M16 must make them fit a ~360x640 dp phone host and reserve room for
  Thumby: a 56 dp corner head plus a 2-line caption strip (S, phone), a bubble on tablet/TV (M/L).
  **Measuring how they fit a phone is a prerequisite** (unverified today; no FittedBox or breakpoint).
- **Identity (item 5).** Each colour + accessory combination (36) gets a **stable ID** and a
  **display/spoken name** ("the Red Bow") that M16 shows and Thumby speaks. Nicknames are caption-only,
  never spoken.
- **Awards (item 6).** The reveal and final screens leave a slot for Thumby's caption/bubble and use a
  ceremony order 3rd -> 2nd -> 1st. Reveal timing must tolerate a spoken line: the missed-award 2 s
  may be too short (a design point, not a decision).
- **First-time-host flag (host side).** Used by the coach marks and by Thumby's lobby explainer.
  "Show tips" is controller-side today, so this is a new host-side flag.
- **Lobby events.** Player joined, look picked and game chosen are exposed as providers/events the
  Thumby director can listen to (`playerJoinedProvider` exists; look pick and game choice do not).
- **Sound.** Thumby gets its own voice channel/volume and music ducking later. M16 must **not grow
  `sound.dart`** (375 of 380 lines).

## Every host setup

- **TV host** (Sony BRAVIA, 1920×1080): all TV mockups are at the system's 1280×720 frame; live
  capture confirmed the host shell/join/picker/round/results flow.
- **Windows host** (`tv_test_app` desktop): same screens; needed for testing and automation. The
  pairing panel was not live-captured on Windows in this session (no device) — include it in the
  Windows device-check pass.
- **Phone "Play on this phone"** (controller hosts): the pad is the fixed-dp layout (30 identical boxes
  from 1133×744 to 1366×1024, `vf-matrix-tablets`), so a phone host is the phone form factor below.
- **A joined phone**: frames 0, 3, 4, 8, 9 are the joined-phone/controller surfaces.
- **A peer one build older**: not exercised live; protocol compatibility is covered by existing tests.
  Any additive field (item 1) must be capability-gated so an older peer still works (HANDOFF §3).

## Proposed screens' states

- **Join screen (frame 2)**: waiting (code visible + "Room for N more"), empty (0 players), dropped
  (away chip, frame 1), error (wrong code — to be added; today absent).
- **Controller pad (frames 0, 3, 8)**: waiting ("Connecting…"), connected (ping + state strip),
  dropped/host-away (card to be added — today absent), error (only on the connect screen today).
- **Round + results (frames 0, 7)**: in-round (clock/coins on phone), round-end (result card clears the
  HUD), scoreboard (reconciled coins→points, correct round number).
- **Identity (frames 4–5)**: empty nickname (0/10, not clipped), colour/accessory taken (nearest free),
  saved (preview updates).
- **End of night (frame 6)**: awards delivered, winner crowned, "Back to games".

## Rejected, and why

- **QR-code join** — nice (AirConsole/Jackbox) but a TV code already works on this couch setup and
  stays offline; QR is a later nicety.
- **Auto-start timer** — no studied game auto-starts; host/ready confirmation is the norm and it
  avoids a false start while people grab phones.
- **Whole-night cross-game summary** — no studied game has one; a per-night scoreboard + awards
  (item 6) delivers the same payoff for far less.
- **A full responsive (fluid) pad** — the fixed-dp pad is already a deliberate, tested layout; the
  real fix is the 48 dp targets and the SE-width truncation, not a redesign.
- **Moving the pairing code to the phone** — it already enters the code on the phone; the gap is the
  TV not *showing* it, which is a TV-side one-line fix.

## Colour + accessory: the path for more later

Approved now: the six default colours and six accessories (look-and-sound §5b). The path for adding
more is already designed as a data change, not a drawing change:

- **One value.** `ToyCharacter` (colour slot + `ToyAccessory`) is the single place a player's number
  becomes a character; `ToyCharacter.forPlayer(n)` supplies today's defaults. Painters draw a
  character, never a number.
- **A new accessory** = one entry in `ToyAccessory`, drawn in ink + paper only, so it works on any
  colour and both palettes. No painter changes.
- **A new colour** = one entry in the player palette, then re-run the existing contrast test
  (ink-on-fill ≥ 4.5:1, control parts ≥ 3:1).
- **Customisation (when built)**: the phone picks colour + accessory in Settings, saved with the
  nickname; the host sends each player's `ToyCharacter` to every phone through an additive,
  capability-gated protocol field (the same pattern as item 1 and M14's optional fields), so an
  older peer still works.

## Decisions (owner, Nov 18)

1. **Item 1 (round state on the phone) — approved** as a low-risk additive, capability-gated field.
2. **Colour + accessory — approved for now** (six colours + six accessories); more may come later per
   the path above.
3. **Windows host parity — needed** for testing and automation; include it in the device-check pass.
4. **The 11 earlier suggestions — superseded** by this evidence-driven fresh list ("stay
   evidence-driven").

## Mockups

`mockups/proposal-mockups.html` renders 16 frames (0–15: the 9-item proposal, then the app-start
design — see `APP-START.md`) in Sunny and Night at TV 1280×720 and phone 816×384. Rendered PNGs:
`mockups/proposal-00-sunny.png` … `proposal-15-night.png` (32 files).
