import 'package:connection/connection.dart';

/// Short status for the app bar chip and Diagnostics.
String statusLabel(ClientSnapshot s) => switch (s.status) {
  ClientStatus.idle => 'Not connected',
  ClientStatus.connecting => 'Connecting…',
  ClientStatus.waitingForCode => 'Enter code',
  ClientStatus.pairing => 'Pairing…',
  ClientStatus.connected => 'Connected',
  ClientStatus.reconnecting => 'Reconnecting…',
  ClientStatus.failed => 'Not connected',
};

/// A sentence explaining a problem, for the connection panel.
String? problemMessage(ClientSnapshot s) {
  final host = s.hostLabel;
  return switch (s.problem) {
    null => null,
    ClientProblem.unreachable =>
      'Couldn\'t reach $host. Check that the TV app is open and that the phone is on the same Wi-Fi.',
    ClientProblem.wrongCode => 'Wrong code. Check the code on the TV and try again.',
    ClientProblem.tooManyAttempts => 'Too many wrong codes. The TV now shows a new code.',
    ClientProblem.pairingForgotten =>
      'The TV doesn\'t remember this phone (it may have restarted). Enter the code again.',
    ClientProblem.versionMismatch =>
      'The TV app and this app use different protocol versions. Install matching builds.',
    ClientProblem.replaced => 'This phone connected to the TV again on another connection.',
    ClientProblem.protocolError => 'The TV rejected a message${s.detail == null ? '' : ' (${s.detail})'}.',
    ClientProblem.pairingTimeout => 'The code wasn\'t entered in time.',
    ClientProblem.connectionLost => 'The connection to $host was lost.',
  };
}
