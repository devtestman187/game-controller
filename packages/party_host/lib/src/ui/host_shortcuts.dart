import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The keys and buttons that press the focused control, for every host app:
/// a TV remote sends "select" for its OK button, and Enter and the gamepad's A
/// arrive from keyboards and controllers. Mapping all three to
/// [ActivateIntent] lets every screen work without a mouse (PRD v2 T21).
const hostActivateShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
};
