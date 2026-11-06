import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart' show feedsOf;

void main() {
  ControllerInfo c(String id, int? player, {InputStateMessage? input, String name = 'Phone'}) => ControllerInfo(
    controllerId: id,
    name: '$name $id',
    platform: 'ios',
    appVersion: '0.6.0',
    remoteAddress: '192.168.1.2$player',
    state: player == null ? ControllerState.disconnected : ControllerState.connected,
    since: DateTime(2026),
    rttMs: 10,
    player: player,
    input: input,
  );
  HostViewState s(List<ControllerInfo> list) => HostViewState(
    hostName: 'TV',
    host: HostSnapshot(running: true, port: 45780, pairingCode: '1234', controllers: list),
  );

  test('players are the connected controllers in player order, each with its colour', () {
    final fake = FakeHostService(s([c('b', 2), c('gone', null), c('a', 1)]));
    final feeds = feedsOf(fake.gameHost);
    expect(feeds.map((f) => (f.id, f.number)), [('a', 1), ('b', 2)]);
    expect(feeds.map((f) => f.color), [Color(playerColors[0]), Color(playerColors[1])]);
  });
}
