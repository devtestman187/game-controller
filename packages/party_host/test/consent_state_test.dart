import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This app instance's two consent answers (design sentry-consent.md): the
/// answers it reads at startup, the one given before M14 carrying over, and
/// what each answer does as soon as it is given.
void main() {
  late FakeCrashReporter crash;

  setUp(() {
    crash = FakeCrashReporter();
    CrashReports.use(crash);
  });

  /// A container over [saved], with [host] as the running host service when it
  /// is given and no host service at all when it is not (reading that provider
  /// would throw, as it does in an app that has not made one).
  Future<ProviderContainer> consentContainer({Map<String, Object> saved = const {}, FakeHostService? host}) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        crashReporterProvider.overrideWithValue(crash),
        if (host != null) hostServiceProvider.overrideWithValue(host),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('an instance that was never asked holds no answers', () async {
    final container = await consentContainer();
    final consent = container.read(consentProvider);
    expect(consent.crash, isNull);
    expect(consent.stats, isNull);
  });

  test('the stats answer given before M14 carries over to this instance', () async {
    final container = await consentContainer(saved: {'statsConsent': true, 'crashConsent': false});
    final consent = container.read(consentProvider);
    expect(consent.stats, isTrue, reason: 'the old statsConsent key is this instance\'s stats answer');
    expect(consent.crash, isFalse);
  });

  test('setStats saves the answer and tells the running host\'s stats', () async {
    final host = FakeHostService(sampleState(), consent: null);
    final container = await consentContainer(host: host);
    // The app's host route has already made the host service, so it is there
    // to be told (an override is made when it is first read).
    expect(container.read(hostServiceProvider), same(host));
    await container.read(consentProvider.notifier).setStats(false);

    expect(container.read(consentProvider).stats, isFalse);
    expect(container.read(prefsProvider).getBool('statsConsent'), isFalse);
    expect(host.stats.consents, [false], reason: 'the running host follows the answer at once');
  });

  test('setStats saves the answer when no host service is running, and reaches nothing', () async {
    final container = await consentContainer();
    await container.read(consentProvider.notifier).setStats(true);

    expect(container.read(consentProvider).stats, isTrue);
    expect(
      container.read(prefsProvider).getBool('statsConsent'),
      isTrue,
      reason: 'reading the host service that is not there would throw',
    );
  });

  test('setCrash saves the answer and turns reports on and off at once', () async {
    final container = await consentContainer();
    final consent = container.read(consentProvider.notifier);

    await consent.setCrash(true);
    expect(container.read(prefsProvider).getBool('crashConsent'), isTrue);
    expect(crash.enableCount, 1);
    expect(crash.enabled, isTrue);
    CrashReports.capture(StateError('on'), null, where: 'test');
    expect(crash.captures, hasLength(1));

    await consent.setCrash(false);
    expect(container.read(prefsProvider).getBool('crashConsent'), isFalse);
    expect(crash.disableCount, 1);
    expect(crash.enabled, isFalse);
    CrashReports.capture(StateError('off'), null, where: 'test');
    expect(crash.captures, hasLength(1), reason: 'reports stay off while the answer is no');
  });

  test('crash reports are not available until an app\'s build says it can send them', () async {
    final container = await consentContainer();
    expect(container.read(crashAvailableProvider), isFalse);
  });
}
