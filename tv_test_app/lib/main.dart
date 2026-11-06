import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/keyboard_player.dart';
import 'src/tv_host_setup.dart';
import 'src/ui/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // The shell's own inputs for the host: its identity, its folders and its
  // uploader come from `tv_host_setup.dart`, its local player from the
  // keyboard player on a desktop (M12 design §2.6).
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        hostIdentityProvider.overrideWithValue(tvHostIdentity()),
        hostDirectoriesProvider.overrideWithValue(const TvDirectories()),
        sessionUploaderProvider.overrideWith((ref) => tvUploader()),
        localPlayerSourceProvider.overrideWithValue(tvKeyboardPlayer),
      ],
      child: const TvTestApp(),
    ),
  );
}

class TvTestApp extends StatelessWidget {
  const TvTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      // The remote's OK button and the gamepad's A press what has the focus.
      shortcuts: hostActivateShortcuts,
      child: MaterialApp(
        title: 'Thumb Party TV',
        // The phones work every screen like the remote (PRD v2 T21).
        builder: (context, child) => ControllerMenus(child: child!),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5AAAFF), brightness: Brightness.dark),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
