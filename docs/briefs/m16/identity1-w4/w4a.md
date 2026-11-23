job: M16 w4a split host_connection.dart (at the 380-line cap): the pairing handlers move to a part file
pub: no
turns: 35
expected-min: 15
tests-first: exempt pure refactor, behaviour and tests unchanged
stop: after the move. No behaviour change, no new feature, no rename of public names.
read: docs/briefs/templates/COMMON.md · packages/connection/lib/src/host_connection.dart:1-30,266-352 (imports, part line, _onHello/_onPair/_accept) · packages/connection/lib/src/host_connection_info.dart:1-8 (the existing part: how it reads the connection's private fields) · docs/coding-guidelines.md
changes: HostConnectionPairing
decisions: none needed; the owner wants the file split before Q2 adds to it.
do:
1 New file packages/connection/lib/src/host_connection_pairing.dart: `part of 'host_connection.dart';` and an `extension HostConnectionPairing on HostConnection` holding the three methods `_onHello`, `_onPair`, `_accept`, moved unchanged (doc comments kept; a short extension doc says it is the hello, pair request and the pairing's acceptance).
2 host_connection.dart: delete those three methods, add `part 'host_connection_pairing.dart';` beside the other part line. Calls to them from `_handle` must be written `this._onHello(message)` / `this._onPair(message)` (extension members are not found by an unqualified call inside the class; if the analyzer still complains, keep that form).
3 Both files stay under 380 lines; host_connection.dart should end near 290.
4 Report: the two line counts and a move map (method -> new line).
allow: packages/connection/lib/src/host_connection.dart · packages/connection/lib/src/host_connection_pairing.dart · docs/briefs/m16/identity1-w4/w4a-report.md
check: format analyze connection
report: docs/briefs/m16/identity1-w4/w4a-report.md
