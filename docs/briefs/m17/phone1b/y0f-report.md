# y0f report: "Try the shop" demo on the Games screen

tests-first: exempt, new screen with no earlier behaviour; its test file is new.

## Files changed
- `packages/party_host/lib/src/ui/shop_demo_screen.dart` (new): `ShopDemoScreen` runs one `ChoiceRound` (20 s, grace 8 s,
  Build cost 3 max 3 "Bolts", Save +2 default, Roadworks for the last player number only) over the joined phones
  (not local, not simulated) with `OldPhoneChoices` on `server.messages`. It shows the title, a countdown, who locked in,
  then every choice at once with "(by default)" marked, and a Back button. Leaving closes and disposes the round.
  Without a `ServerGameHost`, or with no joined phone, it shows "Join with phones to try the shop" and runs no round.
- `packages/party_host/lib/src/ui/games_screen.dart`: opens the demo from the picker (`onShop`).
- `packages/party_host/lib/src/ui/games_screen_widgets.dart`: "Try the shop" button (`openShopDemo`) at the right end of
  the playtest line's row, not a card. The row is as tall as the TV look's 64 px button, so `gameCardHeightPx` 340 -> 308
  and `gamePictureHeightPx` 186 -> 154 (same 8 px spare in the card). Cards and their order are unchanged.
- `packages/party_host/lib/src/text/host_text.dart`: `HostText.tryShop` only (file is at 380 lines).
- `packages/party_host/lib/party_host.dart`: export of the screen.
- `packages/party_host/test/shop_demo_test.dart` (new): 5 tests x 2 looks (menu, TV) at 1920x1080 plus the no-host line.
- `packages/party_host/test/touch_targets_host_test.dart`: 6 entries for `openShopDemo` in `knownBelow48Host`
  (below 48 dp on the three phone sizes like the other footer buttons).

## Computed values
- Button at TV size, both looks, is checked at >= 48 dp on both sides.
- Rows: Ann locks Build x2 -> "Ann: Build 2 = 6 Bolts" (2 x 3); Bea unpicked -> "Bea: Save +2 (by default)".
- First `endsInMs` is read off the host's real stopwatch, so it reads 19999 not 20000: the test allows full-1000..full.
- Touch targets (dp): 568x320 menu 122.9x28.4, tv 122.9x37.9; 640x360 menu 138.5x32.0, tv 138.5x42.7;
  375x667 menu 81.2x18.8, tv 81.2x25.0.

## Self-check
1. Host setups: real `ServerGameHost` with two capable phones, tested; fake host (no round line), tested. Old phones:
   `OldPhoneChoices` is started, but not covered by a party_host test (connection tests cover it).
2. State starts in `initState` and ends in `dispose`; nothing chosen = Save +2 by default, tested.
3. Pause menu, host away, dropped link: not covered here; the round's own grace handles a dropped phone.
4. Only allowed files changed.
6. Menu and TV look both tested; the button has no fixed pixel height.

## Questions / deviations
1. The brief says `HostText.shopDemo*`; `host_text.dart` is at 379 lines (limit 380), so only `tryShop` went there. The
   other words are in a private `_ShopText` in the screen file. Moving them into HostText needs that file split.
2. The picker's cards are 32 px shorter to make room for the button; the frame tests stay green.
3. The countdown counts its own 1 s ticks (fake-clock safe), not the host clock.

## Commit message
m17 phone1b y0f: "Try the shop" demo on the Games screen

ShopDemoScreen runs one ChoiceRound over the joined phones (Build, Save +2,
Roadworks for the last number), old phones through OldPhoneChoices, and
shows every choice at the end. A small "Try the shop" button sits beside
the playtest line; the three cards keep their order, 32 px shorter.

## Status row
y0f: "Try the shop" demo on the host Games screen done (tests menu+TV); open: old-phone path and pause/away not tested in party_host, shop words not in HostText.

## Delete
- none
