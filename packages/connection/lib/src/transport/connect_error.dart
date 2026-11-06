import 'dart:async';
import 'dart:io';

/// A short, readable description of a connection error, for the connector's
/// log lines and the listener's failure message.
String describeError(Object error) => switch (error) {
  SocketException(osError: final os?) => '${os.message.trim()} (OS error ${os.errorCode})',
  SocketException(:final message) => message,
  WebSocketException(:final message) => message,
  HttpException(:final message) => message,
  TimeoutException() => 'Timed out',
  _ => '$error',
};
