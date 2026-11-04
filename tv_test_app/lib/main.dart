import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/demo/demo_boot.dart';
import 'src/demo/demo_flags.dart';
import 'src/demo/demo_live.dart';
import 'src/demo/demo_window.dart';
import 'src/providers.dart';
import 'src/ui/controller_menus.dart';
import 'src/ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Demo video (docs/demo-video-runbook.md 2.1): its own preferences and its
  // own sessions folder, so the owner's pairings, consent and settings are
  // never touched, and a borderless full-screen window. Store builds never set
  // DEMO_DIRECTOR, so none of this runs there.
  if (demoDirector) {
    SharedPreferences.setPrefix('demo.');
    installDemoLive();
  }
  final prefs = await SharedPreferences.getInstance();
  if (demoDirector) {
    WidgetsBinding.instance.addPostFrameCallback((_) => demoFullScreen());
  }
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const TvTestApp()));
}

class TvTestApp extends StatelessWidget {
  const TvTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      // TV remotes send "select" (D-pad center). Map it, Enter and the gamepad A
      // button to "activate" so every focused control works with a remote.
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      child: MaterialApp(
        title: 'Thumb Party TV',
        // The phones work every screen like the remote (PRD v2 T21). In a demo
        // build the director starts on top of it, once the TV is listening.
        builder: (context, child) {
          final menus = ControllerMenus(child: child!);
          return demoDirector ? DemoBoot(child: menus) : menus;
        },
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5AAAFF), brightness: Brightness.dark),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
