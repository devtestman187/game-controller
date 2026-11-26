import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_state.dart';

void main() {
  test('every night length plays between 1 and nightRoundCap rounds', () {
    for (final length in NightLength.values) {
      expect(length.rounds, greaterThanOrEqualTo(1), reason: '$length');
      expect(length.rounds, lessThanOrEqualTo(nightRoundCap), reason: '$length');
    }
  });

  test('the shipped night lengths are exactly 3 and 5 rounds', () {
    expect(NightLength.values.map((length) => length.rounds).toList(), [3, 5]);
  });

  test('no night length has 8 rounds, which stays unavailable until the variant count allows it', () {
    expect(NightLength.values.any((length) => length.rounds == 8), isFalse);
  });

  test('a night of 5 rounds starts at setup, round 0, with 5 rounds', () {
    final flow = NightFlow.start(5);
    expect(flow.stage, NightStage.setup);
    expect(flow.round, 0);
    expect(flow.rounds, 5);
  });

  test('starting a night of 8 rounds fails the round cap assert', () {
    expect(() => NightFlow.start(8), throwsA(isA<AssertionError>()));
  });
}
