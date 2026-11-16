import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show consentProvider;

/// "Share control stats with the TV" in Settings (PRD v2 privacy rules): this
/// phone's answer to the usage stats question (design sentry-consent.md). It is
/// read only and off until the adult answers, because [consentProvider] holds
/// the answer: the Settings switch and the prompt record it there, which also
/// tells the stats of a host this phone runs.
final shareStatsProvider = Provider<bool>((ref) => ref.watch(consentProvider).stats == true);

/// Whether this launch of the app puts its two consent questions to the adult
/// on the connect screen's first frame (design sentry-consent.md). The app's
/// `main()` turns it on: what asks is a launch of the app, so a test that
/// mounts `ControllerApp` itself starts past the questions, with the answers
/// its mock preferences hold, as a launch that asked already would leave them.
final launchConsentAskProvider = Provider<bool>((ref) => false);

/// Whether this launch has put its questions already (design sentry-consent.md):
/// the connect screen opens again and again, and a launch asks once.
final launchConsentAskedProvider = NotifierProvider<LaunchConsentAskedNotifier, bool>(LaunchConsentAskedNotifier.new);

/// Remembers that this launch's questions have been put to the adult.
class LaunchConsentAskedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Records that the launch's questions have been put, so the connect screen
  /// asks nothing the next time it opens.
  void mark() => state = true;
}
