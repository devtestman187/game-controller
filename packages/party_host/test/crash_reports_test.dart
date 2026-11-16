import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/testing/fake_crash.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A DSN as a build would pass it: made up, so no project's address is kept in
/// the repo (design sentry-consent.md).
const _dsn = 'https://example-public-key@example.invalid/1';
const _release = '1.0.0+1';
const _environment = 'test';

void main() {
  late FakeCrashReporter fake;

  setUp(() {
    fake = FakeCrashReporter();
    CrashReports.use(fake);
  });

  Future<FakeCrashReporter> startCrash({bool? consent, String dsn = _dsn}) async {
    SharedPreferences.setMockInitialValues({'crashConsent': ?consent});
    final prefs = await SharedPreferences.getInstance();
    final reporter = FakeCrashReporter();
    await startCrashReporting(prefs: prefs, dsn: dsn, release: _release, environment: _environment, reporter: reporter);
    return reporter;
  }

  group('capture', () {
    test('sends nothing while reports are off', () {
      CrashReports.capture(StateError('boom'), StackTrace.current, where: 'test');
      expect(fake.captures, isEmpty);
    });

    test('sends the error, its stack and where it came from while reports are on', () async {
      await fake.enable();
      final error = StateError('boom');
      final stack = StackTrace.current;
      CrashReports.capture(error, stack, where: 'test');
      expect(fake.captures, hasLength(1));
      expect(fake.captures.single.error, same(error));
      expect(fake.captures.single.stack, same(stack));
      expect(fake.captures.single.where, 'test');
    });

    test('does not throw when the reporter itself fails', () {
      CrashReports.use(_FailingReporter());
      expect(() => CrashReports.capture(StateError('boom'), null), returnsNormally);
    });

    test('stops sending when reports are turned off again', () async {
      await fake.enable();
      CrashReports.capture(StateError('before'), null);
      await fake.disable();
      CrashReports.capture(StateError('after'), null);
      expect(fake.captures, hasLength(1));
      expect(fake.captures.single.error, isA<StateError>());
      expect(fake.disableCount, 1);
    });
  });

  group('guard', () {
    test('reports a future that fails once and does not fail itself', () async {
      await fake.enable();
      final error = StateError('upload failed');
      await CrashReports.guard(Future<void>.error(error), where: 'upload');
      expect(fake.captures, hasLength(1));
      expect(fake.captures.single.error, same(error));
      expect(fake.captures.single.where, 'upload');
    });

    test('sends nothing while reports are off and still does not fail', () async {
      await CrashReports.guard(Future<void>.error(StateError('boom')), where: 'upload');
      expect(fake.captures, isEmpty);
    });

    test('sends nothing for a future that completes', () async {
      await fake.enable();
      await CrashReports.guard(Future<void>.value(), where: 'upload');
      expect(fake.captures, isEmpty);
    });
  });

  group('startCrashReporting', () {
    test('turns reports on when this instance said yes and the build has a DSN', () async {
      final reporter = await startCrash(consent: true);
      expect(reporter.enabled, isTrue);
      expect(reporter.enableCount, 1);
    });

    test('leaves reports off when this instance said no', () async {
      final reporter = await startCrash(consent: false);
      expect(reporter.enabled, isFalse);
      expect(reporter.enableCount, 0);
    });

    test('leaves reports off when nobody answered yet', () async {
      final reporter = await startCrash();
      expect(reporter.enabled, isFalse);
      expect(reporter.enableCount, 0);
    });

    test('leaves reports off when the build has no DSN, even after a yes', () async {
      final reporter = await startCrash(consent: true, dsn: '');
      expect(reporter.enabled, isFalse);
      expect(reporter.enableCount, 0);
    });

    test('reports through the reporter it was given once reports are on', () async {
      final reporter = await startCrash(consent: true);
      CrashReports.capture(StateError('boom'), StackTrace.current, where: 'test');
      expect(reporter.captures, hasLength(1));
      expect(fake.captures, isEmpty, reason: 'the started reporter replaced the one from setUp');
    });
  });

  group('error handlers', () {
    late FlutterExceptionHandler? savedFlutterError;
    late ErrorCallback? savedPlatformError;

    setUp(() {
      savedFlutterError = FlutterError.onError;
      savedPlatformError = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = savedFlutterError;
      PlatformDispatcher.instance.onError = savedPlatformError;
    });

    test('the Flutter handler reports the error and still calls the one before it', () async {
      final forwarded = <FlutterErrorDetails>[];
      FlutterError.onError = (details) => forwarded.add(details);
      final reporter = await startCrash(consent: true);
      final details = FlutterErrorDetails(exception: StateError('boom'));
      FlutterError.onError!(details);
      expect(reporter.captures, hasLength(1));
      expect(reporter.captures.single.error, same(details.exception));
      expect(reporter.captures.single.where, 'flutterError');
      expect(forwarded, [details]);
    });

    test('the platform handler reports the error and returns what the one before it returned', () async {
      PlatformDispatcher.instance.onError = (error, stack) => true;
      final reporter = await startCrash(consent: true);
      final error = StateError('boom');
      expect(PlatformDispatcher.instance.onError!(error, StackTrace.current), isTrue);
      expect(reporter.captures, hasLength(1));
      expect(reporter.captures.single.error, same(error));
      expect(reporter.captures.single.where, 'platformError');
    });

    test('the platform handler returns false when nothing handled the error before', () async {
      PlatformDispatcher.instance.onError = null;
      await startCrash(consent: true);
      expect(PlatformDispatcher.instance.onError!(StateError('boom'), StackTrace.current), isFalse);
    });
  });
}

/// A reporter whose report always fails, to show that reporting never reaches
/// the caller.
class _FailingReporter implements CrashReporter {
  @override
  bool get enabled => true;

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}

  @override
  void capture(Object error, StackTrace? stack, {String? where}) => throw StateError('no report');
}
