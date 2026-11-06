import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('pairings are saved and loaded; broken data is ignored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(loadPairings(prefs), isEmpty);
    savePairings(prefs, const [
      SavedPairing(controllerId: 'p1', token: 'tok', name: 'iPhone 3F1C', platform: 'ios', appVersion: '0.6.0'),
    ]);
    expect(loadPairings(prefs).single.token, 'tok');
    await prefs.setString('pairings', '[{"id": "x"}, 5, {"id": "p2", "token": "t2"}]');
    expect(loadPairings(prefs).map((p) => p.controllerId), ['p2']);
    await prefs.setString('pairings', 'not json');
    expect(loadPairings(prefs), isEmpty);
  });
}
