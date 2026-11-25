import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' show askConsents;

import '../host/hosting.dart';
import '../providers.dart';

/// Whether this launch's two consent questions are due now, and if they are,
/// marks the launch asked so they are never put twice.
///
/// False when this phone hosts a live game (that game's own first frame asks
/// instead, B-023), when the launch asks nothing, or when the launch already
/// asked. Otherwise it marks the launch asked and returns true.
bool launchConsentDue(WidgetRef ref) {
  if (ref.read(hostingProvider)?.live ?? false) return false;
  if (!ref.read(launchConsentAskProvider) || ref.read(launchConsentAskedProvider)) return false;
  ref.read(launchConsentAskedProvider.notifier).mark();
  return true;
}

/// Puts this launch's own two questions (design sentry-consent.md) to the adult,
/// once a launch: Home and the pad both enter here, and the launch's flag means
/// they never ask twice.
///
/// The returned future completes when the questions are answered, or at once
/// when none is asked. The caller checks that [context] is still mounted.
Future<void> askLaunchConsent(BuildContext context, WidgetRef ref) async {
  if (!launchConsentDue(ref)) return;
  await askConsents(context, ref);
}
