job: night2a d2e — the pickers Shuffle, Playlist and Rotating chooser
stop: pure Dart, no provider, no UI, no new NightPicker value, no wiring, no Vote (B8); no change to Variant or NightSettings
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/night/variant.dart (Variant: from d2c) · packages/party_host/lib/src/night/night_settings.dart:19-23 (NightPicker) · plan, quoted (M17-proposals 1.2): "Shuffle: Random, no repeats. Playlist: Host sets the order. Rotating chooser: A different player picks each round."
changes: ShufflePicker · PlaylistPicker · RotatingChooser
probe: docs/briefs/m17/night2a/probe-d2e.patch
model: haiku
turns: 45
expected-min: 20
tests-first: exempt a new type: the test cannot compile on the base
do:
1 NEW packages/party_host/lib/src/night/night_pickers.dart (under 150 lines). `final class ShufflePicker` const: `Variant? next({required List<Variant> pool, required List<Variant> played, required Random random})`: a random pool variant not yet in `played`; when every one was played, a random one that is not `played.last` (when the pool has only that one, it); empty pool gives null. `final class PlaylistPicker` const with `final List<Variant> order`: `Variant? next(int round)` is `order[round % order.length]` (the playlist repeats if the night is longer), null when the order is empty; round counts from 0. `final class RotatingChooser` const: `String? next({required List<String> playerIds, String? lastChooser})` is the id after `lastChooser` in `playerIds` (wrapping round), the first id when lastChooser is null or no longer in the list, null when the list is empty (a player who left is skipped by the list not containing them; with one player it is that player).
2 Tests: NEW packages/party_host/test/night_pickers_test.dart, written and run first (import src files; `Random(7)`; hand-made Variants): shuffle never repeats within a pool until all are played (draw 10 in a row feeding `played`), then never the same twice in a row, one-variant pool returns it, empty gives null, same seed same result; playlist follows the host's order, repeats after the end, empty gives null; rotating: p1 then p2 then p3 then p1, a leaver skipped, an unknown lastChooser gives the first, one player gives that player, empty gives null.
3 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/party_host/lib/src/night/night_pickers.dart · packages/party_host/test/night_pickers_test.dart
check: format analyze
report: docs/briefs/m17/night2a/d2e-report.md
