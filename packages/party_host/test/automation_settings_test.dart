import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// The settings a launch with [values] in its environment asks for (M15 a2).
AutomationSettings fromEnv(Map<String, String> values) => AutomationSettings.fromSources(env: (name) => values[name]);

void main() {
  test('off unless a launch says so, on this machine only', () {
    const settings = AutomationSettings();
    expect(settings.enabled, isFalse, reason: 'a store build and an ordinary launch get this');
    expect(settings.bindAddress, '127.0.0.1', reason: 'nothing on the network can reach it');
    expect(settings.isLoopback, isTrue);
    expect(settings.port, 8787);
    expect(settings.token, isEmpty);
    expect(settings.problem, isNull);
    expect(settings.statsConsent, isNull, reason: 'nobody answered the stats question');
    expect(fromEnv({}).enabled, isFalse, reason: 'an empty environment is an ordinary launch');
  });

  test('THUMBPARTY_AUTOMATION=1 switches it on, and nothing else does', () {
    expect(fromEnv({AutomationSettings.envEnabled: '1'}).enabled, isTrue);
    expect(
      fromEnv({AutomationSettings.envEnabled: ' 1 '}).enabled,
      isTrue,
      reason: 'a shell pads nothing, but a hand may',
    );
    for (final value in ['', '0', 'yes', 'true', 'on']) {
      expect(fromEnv({AutomationSettings.envEnabled: value}).enabled, isFalse, reason: '"$value" is not the one value');
    }
    expect(
      AutomationSettings.fromSources(env: (_) => null, buildEnabled: true).enabled,
      isTrue,
      reason: 'AUTOMATION define',
    );
  });

  test('a bind beyond this machine needs a token, and the request carries it', () {
    final open = fromEnv({AutomationSettings.envEnabled: '1', AutomationSettings.envBind: '0.0.0.0'});
    expect(open.isLoopback, isFalse);
    expect(open.problem, contains(AutomationSettings.envToken), reason: 'the refusal names the variable to set');

    final guarded = fromEnv({
      AutomationSettings.envEnabled: '1',
      AutomationSettings.envBind: '0.0.0.0',
      AutomationSettings.envToken: 'sekrit',
    });
    expect(guarded.problem, isNull);
    expect(guarded.authorized(null), isFalse, reason: 'every request carries the token');
    expect(guarded.authorized('wrong'), isFalse);
    expect(guarded.authorized('sekrit'), isTrue);
    expect(guarded.describe()['token'], 'set', reason: 'the settings read back never carry the token itself');
  });

  test('a token set on loopback is asked for too', () {
    final settings = fromEnv({AutomationSettings.envEnabled: '1', AutomationSettings.envToken: 'sekrit'});
    expect(settings.isLoopback, isTrue);
    expect(settings.problem, isNull);
    expect(settings.authorized(null), isFalse);
    expect(settings.authorized('sekrit'), isTrue);
    expect(fromEnv({AutomationSettings.envEnabled: '1'}).authorized(null), isTrue, reason: 'no token, no header');
  });

  test('ports: automation listens where it is told, the controller is pinned', () {
    final settings = fromEnv({
      AutomationSettings.envEnabled: '1',
      AutomationSettings.envPort: '9000',
      AutomationSettings.envControllerPort: '45780',
    });
    expect(settings.port, 9000);
    expect(settings.controllerPort, 45780);
    for (final raw in ['', 'abc', '-1', '70000']) {
      final bad = fromEnv({AutomationSettings.envPort: raw});
      expect(bad.port, AutomationSettings.defaultPort, reason: '"$raw" is not a port, so the usual one is');
      expect(bad.controllerPort, isNull, reason: '"$raw" pins no controller port');
    }
    expect(fromEnv({AutomationSettings.envPort: '0'}).port, 0, reason: '0 asks the system, as a test does');
  });

  test('the stats question is only ever answered no by a launch', () {
    expect(fromEnv({AutomationSettings.envStatsConsent: 'no'}).statsConsent, isFalse);
    expect(fromEnv({AutomationSettings.envStatsConsent: 'NO'}).statsConsent, isFalse);
    for (final value in ['', 'yes', 'true', '1']) {
      expect(
        fromEnv({AutomationSettings.envStatsConsent: value}).statsConsent,
        isNull,
        reason: '"$value" answers nothing',
      );
    }
    expect(const AutomationSettings().statsConsent, isNull, reason: 'sharing is an adult\'s choice');
  });
}
