import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/testing/fake_crash.dart';

/// The fake reporter a test trusts to stand in for Sentry: like the real one,
/// it sends nothing while reports are off (design sentry-consent.md), so a
/// test that sees no report cannot be hiding a missing enabled check
/// (M14 sentry1).
void main() {
  test('a report handed over while reports are off is dropped', () {
    final fake = FakeCrashReporter();

    fake.capture(StateError('off'), null, where: 'test');

    expect(fake.captures, isEmpty, reason: 'the real reporter sends nothing while off either');
    expect(fake.enabled, isFalse);
  });

  test('the same report is kept once reports are on', () async {
    final fake = FakeCrashReporter();
    await fake.enable();

    fake.capture(StateError('on'), null, where: 'test');

    expect(fake.captures, hasLength(1));
    expect(fake.captures.single.where, 'test');
    expect(fake.captures.single.error, isA<StateError>());
  });

  test('reports are dropped again after they are turned off', () async {
    final fake = FakeCrashReporter();
    await fake.enable();
    fake.capture(StateError('on'), null);

    await fake.disable();
    fake.capture(StateError('after'), null);

    expect(fake.captures, hasLength(1));
    expect(fake.enableCount, 1);
    expect(fake.disableCount, 1);
  });
}
