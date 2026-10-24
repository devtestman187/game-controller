import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:protocol/protocol.dart';

void main() {
  runApp(const TvTestApp());
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
        title: 'Controller Test',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5AAAFF),
            brightness: Brightness.dark,
          ),
        ),
        home: const HelloScreen(),
      ),
    );
  }
}

class HelloScreen extends StatefulWidget {
  const HelloScreen({super.key});

  @override
  State<HelloScreen> createState() => _HelloScreenState();
}

class _HelloScreenState extends State<HelloScreen> {
  String _lastAction = 'Use the remote: arrows to move, center to select.';
  String _lastKey = '-';

  void _act(String label) => setState(() => _lastAction = 'Selected: $label');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Focus(
        // Observe keys without consuming them, to show what the remote sends.
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            setState(() => _lastKey = event.logicalKey.keyLabel.isEmpty
                ? event.logicalKey.debugName ?? '?'
                : event.logicalKey.keyLabel);
          }
          return KeyEventResult.ignored;
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Works on a 16:9 TV and a resizable laptop window.
              final scale = (constraints.maxWidth / 1280).clamp(0.6, 1.5);
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(32 * scale),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tv, size: 72 * scale),
                      SizedBox(height: 16 * scale),
                      Text('Controller Test App', style: text.displaySmall),
                      SizedBox(height: 8 * scale),
                      Text('Protocol v$protocolVersion · Milestone 0',
                          style: text.titleMedium),
                      SizedBox(height: 32 * scale),
                      Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          _TvButton(label: 'Input', autofocus: true, onPressed: () => _act('Input')),
                          _TvButton(label: 'Game', onPressed: () => _act('Game')),
                          _TvButton(label: 'Haptics', onPressed: () => _act('Haptics')),
                        ],
                      ),
                      SizedBox(height: 32 * scale),
                      Text(_lastAction, style: text.titleLarge),
                      SizedBox(height: 8 * scale),
                      Text('Last key: $_lastKey', style: text.bodyMedium),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A button with a strong focus ring that is easy to see from the couch.
class _TvButton extends StatelessWidget {
  const _TvButton({required this.label, required this.onPressed, this.autofocus = false});

  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.tonal(
      autofocus: autofocus,
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(200, 64)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 22)),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? BorderSide(color: scheme.primary, width: 4)
              : BorderSide.none,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
        ),
      ),
      child: Text(label),
    );
  }
}
