import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:shared_preferences/shared_preferences.dart';

import 'src/host/automation_build.dart';
import 'src/host/host_overrides.dart';
import 'src/host/phone_host_setup.dart';
import 'src/providers.dart';
import 'src/ui/controller_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The controller is a landscape-only app.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  // Full screen, so the status bar doesn't take room from the pad.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final prefs = await SharedPreferences.getInstance();
  // The look's shader, loaded before the first screen (M13 design section 6):
  // a slow device shows its splash a little longer rather than a stalled first
  // menu, and the Canvas fallback draws everything if it doesn't arrive.
  final shaders = await party.ToyShaders.load().timeout(
    party.toyShaderLoadTimeout,
    onTimeout: () => party.ToyShaders.none,
  );
  // The fonts' licences, for the licence page only, so nothing waits for them.
  unawaited(party.registerToyFontLicenses());
  runApp(
    ProviderScope(
      // The host's inputs live in the root scope (m12 §3): the host route, the
      // pause menu's dialog and the games all read the one container.
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        party.toyShadersProvider.overrideWithValue(shaders),
        // The sessions this phone hosts go to the stats store, with the adult's
        // yes at the Stats screen, as the TV's do (M14 r5 8). A build with no
        // Firestore project set has none, and the sessions stay on the phone.
        party.sessionUploaderProvider.overrideWith((ref) => phoneUploader()),
        // The automation interface is compiled in and off unless the build's
        // `--dart-define=AUTOMATION=true` says so (M15 a2): a phone has no
        // environment to launch it from.
        party.automationSettingsProvider.overrideWithValue(phoneAutomationSettings()),
        ...phoneHostOverrides(directories: const PhoneHostDirectories()),
      ],
      child: const ControllerApp(),
    ),
  );
}

/// The app in the toy look (M13): the look over everything, and the theme made
/// from it, so every screen and every route draws in it.
class ControllerApp extends ConsumerWidget {
  const ControllerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(party.toyLookProvider);
    return party.ToyLookScope(
      look: look,
      child: MaterialApp(
        title: 'Thumb Party',
        debugShowCheckedModeBanner: false,
        theme: party.toyTheme(look),
        // A page's push or pop works the palette out again (design D1), never
        // a dialog's.
        navigatorObservers: [ref.watch(party.toyLookRouteObserverProvider)],
        // This phone is touch first, so nothing on its host's screens keeps a
        // focus look a thumb can't take away (m12 bug 1107f rule A). Above every
        // route, so the dialogs are covered too. The automation shell takes the
        // frame a screenshot captures and draws the latency card over every
        // route (M15 a2).
        builder: (context, child) =>
            party.AutomationShell(child: party.HostFocusScope(child: child ?? const SizedBox.shrink())),
        // A script's `POST game/start` pushes the round here (M15 a2).
        home: const party.AutomationGate(child: ControllerScreen()),
      ),
    );
  }
}
