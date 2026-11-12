import 'package:party_host/party_host.dart' as party;

/// Whether this build carries the automation interface, from
/// `--dart-define=AUTOMATION=true` (M15 a2): a phone has no environment of
/// its own, so its build's define is the whole switch. Off unless a build
/// passes it, and a store build never does.
const bool automationDefined = bool.fromEnvironment('AUTOMATION');

/// This phone's automation settings: the build's define, and nothing else.
/// [defined] is how a test says what the build was told.
party.AutomationSettings phoneAutomationSettings({bool defined = automationDefined}) =>
    party.AutomationSettings.fromSources(env: (_) => null, buildEnabled: defined);
