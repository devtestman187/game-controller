import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';

/// Asks this instance's consent questions once, on the first launch (PRD v2
/// T19, design sentry-consent.md): crash reports first, but only where this
/// build can send them, then usage stats, and each one only while it is
/// unanswered. Takes no space.
class FirstLaunchConsent extends ConsumerStatefulWidget {
  const FirstLaunchConsent({super.key});

  @override
  ConsumerState<FirstLaunchConsent> createState() => _FirstLaunchConsentState();
}

class _FirstLaunchConsentState extends ConsumerState<FirstLaunchConsent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasUnansweredQuestion) unawaited(askConsents(context, ref));
    });
  }

  /// Whether this launch has a question left to ask: the stats one always,
  /// the crash reports one only where a report could be sent.
  bool get _hasUnansweredQuestion {
    final consent = ref.read(consentProvider);
    return consent.stats == null || (ref.read(crashAvailableProvider) && consent.crash == null);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
