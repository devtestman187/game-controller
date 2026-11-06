import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';

/// Shows the consent prompt once, on the first launch (PRD v2 T19), when
/// the stats sharing choice has never been made. Takes no space.
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
      if (mounted && ref.read(statsStateProvider).consent == null) askConsent(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
