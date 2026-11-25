import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show askConsents;

import '../host/hosting.dart';
import '../providers.dart';

/// Puts this launch's own two questions (design sentry-consent.md) to the adult,
/// once a launch: Home and the pad both enter here, and the launch's flag means
/// they never ask twice.
///
/// Nothing is asked while this phone hosts a live game: that game's own first
/// frame asks instead (B-023), never a prompt over it. The returned future
/// completes when the questions are answered, or at once when none is asked.
/// The caller checks that [context] is still mounted.
Future<void> askLaunchConsent(BuildContext context, WidgetRef ref) async {
  if (ref.read(hostingProvider)?.live ?? false) return;
  if (!ref.read(launchConsentAskProvider) || ref.read(launchConsentAskedProvider)) return;
  ref.read(launchConsentAskedProvider.notifier).mark();
  await askConsents(context, ref);
}
