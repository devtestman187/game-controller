import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:protocol/protocol.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The controller is a landscape-only app.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ControllerApp());
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5AAAFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HelloScreen(),
    );
  }
}

class HelloScreen extends StatelessWidget {
  const HelloScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports, size: 72),
              const SizedBox(height: 16),
              Text('Game Controller', style: text.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Hello from ${defaultTargetPlatform.name} · '
                'protocol v$protocolVersion',
                style: text.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text('Milestone 0 build', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
