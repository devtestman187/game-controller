import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/testing/fake_crash.dart';

import 'support/host_harness.dart';

/// The two consent prompts (design sentry-consent.md): asked one at a time,
/// crash reports first, and only where an answer can do something.
void main() {
  late FakeCrashReporter crash;

  setUp(() {
    crash = FakeCrashReporter();
    CrashReports.use(crash);
  });

  /// The providers under the harness's screen, for the answers it saved.
  ProviderContainer consentContainer(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byKey(const Key('ask'))));

  testWidgets('with no DSN in the build, the launch asks only about stats', (tester) async {
    final fake = await pumpHost(tester, screen: const _AskScreen());
    await tester.tap(find.byKey(const Key('ask')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('crashConsentDialog')), findsNothing, reason: 'no report can be sent from this build');
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('consentYes')));
    await tester.pumpAndSettle();
    final container = consentContainer(tester);
    expect(container.read(prefsProvider).getBool('statsConsent'), isTrue);
    expect(container.read(prefsProvider).getBool('crashConsent'), isNull);
    expect(fake.stats.consents, [true], reason: 'the running host\'s stats follow the answer');

    // Both questions are answered now (the crash one was never asked), so the
    // next launch asks nothing.
    await tester.tap(find.byKey(const Key('ask')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });

  testWidgets('with a DSN in the build, the crash question comes first and then the stats one', (tester) async {
    final fake = await pumpHost(
      tester,
      screen: const _AskScreen(),
      overrides: [crashAvailableProvider.overrideWithValue(true), crashReporterProvider.overrideWithValue(crash)],
    );
    await tester.tap(find.byKey(const Key('ask')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crashConsentDialog')), findsOneWidget);
    expect(find.byKey(const Key('consentDialog')), findsNothing, reason: 'one question at a time, crash reports first');

    await tester.tap(find.byKey(const Key('crashYes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('crashConsentDialog')), findsNothing);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget, reason: 'then the stats question');

    await tester.tap(find.byKey(const Key('consentNo')));
    await tester.pumpAndSettle();
    final container = consentContainer(tester);
    expect(container.read(consentProvider).crash, isTrue);
    expect(container.read(consentProvider).stats, isFalse);
    expect(container.read(prefsProvider).getBool('crashConsent'), isTrue);
    expect(container.read(prefsProvider).getBool('statsConsent'), isFalse);
    expect(crash.enabled, isTrue, reason: 'the yes turns reports on at once');
    expect(fake.stats.consents, [false]);
  });

  testWidgets('the first host\'s prompt takes a thumb and nothing else', (tester) async {
    await pumpHost(tester, screen: const _AskScreen(touchOnly: true));
    await tester.tap(find.byKey(const Key('ask')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consentDialog')), findsOneWidget, reason: 'no key reaches either button');
    expect(
      consentContainer(tester).read(prefsProvider).getBool('statsConsent'),
      isNull,
      reason: 'nothing was answered',
    );

    await tester.tap(find.byKey(const Key('consentNo')));
    await tester.pumpAndSettle();
    expect(consentContainer(tester).read(prefsProvider).getBool('statsConsent'), isFalse);
  });
}

/// A host screen with one button that opens this instance's consent questions,
/// as an app's first launch does.
class _AskScreen extends ConsumerWidget {
  const _AskScreen({this.touchOnly = false});

  /// Whether the prompts take a thumb only, as the phone's first host does.
  final bool touchOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: HostButton(
        key: const Key('ask'),
        label: 'Ask',
        onPressed: () async {
          await askConsents(context, ref, touchOnly: touchOnly);
        },
      ),
    ),
  );
}
