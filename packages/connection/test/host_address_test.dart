import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('HostAddress.parse', () {
    test('IPv4 without a port uses the default port', () {
      final a = HostAddress.parse(' 192.168.1.50 ');
      expect(a.addresses, ['192.168.1.50']);
      expect(a.port, defaultPort);
    });

    test('IPv4 with a port', () {
      expect(HostAddress.parse('192.168.1.50:5000').port, 5000);
    });

    test('bracketed IPv6 with a port, and bare IPv6', () {
      final a = HostAddress.parse('[fe80::1]:5000');
      expect(a.addresses, ['fe80::1']);
      expect(a.port, 5000);
      expect(HostAddress.parse('fe80::1').addresses, ['fe80::1']);
    });

    test('accepts a pasted ws:// or http:// address', () {
      expect(HostAddress.parse('ws://10.0.0.2:45780/').addresses, ['10.0.0.2']);
      expect(HostAddress.parse('http://10.0.0.2').addresses, ['10.0.0.2']);
    });

    test('hostname', () => expect(HostAddress.parse('tv.local').addresses, ['tv.local']));

    for (final bad in ['', '  ', '10.0.0.2:', '10.0.0.2:99999', '10.0.0.2:abc', '[fe80::1', '10.0 .0.2', ':5000']) {
      test('rejects "$bad"', () => expect(() => HostAddress.parse(bad), throwsFormatException));
    }
  });

  test('tries IPv4 first, then other addresses, then link-local IPv6', () {
    final a = HostAddress(addresses: ['fe80::1', 'tv.local', '2001:db8::5', '192.168.1.50'], port: 1);
    expect(a.ordered, ['192.168.1.50', 'tv.local', '2001:db8::5', 'fe80::1']);
  });

  test('builds WebSocket URIs, with brackets for IPv6', () {
    final a = HostAddress(addresses: ['::1'], port: 45780);
    expect(a.uriFor('::1').toString(), 'ws://[::1]:45780/ws');
    expect(a.display, '[::1]:45780');
  });

  test('round-trips through JSON', () {
    final a = HostAddress(addresses: ['10.0.0.2', 'fe80::1'], port: 45780, hostId: 'h', name: 'TV');
    expect(HostAddress.fromJson(a.toJson()), a);
  });

  test('shows IPv4-mapped addresses as IPv4', () {
    expect(displayIp('::ffff:192.168.1.5'), '192.168.1.5');
    expect(displayIp('fe80::1'), 'fe80::1');
  });

  group('HostAddress.local', () {
    final local = HostAddress.local(hostId: 'host-1', name: 'Thumb Party TV');

    test('shows the host name: it has no address and no port', () {
      expect(local.isLocal, isTrue);
      expect(local.addresses, isEmpty);
      expect(local.port, 0);
      expect(local.display, 'Thumb Party TV');
      expect(local.label, 'Thumb Party TV');
    });

    test('writes isLocal to JSON and reads it back', () {
      expect(local.toJson()['isLocal'], isTrue);
      final back = HostAddress.fromJson(local.toJson());
      expect(back, local);
      expect(back.isLocal, isTrue);
      expect(back.display, 'Thumb Party TV');
    });

    test('reads JSON without isLocal as a network address, as before', () {
      final json = HostAddress(addresses: ['10.0.0.2'], port: defaultPort).toJson();
      expect(json.containsKey('isLocal'), isFalse);
      final address = HostAddress.fromJson(json);
      expect(address.isLocal, isFalse);
      expect(address.display, '10.0.0.2:45780');
      expect(address.ordered, ['10.0.0.2']);
    });

    test('is not the same as a network address of the same host', () {
      final network = HostAddress(addresses: ['10.0.0.5'], port: defaultPort, hostId: 'host-1', name: 'Thumb Party TV');
      expect(local, isNot(network));
    });

    test('is rejected by the web socket connector', () async {
      await expectLater(WebSocketConnector().open(local, isCancelled: () => false), throwsA(isA<ConnectFailed>()));
    });
  });

  test('the log buffer keeps only the newest lines', () {
    final log = LogBuffer(capacity: 3);
    final sink = log.sink('test');
    for (var i = 1; i <= 5; i++) {
      sink('line $i');
    }
    expect(log.lines.map((l) => l.message), ['line 3', 'line 4', 'line 5']);
    expect(log.export(), contains('[test] line 5'));
  });
}
