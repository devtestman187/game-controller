// Prints one web page as plain text, with its links in [brackets], for the
// flash worker's research jobs (tools/flash.sh --web copies it into the job's
// folder as fetch.dart).
//
//   dart fetch.dart <http(s) URL>
//
// Refused: other schemes, local and private addresses (this PC, the home
// network's TVs and phones), URLs that look like they carry a key, and pages
// that aren't text. At most 2 MB is read and 200,000 characters printed.
import 'dart:convert';
import 'dart:io';

const _maxBytes = 2 * 1024 * 1024;
const _maxChars = 200000;
const _maxRedirects = 5;

Future<void> main(List<String> args) async {
  if (args.length != 1) _refuse('usage: dart fetch.dart <http(s) URL>');
  var uri = _check(args.single);
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = 'ThumbPartyResearch/1.0';
  try {
    for (var hop = 0; ; hop++) {
      await _checkHost(uri);
      final request = await client.getUrl(uri)
        ..followRedirects = false
        ..headers.set(HttpHeaders.acceptHeader, 'text/html, text/plain, application/json;q=0.9, */*;q=0.1');
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.isRedirect) {
        await response.drain<void>();
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || hop >= _maxRedirects) _refuse('too many redirects, or one without a location');
        uri = _check(uri.resolve(location).toString());
        continue;
      }
      final type = response.headers.contentType;
      final mime = type?.mimeType ?? 'text/html';
      final text = mime.startsWith('text/') || mime.contains('json') || mime.contains('xml');
      if (!text) {
        await response.drain<void>();
        _refuse('not a text page ($mime): ${uri.toString()}');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length >= _maxBytes) break;
      }
      final body = utf8.decode(bytes, allowMalformed: true);
      var out = mime == 'text/html' || mime.contains('xhtml') ? _htmlToText(body) : body;
      if (out.length > _maxChars) out = '${out.substring(0, _maxChars)}\n\n[cut at $_maxChars characters]';
      stdout.writeln('URL: $uri (HTTP ${response.statusCode})\n');
      stdout.writeln(out);
      return;
    }
  } on SocketException catch (e) {
    _refuse('could not connect: ${e.message}');
  } on HttpException catch (e) {
    _refuse('HTTP error: ${e.message}');
  } on Exception catch (e) {
    _refuse('failed: $e');
  } finally {
    client.close(force: true);
  }
}

Never _refuse(String why) {
  stderr.writeln('fetch: $why');
  exit(2);
}

Uri _check(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
    _refuse('only http and https URLs');
  }
  final decoded = Uri.decodeFull(raw);
  if (RegExp(r'sk-[A-Za-z0-9_-]{8,}').hasMatch(decoded) || RegExp(r'[A-Za-z0-9_-]{48,}').hasMatch(uri.query)) {
    _refuse('the URL looks like it carries a key');
  }
  return uri;
}

/// Refuses this PC and the home network (the TVs, phones and router).
Future<void> _checkHost(Uri uri) async {
  final host = uri.host.toLowerCase();
  if (host == 'localhost' || host.endsWith('.local') || host.endsWith('.localhost') || host.endsWith('.lan')) {
    _refuse('local addresses are refused');
  }
  final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 10));
  for (final a in addresses) {
    if (a.isLoopback || a.isLinkLocal || a.isMulticast || _private(a))
      _refuse('local and private addresses are refused');
  }
}

bool _private(InternetAddress a) {
  final b = a.rawAddress;
  if (a.type == InternetAddressType.IPv4) {
    return b[0] == 10 ||
        b[0] == 0 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168) ||
        (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
  }
  return (b[0] & 0xFE) == 0xFC; // IPv6 unique local (fc00::/7)
}

String _htmlToText(String html) {
  var s = html.replaceAll(
    RegExp(r'<(script|style|noscript|svg|template|head)\b[^>]*>.*?</\1\s*>', caseSensitive: false, dotAll: true),
    ' ',
  );
  s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
  s = s.replaceAllMapped(
    RegExp(r'''<a\b[^>]*?href\s*=\s*["']([^"']*)["'][^>]*>(.*?)</a\s*>''', caseSensitive: false, dotAll: true),
    (m) {
      final label = m[2]!.replaceAll(RegExp(r'<[^>]+>'), ' ').trim();
      final href = _realLink(_entities(m[1]!));
      if (href.isEmpty || href.startsWith('#') || href.startsWith('javascript:')) return label;
      return label.isEmpty ? '[$href]' : '$label [$href]';
    },
  );
  s = s.replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '\n- ');
  s = s.replaceAll(
    RegExp(r'<(br|/p|/div|/h[1-6]|/tr|/li|/pre|/table|/section|/article)\b[^>]*>', caseSensitive: false),
    '\n',
  );
  s = s.replaceAll(RegExp(r'<h[1-6]\b[^>]*>', caseSensitive: false), '\n## ');
  s = s.replaceAll(RegExp(r'<(td|th)\b[^>]*>', caseSensitive: false), ' | ');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = _entities(s);
  final lines = s.split('\n').map((l) => l.replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ').trim());
  final out = StringBuffer();
  var blank = 0;
  for (final l in lines) {
    if (l.isEmpty) {
      if (++blank > 1) continue;
    } else {
      blank = 0;
    }
    out.writeln(l);
  }
  return out.toString().trim();
}

/// DuckDuckGo's result links go through a redirect: show where they lead.
String _realLink(String href) {
  final m = RegExp(r'[?&]uddg=([^&]+)').firstMatch(href);
  if (m == null) return href;
  try {
    return Uri.decodeComponent(m[1]!);
  } on FormatException {
    return href;
  }
}

String _entities(String s) => s
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');
