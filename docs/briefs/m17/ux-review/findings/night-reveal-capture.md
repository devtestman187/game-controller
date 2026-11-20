# M17 — live capture: the end-of-night flow (tablet as phone host)

Status: findings (Flash worker, Nov 19). Pixel Tablet `adb-3817105H80BRQP-cAkbcX._adb-tls-connect._tcp`,
app `com.thumbparty.app`, raster 2560x1600 @ 320 (dp = px/2). Full write-up + PNGs:
`C:\Users\mrman\Documents\deepseek-harness\default-workspace\capture-reveal\`.

## Key result

The **award reveal does render live** — `End night` on the round-1 results card goes straight to the
three awards, then the final scoreboard. (M16's "awards never shown" finding was "never reached",
not broken.)

## Measured surfaces (for the host-character mockups)

- **Round-result card** (`reveal-05`): x[912..1647] y[546..1053] = 368x254 dp, horizontally centred
  (456 dp free each side). Header **"Robo wins!"** navy `#1E1646` on orange `#FF8A1F`, bar h 41 dp.
  Body: "P1 Phone 1719 0 coins", "Robo 7 coins"; buttons Next / End night. Background = still-drawn
  Arena field, not blank.
- **Award reveal** (3 cards, `reveal-06/07/08`): card horizontally centred, header h 41 dp, icon disc
  100 dp. Widths auto-size to the reason line: Best Helper 448 dp (blue `#2E9BF0`), Comeback 460 dp
  (orange `#FF8A1F`), Bounce House 359 dp (purple `#A66CFF`). Empty bands for a host character:
  left ~380x650 dp, right ~410x735 dp, below ~1280x230 dp.
- **Final scoreboard** (`reveal-09`): card x[822..1737] y[272..834] = 458x281 dp, green header
  `#14C8A0`, crown on "1 Robo ★12 +12", "Back to games". Animated confetti behind; clean band
  below the card ~1280x380 dp.
- **Timing**: ~1.6 s per award (all were the 2 s "missed" path), final scores at ~8 s.

## Gaps / unmeasured

- **Won-award layout not captured** — all three awards rendered "Not won tonight" (P1 scored 0;
  Robo's 7 coins won no award). Winner row + reason + "+3" mocked from `night_reveal_widgets.dart`.
- Night scoreboard "Round N of 3" skipped (End night bypasses it) — placement taken from M16
  `vf-2dev-round` Record 6.
- Cold launch boots to the pad, not the 3-role Home (M16 item 7 not built yet).

## Navigation (differs from the working model)

Pad → "tap to connect" pill → Connect to a TV → **Host a game** → sheet → **Play on this phone** →
game picker → Party night → 3 rounds → "Pick round 1" → Bumper Round → Arena waiting card → Ready.
