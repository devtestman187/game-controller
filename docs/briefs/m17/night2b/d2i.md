job: night2b d2i — pool honesty: the setup offers only what a night can play, nothing that does not exist
stop: pure Dart, no UI, no change to the director, pickers or settings fields; no Rotating or Vote offered (owner questions open); no 8-round option
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/night_settings.dart:19-23,26-100 (NightPicker, NightSettings, kids, copyWith) · packages/party_host/lib/src/night/variant.dart (whole) · packages/party_host/lib/src/night/night_pick.dart (nightPlayableGames, mapTierLevel from d2w) · packages/party_host/lib/src/night/night_state.dart:1-30 (NightLength: three and five only) · plan d2i: "Pool honesty: show only variants that exist; no 8-round option; Kids preset narrows the range"
changes: NightSetupOptions · offeredGames · offeredPickers · offeredLengths · togglePoolGame · withDifficulty · gamesOn
model: haiku
turns: 45
expected-min: 20
tests-first: exempt new type: the test cannot compile on the base
do:
1 NEW packages/party_host/lib/src/night/night_setup_options.dart (one public class `NightSetupOptions` with static members; under 150 lines), pure: `offeredGames` = the VariantGame values in nightPlayableGames, in enum order; `offeredPickers` = [host, director, shuffle, playlist]; `offeredLengths` = NightLength.values (never above five rounds).
2 `Set<VariantGame> gamesOn(NightSettings)`: the games the pool allows (empty pool = every offered game; a pool entry is a game name or a variant id, as variantPool reads it). `NightSettings togglePoolGame(NightSettings, VariantGame game, Level Function(String) mapTierLevel)`: flips one offered game; the result must keep a pool the range can still play (at least one variant in `variantPool` of the playable launch variants), otherwise the settings come back unchanged; when every offered game is on, the pool is stored empty. `NightSettings withDifficulty(NightSettings, {Level? min, Level? max}, Level Function(String) mapTierLevel)`: min never above max (the other end moves with it), and a range with no playable variant in the pool is refused (settings unchanged).
3 Tests: NEW packages/party_host/test/night_setup_options_test.dart: arenaRace, rotating and vote are never offered; lengths are 3 and 5 rounds only; the default settings and `NightSettings.kids` both leave at least one playable variant (Kids: Shape Race easy and Pinball); toggling Shape Race off leaves the Bumper Round, toggling the last game off is refused; both on stores an empty pool; setting max below min moves min; a range with no playable variant is refused (pool {'bumperRound'} with mapTierLevel stubs rating every map hard refuses max easy); an edited Kids night (isKids false) is not capped by this file.
4 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/night/night_setup_options.dart · packages/party_host/test/night_setup_options_test.dart
check: format analyze
report: docs/briefs/m17/night2b/d2i-report.md
