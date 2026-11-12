// Calls the host's automation interface (M15 a2): `dart tools/automation.dart
// <call> [options]`. Documented in docs/automation.md, with the calls, their
// bodies and a curl example for each.
//
//   status                      the host, its screen, its players and its ports
//   players --nickname Ann      add a simulated player (--colour 1..6
//                               --accessory ears|antenna|bow|cap|tuft|crown)
//   players --remove local-1    take one back out
//   input --player local-1 --buttons a --dx 0 --dy 0   a press or a stick
//   start --game arena --mode bumper --map toy-factory --level hard
//         --puzzle house --teams 1=left,2=right --night 3 --chaos little --robo easy
//   stop                        back to the home screen
//   settings --look night --hz 30 --sound off --consent no
//   state                       the round, its latest frame, the last result
//   flash --on|--off            show or hide the latency test card
//   press --player local-1 --button a   a press, timed on the host's clock
//   stream --json '{"viewer":{"kind":"browser"},"stages":[{"name":"input","ms":40}]}'
//   session                     the live session's summary
//   screenshot --out shot.png   the host's frame as a PNG
//
// The token comes from --token or THUMBPARTY_AUTOMATION_TOKEN, the address
// from --url or THUMBPARTY_AUTOMATION_URL (the loopback default otherwise).
// Exit code: 0 the host answered ok, 1 it refused, 2 bad use.
import 'dart:convert';
import 'dart:io';

/// Where the interface listens unless a launch moved it.
const defaultBase = 'http://127.0.0.1:8787/automation/v1';

/// The header a token travels in when one is set.
const tokenHeader = 'x-automation-token';

/// The file a screenshot goes to when `--out` names none.
const defaultShot = 'automation-screenshot.png';

/// What `--help` and a bad call print.
final usage =
    'Calls: ${calls.keys.join(', ')}\n'
    'Options: --url --token, and the ones a call takes: '
    '--nickname --colour --accessory --remove --player --buttons --dx --dy --lx --ly '
    '--game --mode --map --puzzle --level --teams --chaos --robo --night '
    '--look --hz --sound --consent --on --off --button --json --out';

/// Every call the interface has: its method and its path.
const calls = <String, (String, String)>{
  'status': ('GET', '/status'),
  'players': ('POST', '/players'),
  'input': ('POST', '/input'),
  'start': ('POST', '/game/start'),
  'stop': ('POST', '/game/stop'),
  'settings': ('POST', '/settings'),
  'state': ('GET', '/state'),
  'flash': ('POST', '/probe/flash'),
  'press': ('POST', '/probe/press'),
  'stream': ('POST', '/stats/stream'),
  'session': ('GET', '/stats/session'),
  'screenshot': ('GET', '/screenshot'),
};

/// A launch the tool can't use: its message is what the person reads.
final class UsageError implements Exception {
  const UsageError(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<void> main(List<String> args) async {
  try {
    await run(args);
  } on UsageError catch (e) {
    stderr.writeln(e.message);
    stderr.writeln('Usage: dart tools/automation.dart <call> [options]; --help lists the calls.');
    exitCode = 2;
  }
}

/// Runs one call and prints its answer; a refusal sets the exit code.
Future<void> run(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    print(usage);
    if (args.isEmpty) exitCode = 2;
    return;
  }
  final name = args.first;
  final call = calls[name];
  if (call == null) throw UsageError('there is no call "$name": ${calls.keys.join(', ')}');
  final options = _optionsOf(args.skip(1));
  final base = options['url'] ?? Platform.environment['THUMBPARTY_AUTOMATION_URL'] ?? defaultBase;
  final token = options['token'] ?? Platform.environment['THUMBPARTY_AUTOMATION_TOKEN'] ?? '';
  final client = HttpClient();
  try {
    final request = await client.openUrl(call.$1, Uri.parse('$base${call.$2}'));
    if (token.isNotEmpty) request.headers.set(tokenHeader, token);
    final body = _bodyOf(name, options);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final bytes = await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    if (name == 'screenshot' && response.statusCode == HttpStatus.ok) {
      final out = File(options['out'] ?? defaultShot)..writeAsBytesSync(bytes);
      print('saved ${out.path} (${bytes.length} bytes)');
      return;
    }
    final text = utf8.decode(bytes);
    final decoded = jsonDecode(text);
    print(const JsonEncoder.withIndent('  ').convert(decoded));
    if (response.statusCode != HttpStatus.ok) exitCode = 1;
  } finally {
    client.close(force: true);
  }
}

/// `--name value` pairs; `--on` and `--off` are the one flag pair.
Map<String, String> _optionsOf(Iterable<String> args) {
  final options = <String, String>{};
  final list = args.toList();
  for (var i = 0; i < list.length; i++) {
    final arg = list[i];
    if (!arg.startsWith('--')) throw UsageError('"$arg" is not an option: write --name value');
    final name = arg.substring(2);
    if (name == 'on' || name == 'off') {
      options['on'] = '${name == 'on'}';
      continue;
    }
    if (i + 1 >= list.length) throw UsageError('--$name needs a value');
    options[name] = list[++i];
  }
  return options;
}

/// The body [call] sends, or null for a call without one.
Map<String, Object?>? _bodyOf(String call, Map<String, String> o) => switch (call) {
  'players' => _playersBody(o),
  'input' => {
    if (o['player'] != null) 'player': o['player']!,
    'buttons': [
      for (final b in (o['buttons'] ?? '').split(','))
        if (b.isNotEmpty) b,
    ],
    if (o['dx'] != null) 'dx': _number(o, 'dx'),
    if (o['dy'] != null) 'dy': _number(o, 'dy'),
    if (o['lx'] != null) 'lx': _decimal(o, 'lx'),
    if (o['ly'] != null) 'ly': _decimal(o, 'ly'),
  },
  'start' => _startBody(o),
  'settings' => {
    if (o['look'] != null) 'look': o['look']!,
    if (o['hz'] != null) 'frameRateHz': _number(o, 'hz'),
    if (o['sound'] != null) 'sound': _answer(o['sound']!),
    if (o['consent'] != null) 'statsConsent': _answer(o['consent']!),
  },
  'flash' => {'on': o['on'] != 'false'},
  'press' => {if (o['player'] != null) 'player': o['player']!, 'button': o['button'] ?? 'a'},
  'stream' => asObject(jsonDecode(o['json'] ?? '{}'), '--json'),
  _ => null,
};

/// A player to add: a nickname, a character, or one to remove.
Map<String, Object?> _playersBody(Map<String, String> o) {
  final colour = o['colour'];
  final accessory = o['accessory'];
  return {
    if (o['nickname'] != null) 'nickname': o['nickname']!,
    if (o['remove'] != null) 'remove': o['remove']!,
    if (colour != null || accessory != null)
      'character': {'colour': _number(o, 'colour', fallback: 1), 'accessory': accessory ?? 'cap'},
  };
}

/// A game to start, with the arena's and the puzzle's own settings.
Map<String, Object?> _startBody(Map<String, String> o) {
  final teams = {
    for (final pair in (o['teams'] ?? '').split(','))
      if (pair.contains('=')) pair.split('=').first: pair.split('=').last,
  };
  final settings = {
    if (o['chaos'] != null) 'chaos': o['chaos']!,
    if (o['robo'] != null) 'robo': o['robo']!,
    if (o['night'] != null) 'night': {'rounds': _number(o, 'night', fallback: 3)},
  };
  return {
    'game': o['game'] ?? 'arena',
    if (o['mode'] != null) 'mode': o['mode']!,
    if (o['map'] != null) 'map': o['map']!,
    if (o['puzzle'] != null) 'puzzle': o['puzzle']!,
    if (o['level'] != null) 'level': o['level']!,
    if (teams.isNotEmpty) 'teams': teams,
    if (settings.isNotEmpty) 'settings': settings,
  };
}

/// [value] as JSON: it has to be a JSON object, since the calls take one.
Map<String, Object?> asObject(Object? value, String name) {
  if (value is! Map<String, Object?>) throw UsageError('$name is a JSON object, like {"viewer": {"kind": "browser"}}');
  return value;
}

/// "yes"/"no"/"true"/"false" as a JSON boolean.
bool _answer(String value) => switch (value.toLowerCase()) {
  'yes' || 'true' || 'on' => true,
  'no' || 'false' || 'off' => false,
  _ => throw UsageError('"$value" is yes or no'),
};

int _number(Map<String, String> o, String name, {int fallback = 0}) =>
    o[name] == null ? fallback : int.tryParse(o[name]!) ?? (throw UsageError('--$name is a whole number'));

double _decimal(Map<String, String> o, String name) =>
    double.tryParse(o[name]!) ?? (throw UsageError('--$name is a number'));
