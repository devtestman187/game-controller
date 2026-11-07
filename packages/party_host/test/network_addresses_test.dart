import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

void main() {
  // A hosting iPhone showed its carrier address instead of its Wi-Fi one
  // (bug 1107b): `en0` and `pdp_ip0` were both unranked, so the OS's order
  // won. These cases pin the rule by interface name.

  test('an iPhone lists only its Wi-Fi address, not the cellular one', () {
    // getifaddrs handed `pdp_ip0` over first on the owner's iPhone (bug 1107b).
    final ordered = orderedAddresses(const [
      LocalAddress('10.12.7.4', 'pdp_ip0'),
      LocalAddress('192.168.50.193', 'en0'),
    ]);
    expect(ordered, const [LocalAddress('192.168.50.193', 'en0')]);
  });

  test('a Windows PC keeps Wi-Fi, then Ethernet, then the virtual adapter', () {
    final ordered = orderedAddresses(const [
      LocalAddress('192.168.1.90', 'vEthernet (WSL)'),
      LocalAddress('10.0.0.9', 'Ethernet'),
      LocalAddress('192.168.1.50', 'Wi-Fi'),
    ]);
    expect(ordered, const [
      LocalAddress('192.168.1.50', 'Wi-Fi'),
      LocalAddress('10.0.0.9', 'Ethernet'),
      LocalAddress('192.168.1.90', 'vEthernet (WSL)'),
    ]);
  });

  test('an Android phone lists only its Wi-Fi address, not the cellular one', () {
    final ordered = orderedAddresses(const [
      LocalAddress('10.1.2.3', 'rmnet_data0'),
      LocalAddress('192.168.1.50', 'wlan0'),
    ]);
    expect(ordered, const [LocalAddress('192.168.1.50', 'wlan0')]);
  });

  test('the iPhone en0 comes before another en interface the OS listed first', () {
    // The case behind the bug: a second interface had 192.168.0.2 and `en0`
    // 192.168.50.193, and whichever the OS listed first won (bug 1107b).
    final ordered = orderedAddresses(const [LocalAddress('192.168.0.2', 'en2'), LocalAddress('192.168.50.193', 'en0')]);
    expect(ordered, const [LocalAddress('192.168.50.193', 'en0'), LocalAddress('192.168.0.2', 'en2')]);
  });

  test('two interfaces of one rank keep the order the OS gave them', () {
    final ordered = orderedAddresses(const [
      LocalAddress('192.168.1.70', 'en3'),
      LocalAddress('192.168.1.50', 'wlan0'),
      LocalAddress('192.168.1.60', 'en1'),
    ]);
    expect(ordered, const [
      LocalAddress('192.168.1.50', 'wlan0'),
      LocalAddress('192.168.1.70', 'en3'),
      LocalAddress('192.168.1.60', 'en1'),
    ]);
  });

  test("the owner's iPhone: Wi-Fi first, the Wi-Fi Calling tunnels after, cellular dropped", () {
    // The host log from the owner's device test (Nov 7, 2026).
    final ordered = orderedAddresses(const [
      LocalAddress('10.155.68.78', 'pdp_ip0'),
      LocalAddress('192.0.0.6', 'ipsec0'),
      LocalAddress('192.168.50.193', 'en0'),
      LocalAddress('192.0.0.6', 'ipsec6'),
    ]);
    expect(ordered.first, const LocalAddress('192.168.50.193', 'en0'));
    expect(ordered.map((a) => a.interfaceName), ['en0', 'ipsec0', 'ipsec6']);
  });

  test("a Windows laptop's mobile broadband adapter is dropped", () {
    final ordered = orderedAddresses(const [
      LocalAddress('10.40.1.2', 'Cellular'),
      LocalAddress('192.168.1.50', 'Wi-Fi'),
    ]);
    expect(ordered, const [LocalAddress('192.168.1.50', 'Wi-Fi')]);
  });
}
