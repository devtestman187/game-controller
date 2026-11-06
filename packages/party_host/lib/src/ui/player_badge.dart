import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart';

/// A round badge with the player number in the player's colour (was in
/// `latency_screen.dart`; every host screen uses it).
class PlayerBadge extends StatelessWidget {
  const PlayerBadge({super.key, required this.number, this.size = 32});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: Color(playerColor(number)), shape: BoxShape.circle),
    child: Text(
      '$number',
      style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.bold, color: const Color(0xFF14181F)),
    ),
  );
}
