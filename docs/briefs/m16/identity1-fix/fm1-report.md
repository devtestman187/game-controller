# fm1 report: away player keeps its look, phones never get a local player's look, typed json map

## Summary

Done. Tests first: `packages/connection/test/identity_fix_test.dart` (3 tests) failed on the old code, 3 of 3:
- away row carried the default look: expected `PlayerCharacter(5, crown)`, got `(2, antenna)` (webSocket only);
- a phone that asked for the local player's look (`forPlayer(1)`) was given it: expected `(2, antenna)`, got `(1, ears)` (webSocket and inProcess).

Then the four fixes:
1. `away_slots.dart` `_hold`: the away `GamePlayer` keeps `character: player.character`.
2. `host_character_reservation.dart` `_reserveCharacter`: adds the character of every row of `playerSource?.call()` whose id is not this session's controllerId (the game's local and away players and other phones). The existing taken sources stay.
3. `character.dart` `_fromFields`: parameter typed `Map<String, Object?>`; `fromJson` casts with `json.cast<String, Object?>()`. Messages unchanged.
4. `identity.dart`: the two other callers of `_fromFields` (row `character` and the `chars` entries) cast the same way. The `SetCharacterMessage` caller already passed a typed map.

Computed expectations:
- `forPlayer(1)` = slot 1, ears (index 0).
- Local player (number 1) holds slot 1 ears; phone asks slot 1 ears; nearest free: colour 1 taken, nearest free 2; accessory ears taken, nearest free antenna (index 1). Expected `PlayerCharacter(2, antenna)`.
- Dropped phone (number 2) asks slot 5 crown; nothing else holds it, so it keeps `(5, crown)`; its away row must show that.

Checks: `tools/check.sh format analyze protocol connection`: format PASS, analyze PASS, protocol PASS (140 tests), connection PASS (360 tests, includes the 3 new ones). Ran the new file on the old code via `flutter test` from packages/connection, 3 failures as above.

## Self-check (docs/review-rules.md part A)

1. Host setups: TV or PC host with a game, webSocket and inProcess (test `a phone that asks for a local player's look ...` runs on both); away-row test webSocket only, as the slot is held for a socket phone (m12 N5). Phone on "Play on this phone" / "Show on this device" / joined phone / phone one build older: not changed by this job; the fix only changes which look a phone is given and the away row's look.
2. Kept state: the away look lives in the `_Slot` for the away slot's life. Ends with the slot (`goOnWithout` test: its row leaves the list). Nothing kept when no game is running: `playerSource` is null, so the taken list is unchanged.
3. Combinations: pause menu, host away, "Get ready", dropped link, results, leaving: not covered by a new test; the change only reads rows the game already lists. Not verified for these states.
4. Stayed in `allow:`: yes. Files changed: `away_slots.dart`, `host_character_reservation.dart`, `character.dart`, `identity.dart`, new `identity_fix_test.dart`, this report.
5. No stop needed.
6. Every look: no UI in this job; the look is data only. No look-sized widget touched.

## Decisions

- The new test file has its own `_newClientWith` (copy of `newClient` plus `character:`), since `newClient` in helpers.dart cannot set a hello character and `wire_phone.dart` has no close. `identity_rows_test.dart` untouched.
- The brief says "cast at the two callers"; there are three callers that pass a parsed map (`fromJson`, and the two in `identity.dart`), so all three cast. Behaviour unchanged.
- The `identity_rows_test.dart` and `identity_reserve_minute_test.dart` files in `allow:` were not needed; not edited.

## Questions

1. `Map.cast` is a lazy view: a non-string key now fails with a `TypeError` on read, not a `FormatException`. JSON keys are always strings, so no change in practice; say if the brief wants a stricter check.
2. The reservation doc comment's wrap is uneven after the edit (one short last line); a re-wrap is a docs nit, not done.

## Commit message — a draft

M16 identity1-fix fm1: keep away looks, skip local players' looks

An away player's row keeps the character it paired with while its slot is
held (away_slots.dart), instead of the number's default. A phone's reserved
look now also avoids the game's local and away players' looks, so a phone
that asks for a local player's look gets the nearest free one. The json
parser's map parameter is typed Map<String, Object?>; callers cast.
New identity_fix_test.dart pins both (fails on the old code).

## Status row

fm1 done: away look kept in `players`; phones never given a local/away player's look; `_fromFields` typed. Open: pause menu, host away, results and leaving combinations not checked by a test.

## Delete

- none
