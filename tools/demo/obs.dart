import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'paths.dart';

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
      'usage: obs.dart <launch|setup|both|prepare|fit|record|stop-record|cursor|bind-tv|quit> '
      '[--password-file f] [--seconds n] [--input tv] [--value false]',
    );
    exit(2);
  }
  final command = args.first;
  String arg(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  if (command == 'launch') {
    // OBS must start from its own folder, or it stops on a hidden
    // "Failed to find locale/en-US.ini" dialog and never opens the websocket.
    final process = await Process.start(
      r'C:\Program Files\obs-studio\bin\64bit\obs64.exe',
      const [
        '--profile',
        'ThumbPartyDemo',
        '--collection',
        'ThumbPartyDemo',
        '--scene',
        'Phone',
        '--minimize-to-tray',
        '--disable-shutdown-check',
      ],
      workingDirectory: r'C:\Program Files\obs-studio\bin\64bit',
      mode: ProcessStartMode.detached,
    );
    stdout.writeln('obs: pid ${process.pid}');
    return;
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
      case 'prepare':
        await client.prepare(arg('screenshot', 'obs_phone_check.png'));
        stdout.writeln('obs: Phone scene ready');
      case 'both':
        await client.setUpBoth(
          int.parse(arg('width', '3840')),
          int.parse(arg('height', '1080')),
        );
        stdout.writeln('obs: Both scene ready');
      case 'canvas':
        await client.setCanvas(
          int.parse(arg('width', '3840')),
          int.parse(arg('height', '1080')),
        );
        stdout.writeln('obs: canvas set');
      case 'shot':
        // A window capture that is not in the program scene renders blank in
        // GetSourceScreenshot, so the scene can be set first.
        if (args.contains('--scene')) {
          await client.request('SetCurrentProgramScene', {
            'sceneName': arg('scene', 'TV'),
          });
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
        await client.screenshot(
          arg('source', 'Both'),
          arg('out', 'shot.png'),
          int.parse(arg('width', '3840')),
          int.parse(arg('height', '1080')),
        );
        stdout.writeln('obs: screenshot ${arg('out', 'shot.png')}');
      case 'fit':
        await client.fitPhone(
          double.parse(arg('width', '1920')),
          double.parse(arg('height', '1080')),
          double.parse(arg('rotation', '0')),
        );
        stdout.writeln('obs: phone fitted');
      case 'record':
        final seconds = int.parse(arg('seconds', '12'));
        await client.startRecord();
        stdout.writeln('obs: recording for ${seconds}s');
        await Future<void>.delayed(Duration(seconds: seconds));
        final path = await client.stopRecord();
        stdout.writeln('obs: saved $path');
      case 'stop-record':
        stdout.writeln('obs: saved ${await client.stopRecord()}');
      case 'scenes':
        final list = await client.request('GetSceneList');
        stdout.writeln(
          'obs: scenes ${[for (final s in (list['scenes'] as List? ?? const [])) (s as Map)['sceneName']]}',
        );
      case 'cursor':
        // 2.8's cursor gate: read (or set) what a window capture does with the
        // pointer. `--value false` is what every take needs.
        final input = arg('input', 'tv');
        if (args.contains('--value')) {
          await client.setCaptureCursor(input, arg('value', 'false') == 'true');
        }
        stdout.writeln(
          'obs: $input capture_cursor=${await client.cursorCaptured(input)}',
        );
      case 'bind-tv':
        await client.bindTvWindow();
        stdout.writeln(
          'obs: tv capture_cursor=${await client.cursorCaptured('tv')}',
        );
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
        if (!_events.isClosed) {
          _events.add((message['d'] as Map).cast<String, dynamic>());
        }
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
  ///
  /// The recorder writes into `$WORK/footage` (E4); the folder is created here
  /// because OBS fails a recording whose folder is missing.
  Future<void> setUp({String? footageDir}) async {
    final footage = footageDir ?? workPath('footage');
    Directory(footage).createSync(recursive: true);
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
      'AdvOut/RecFilePath': footage,
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

  Future<void> setCanvas(int width, int height) async {
    await request('SetVideoSettings', {
      'baseWidth': width,
      'baseHeight': height,
      'outputWidth': width,
      'outputHeight': height,
      'fpsNumerator': 60,
      'fpsDenominator': 1,
    });
  }

  Future<void> screenshot(
    String source,
    String path,
    int width,
    int height,
  ) async {
    final shot = await request('GetSourceScreenshot', {
      'sourceName': source,
      'imageFormat': 'png',
      'imageWidth': width,
      'imageHeight': height,
      'imageCompressionQuality': 80,
    });
    File(path).writeAsBytesSync(
      base64.decode((shot['imageData'] as String? ?? '').split(',').last),
    );
  }

  /// One 3840x1080 canvas: the TV window on the left, the phone window on the
  /// right. Recording both in one file keeps them frame-exact; the recorder
  /// crops the halves into the `<shot>_take<N>_tv.mkv` / `_phone.mkv` files.
  Future<void> setUpBoth([
    int width = 3840,
    int height = 1080,
    String? phoneAvd,
  ]) async {
    await request('SetVideoSettings', {
      'baseWidth': width,
      'baseHeight': height,
      'outputWidth': width,
      'outputHeight': height,
      'fpsNumerator': 60,
      'fpsDenominator': 1,
    });
    try {
      await request('CreateScene', {'sceneName': 'Both'});
    } on ObsError {
      // Already exists.
    }
    await _ensureSource('Both', 'tv', 'window_capture');
    await _ensureSource('Both', 'phone', 'window_capture');
    await _setWindow('tv', const ['thumbpartytv.exe']);
    await _setWindow('phone', [
      'android emulator -',
      if (phoneAvd != null) phoneAvd.toLowerCase(),
    ]);
    await _place(
      'Both',
      'tv',
      width / 4,
      height / 2,
      width / 2,
      height.toDouble(),
    );
    await _place(
      'Both',
      'phone',
      width * 3 / 4,
      height / 2,
      width / 2,
      height.toDouble(),
    );
    await request('SetCurrentProgramScene', {'sceneName': 'Both'});
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  Future<void> _ensureSource(String scene, String input, String kind) async {
    final list = await request('GetSceneItemList', {'sceneName': scene});
    for (final raw in (list['sceneItems'] as List?) ?? const []) {
      if ((raw as Map)['sourceName'] == input) return;
    }
    try {
      await request('CreateInput', {
        'sceneName': scene,
        'inputName': input,
        'inputKind': kind,
        'inputSettings': {'capture_cursor': false, 'method': 2},
        'sceneItemEnabled': true,
      });
    } on ObsError {
      // The input exists in another scene; just add it to this one.
      await request('CreateSceneItem', {
        'sceneName': scene,
        'sourceName': input,
        'sceneItemEnabled': true,
      });
    }
  }

  /// Points the window capture at the running window whose title contains
  /// every one of [patterns]. OBS lists stale window titles too (an emulator
  /// that has quit stays in its list), so one loose pattern can bind a dead
  /// window and record a black half.
  Future<void> _setWindow(String input, List<String> patterns) async {
    final props = await request('GetInputPropertiesListPropertyItems', {
      'inputName': input,
      'propertyName': 'window',
    });
    final items = (props['propertyItems'] as List?) ?? const [];
    Map<String, dynamic>? chosen;
    for (final raw in items) {
      final item = (raw as Map).cast<String, dynamic>();
      final name = (item['itemName'] as String? ?? '').toLowerCase();
      if (patterns.every(name.contains)) {
        chosen = item;
        break;
      }
    }
    if (chosen == null) {
      stderr.writeln(
        'obs: no window for $input (want ${patterns.join(' + ')}); windows:',
      );
      for (final raw in items) {
        stderr.writeln('  ${(raw as Map)['itemName']}');
      }
      throw ObsError('window not found for $input');
    }
    stdout.writeln('obs: $input <- ${chosen['itemName']}');
    // `capture_cursor` again on every bind: a source created before the demo
    // pipeline set it (the TV scene in this machine's collection) would keep
    // drawing the arrow over the footage, and the value at creation time is
    // long gone by the time a take runs.
    await request('SetInputSettings', {
      'inputName': input,
      'inputSettings': {
        'window': chosen['itemValue'],
        'window_priority': 2,
        'capture_cursor': false,
      },
      'overlay': true,
    });
    final cursor = await cursorCaptured(input);
    if (cursor) {
      throw ObsError(
        'obs: $input still captures the cursor; a take would show the pointer',
      );
    }
  }

  /// Whether a window capture draws the pointer. Read back from OBS rather
  /// than assumed, so 2.8's cursor check has something to record per take.
  Future<bool> cursorCaptured(String input) async {
    final settings = await request('GetInputSettings', {'inputName': input});
    final values =
        (settings['inputSettings'] as Map?)?.cast<String, dynamic>() ??
        const {};
    return values['capture_cursor'] == true;
  }

  /// Sets the pointer setting on a window capture. Used by the `cursor`
  /// command to show the gate working on the real source.
  Future<void> setCaptureCursor(String input, bool captured) async {
    await request('SetInputSettings', {
      'inputName': input,
      'inputSettings': {'capture_cursor': captured},
      'overlay': true,
    });
  }

  Future<void> _place(
    String scene,
    String input,
    double x,
    double y,
    double width,
    double height,
  ) async {
    final item = await request('GetSceneItemId', {
      'sceneName': scene,
      'sourceName': input,
    });
    await request('SetSceneItemTransform', {
      'sceneName': scene,
      'sceneItemId': item['sceneItemId'],
      'sceneItemTransform': {
        'positionX': x,
        'positionY': y,
        'boundsType': 'OBS_BOUNDS_SCALE_INNER',
        'boundsWidth': width,
        'boundsHeight': height,
        'alignment': 0,
        'rotation': 0,
      },
    });
  }

  /// Re-binds the TV window capture to the running demo TV window. A scene's
  /// window_capture keeps a stale window handle across TV restarts, which
  /// records a black frame.
  Future<void> bindTvWindow() => _setWindow('tv', const ['thumbpartytv.exe']);

  /// Fits the TV source to the whole 1920x1080 canvas of [scene].
  Future<void> fitTv(String scene) => _place(scene, 'tv', 960, 540, 1920, 1080);

  /// Adds the tv source to a scene that has no items (the collection on this
  /// machine calls its TV scene `Scene` but never gave it one).
  Future<void> ensureTvItem(String scene) async {
    final list = await request('GetSceneItemList', {'sceneName': scene});
    for (final raw in (list['sceneItems'] as List?) ?? const []) {
      if ((raw as Map)['sourceName'] == 'tv') return;
    }
    await request('CreateSceneItem', {
      'sceneName': scene,
      'sourceName': 'tv',
      'sceneItemEnabled': true,
    });
  }

  /// Points the `phone` window capture at the running emulator window and
  /// writes a source screenshot, so a black capture is caught before recording.
  Future<void> prepare(String screenshotPath) async {
    await request('SetCurrentProgramScene', {'sceneName': 'Phone'});
    final properties = await request('GetInputPropertiesListPropertyItems', {
      'inputName': 'phone',
      'propertyName': 'window',
    });
    final items = (properties['propertyItems'] as List?) ?? const [];
    Map<String, dynamic>? chosen;
    for (final item in items) {
      final name = ((item as Map)['itemName'] as String? ?? '').toLowerCase();
      if (name.contains('android emulator -')) {
        chosen = item.cast<String, dynamic>();
        break;
      }
    }
    if (chosen == null) {
      stderr.writeln('obs: no emulator window found; windows:');
      for (final item in items) {
        stderr.writeln('  ${(item as Map)['itemName']}');
      }
      throw ObsError('emulator window not found');
    }
    stdout.writeln('obs: window ${chosen['itemName']}');
    await request('SetInputSettings', {
      'inputName': 'phone',
      'inputSettings': {'window': chosen['itemValue'], 'window_priority': 2},
      'overlay': true,
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final shot = await request('GetSourceScreenshot', {
      'sourceName': 'Phone',
      'imageFormat': 'png',
      'imageWidth': 1920,
      'imageHeight': 1080,
      'imageCompressionQuality': 80,
    });
    final data = (shot['imageData'] as String? ?? '').split(',').last;
    File(screenshotPath).writeAsBytesSync(base64.decode(data));
    stdout.writeln('obs: screenshot $screenshotPath');
  }

  /// Scales (and optionally rotates) the `phone` scene item inside the canvas.
  Future<void> fitPhone(double width, double height, double rotation) async {
    final item = await request('GetSceneItemId', {
      'sceneName': 'Phone',
      'sourceName': 'phone',
    });
    await request('SetSceneItemTransform', {
      'sceneName': 'Phone',
      'sceneItemId': item['sceneItemId'],
      'sceneItemTransform': {
        'boundsType': 'OBS_BOUNDS_SCALE_INNER',
        'boundsWidth': width,
        'boundsHeight': height,
        'alignment': 5,
        'rotation': rotation,
      },
    });
  }

  Future<void> startRecord() => request('StartRecord');

  Future<String> stopRecord() async {
    final out = await request('StopRecord');
    return out['outputPath'] as String? ?? '';
  }

  Future<void> close() async {
    await _socket.close();
    await _events.close();
  }
}

class ObsError implements Exception {
  ObsError(this.message);
  final String message;
  @override
  String toString() => 'ObsError: $message';
}
