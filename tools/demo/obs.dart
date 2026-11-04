import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Minimal obs-websocket v5 client for the demo video pipeline
/// (docs/demo-video-runbook.md 2.6).
///
/// Usage (from the repository root):
///   dart run tools/demo/obs.dart setup   --password-file <path>
///   dart run tools/demo/obs.dart record  --password-file <path> --seconds 12
///   dart run tools/demo/obs.dart stop-record
///
/// The password file is `$WORK/backup/obs-password.txt`; it is never committed.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: obs.dart <setup|record|stop-record|quit> [--password-file f] [--seconds n]',
    );
    exit(2);
  }
  final command = args.first;
  String arg(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final password = File(arg('password-file', 'obs-password.txt'))
      .readAsStringSync()
      .trim();
  final client = await ObsClient.connect('127.0.0.1', 4455, password);
  try {
    switch (command) {
      case 'setup':
        await client.setUp();
        stdout.writeln('obs: profile and scene ready');
      case 'record':
        final seconds = int.parse(arg('seconds', '12'));
        await client.startRecord();
        stdout.writeln('obs: recording for ${seconds}s');
        await Future<void>.delayed(Duration(seconds: seconds));
        final path = await client.stopRecord();
        stdout.writeln('obs: saved $path');
      case 'stop-record':
        stdout.writeln('obs: saved ${await client.stopRecord()}');
      case 'quit':
        await client.close();
      default:
        stderr.writeln('unknown command $command');
        exit(2);
    }
  } finally {
    await client.close();
  }
}

class ObsClient {
  ObsClient._(this._socket);

  final WebSocket _socket;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _hello = Completer<Map<String, dynamic>>();
  final _identified = Completer<void>();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  var _nextId = 1;

  static Future<ObsClient> connect(
    String host,
    int port,
    String password,
  ) async {
    final socket = await WebSocket.connect('ws://$host:$port');
    final client = ObsClient._(socket);
    client._listen();
    await client._identify(password);
    return client;
  }

  void _listen() {
    _socket.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      final op = message['op'] as int;
      if (op == 0) {
        _hello.complete((message['d'] as Map).cast<String, dynamic>());
      } else if (op == 2) {
        if (!_identified.isCompleted) _identified.complete();
      } else if (op == 7) {
        final id = message['d']['requestId'] as String;
        final completer = _pending.remove(id);
        if (completer == null) return;
        final status = message['d']['requestStatus'] as Map<String, dynamic>;
        if (status['result'] == true) {
          completer.complete(
            (message['d']['responseData'] as Map?)?.cast<String, dynamic>() ??
                const {},
          );
        } else {
          completer.completeError(
            ObsError('${status['code']}: ${status['comment'] ?? ''}'),
          );
        }
      } else if (op == 5) {
        _events.add((message['d'] as Map).cast<String, dynamic>());
      }
    });
  }

  Future<void> _identify(String password) async {
    final hello = await _hello.future.timeout(const Duration(seconds: 10));
    final authentication = hello['authentication'] as Map<String, dynamic>?;
    final identify = <String, dynamic>{'rpcVersion': 1};
    if (authentication != null) {
      final salt = authentication['salt'] as String;
      final challenge = authentication['challenge'] as String;
      final secret = base64.encode(
        sha256.convert(utf8.encode(password + salt)).bytes,
      );
      identify['authentication'] = base64.encode(
        sha256.convert(utf8.encode(secret + challenge)).bytes,
      );
    }
    _socket.add(jsonEncode({'op': 1, 'd': identify}));
    await _identified.future.timeout(const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>> request(
    String type, [
    Map<String, dynamic>? data,
  ]) {
    final id = 'r${_nextId++}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _socket.add(
      jsonEncode({
        'op': 6,
        'd': {
          'requestType': type,
          'requestId': id,
          if (data != null) 'requestData': data,
        },
      }),
    );
    return completer.future.timeout(const Duration(seconds: 20));
  }

  /// Creates the demo profile and the `Phone` scene with a cropped window
  /// capture of the emulator.
  Future<void> setUp() async {
    const profile = 'ThumbPartyDemo';
    const collection = 'ThumbPartyDemo';
    try {
      await request('CreateProfile', {'profileName': profile});
    } on ObsError {
      // Already exists.
    }
    await request('SetCurrentProfile', {'profileName': profile});
    await request('SetVideoSettings', {
      'baseWidth': 1920,
      'baseHeight': 1080,
      'outputWidth': 1920,
      'outputHeight': 1080,
      'fpsNumerator': 60,
      'fpsDenominator': 1,
    });
    for (final MapEntry(key: name, value: value) in {
      'Output/Mode': 'Advanced',
      'AdvOut/RecFilePath': r'C:\Users\singh\thumbparty-demo\footage',
      'AdvOut/RecFormat2': 'mkv',
      'AdvOut/RecRB': 'false',
      'AdvOut/RecEncoder': 'obs_qsv11_v2',
    }.entries) {
      await request('SetProfileParameter', {
        'parameterCategory': 'AdvOut',
        'parameterName': name,
        'parameterValue': value,
      });
    }

    try {
      await request('CreateSceneCollection', {
        'sceneCollectionName': collection,
      });
    } on ObsError {
      // Already exists.
    }
    await request('CreateScene', {'sceneName': 'Phone'});
    await request('CreateInput', {
      'sceneName': 'Phone',
      'inputName': 'phone',
      'inputKind': 'window_capture',
      'inputSettings': {
        'window': 'Android Emulator - m7_android12:5554',
        'window_priority': 2,
        'capture_cursor': false,
        'method': 2,
      },
      'sceneItemEnabled': true,
    });
    await request('SetCurrentProgramScene', {'sceneName': 'Phone'});
    // Scale into 1200x540 and crop the emulator's toolbars away.
    final item = await request('GetSceneItemId', {
      'sceneName': 'Phone',
      'sourceName': 'phone',
    });
    await request('SetSceneItemTransform', {
      'sceneName': 'Phone',
      'sceneItemId': item['sceneItemId'],
      'sceneItemTransform': {
        'boundsType': 'OBS_BOUNDS_SCALE_INNER',
        'boundsWidth': 1200,
        'boundsHeight': 540,
        'alignment': 5,
      },
    });
  }

  Future<void> startRecord() => request('StartRecord');

  Future<String> stopRecord() async {
    final out = await request('StopRecord');
    return out['outputPath'] as String? ?? '';
  }

  Future<void> close() async {
    await _events.close();
    await _socket.close();
  }
}

class ObsError implements Exception {
  ObsError(this.message);
  final String message;
  @override
  String toString() => 'ObsError: $message';
}
