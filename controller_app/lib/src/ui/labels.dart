import 'package:connection/connection.dart';
import 'package:party_host/party_host.dart' show PhoneText;

/// Short status for the app bar chip and Diagnostics.
String statusLabel(ClientSnapshot s) => PhoneText.status(s.status);

/// A sentence explaining a problem, for the connection panel.
String? problemMessage(ClientSnapshot s) => PhoneText.problemText(s);
