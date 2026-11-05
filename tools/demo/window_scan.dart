import 'dart:convert';
import 'dart:io';

/// One top-level window in [WindowScan.topmost] (tools/demo/windows.ps1).
class TopWindow {
  const TopWindow({
    required this.pid,
    required this.process,
    required this.title,
    required this.cls,
    required this.visible,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.z = 0,
  });

  final int pid;
  final String process;
  final String title;
  final String cls;
  final bool visible;
  final int left;
  final int top;
  final int right;
  final int bottom;

  /// Position in the z-order; 0 is the top of the desktop.
  final int z;

  int get width => right - left;
  int get height => bottom - top;
  String get rect => '$left,$top,${width}x$height';

  static TopWindow fromJson(Map<String, dynamic> raw) => TopWindow(
    pid: (raw['pid'] as num?)?.toInt() ?? 0,
    process: raw['process'] as String? ?? '?',
    title: raw['title'] as String? ?? '',
    cls: raw['cls'] as String? ?? '',
    visible: raw['visible'] as bool? ?? false,
    left: (raw['left'] as num?)?.toInt() ?? 0,
    top: (raw['top'] as num?)?.toInt() ?? 0,
    right: (raw['right'] as num?)?.toInt() ?? 0,
    bottom: (raw['bottom'] as num?)?.toInt() ?? 0,
    z: (raw['z'] as num?)?.toInt() ?? 0,
  );

  /// `PickerHost.exe` and friends: the host Windows shows its credential and
  /// firewall pickers in (the Nov 5, 2026 blocker).
  bool get isPickerHost => process.toLowerCase().contains('pickerhost');

  @override
  String toString() =>
      'pid $pid ${process.isEmpty ? '?' : process} '
      '"$title" [$cls] ${rect}${visible ? '' : ' hidden'}';
}

/// A WindowFromPoint answer over the TV window (`hitTest` in the scan).
class HitPoint {
  const HitPoint({required this.x, required this.y, required this.window});
  final int x;
  final int y;
  final TopWindow window;

  static HitPoint fromJson(Map<String, dynamic> raw) => HitPoint(
    x: (raw['x'] as num?)?.toInt() ?? 0,
    y: (raw['y'] as num?)?.toInt() ?? 0,
    window: TopWindow.fromJson(raw),
  );
}

/// What tools/demo/windows.ps1 printed.
class WindowScan {
  const WindowScan({
    required this.topmost,
    required this.hitTest,
    required this.tvPid,
    required this.foreground,
  });
  final List<TopWindow> topmost;
  final List<HitPoint> hitTest;
  final int tvPid;
  final TopWindow? foreground;

  static WindowScan fromJson(Map<String, dynamic> raw) => WindowScan(
    topmost: ((raw['topmost'] as List?) ?? const [])
        .map((e) => TopWindow.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    hitTest: ((raw['hitTest'] as List?) ?? const [])
        .map((e) => HitPoint.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    tvPid: (raw['tvPid'] as num?)?.toInt() ?? 0,
    foreground: raw['foreground'] is Map
        ? TopWindow.fromJson((raw['foreground'] as Map).cast<String, dynamic>())
        : null,
  );
}

/// The desktop's own windowless helpers, measured on this PC on Nov 5, 2026:
/// the IME and tooltip hosts, Explorer's staging/island windows, the taskbar and
/// the tray, and Razer Synapse's foreground monitor. They are topmost, most of
/// them invisible or 0x0, and they sit permanently at the top of the z-order,
/// yet they never take a click meant for an app. Anything that is not one of
/// these is reported, because that is exactly what the two "Windows Security"
/// pickers were.
const benignTopmostClasses = <String>{
  'IME',
  'MSCTFIME UI',
  'tooltips_class32',
  'ForegroundStaging',
  'ThumbnailDeviceHelperWnd',
  'SystemTray_Main',
  'Shell_TrayWnd',
  'XamlExplorerHostIslandWindow',
  'XamlExplorerHostIslandWindow_WASDK',
  'MozillaDropShadowWindowClass',
  'Wnd_StartFeed',
  'RzMonitorForegroundWindowClass',
  'Chrome_WidgetWin_1',
  'TMainForm',
};

/// Classes whose name carries a per-process suffix (`ATL:00007FFC…`,
/// `ListnerThreadUsbDetection_27740`).
const benignClassPrefixes = <String>['ATL:', 'ListnerThread'];

bool isBenignTopmost(TopWindow w) =>
    benignTopmostClasses.contains(w.cls) ||
    benignClassPrefixes.any(w.cls.startsWith);

/// The windows that would swallow a click meant for the TV app, or an empty
/// list when the desktop is clean (runbook 3.1).
///
/// A stray is a topmost window that is a picker host, or that has no pixels to
/// show (invisible or 0x0) and is not one of the desktop's own helpers. The
/// second half is the exact signature of the Nov 5, 2026 block: two
/// `PickerHost.exe` "Windows Security" windows, visible, rect 0,0,0,0, topmost,
/// holding the foreground — every click went to them and the TV app never saw
/// one, and nothing about it looked wrong on screen.
List<String> findStrayWindows(List<TopWindow> windows) {
  final strays = <String>[];
  for (final w in windows) {
    if (w.isPickerHost) {
      strays.add('${w.toString()} is a picker host');
      continue;
    }
    final empty = w.width <= 0 || w.height <= 0;
    if ((!w.visible || empty) && !isBenignTopmost(w)) {
      strays.add(
        '${w.toString()} is ${empty ? '0x0' : 'invisible'} and topmost',
      );
    }
  }
  return strays;
}

/// A hit test that landed on a window which cannot be showing anything: a
/// picker host, or an invisible/0x0 window. An ordinary window on top of the TV
/// app (the emulator, this harness) is not an error here: the click path brings
/// the TV window to the front before it clicks (tools/demo/tv.ps1).
List<String> findBlockedPoints(List<HitPoint> points) {
  final blocked = <String>[];
  for (final p in points) {
    final w = p.window;
    final empty = w.width <= 0 || w.height <= 0;
    if (w.isPickerHost || !w.visible || empty) {
      blocked.add(
        'the click point ${p.x},${p.y} belongs to ${w.toString()}'
        '${w.isPickerHost ? ' (a picker host)' : ''}',
      );
    }
  }
  return blocked;
}

/// Every reason this desktop would lose a click, ready to print; empty is good.
List<String> windowProblems(WindowScan scan) => [
  ...findStrayWindows(scan.topmost),
  ...findBlockedPoints(scan.hitTest),
];

/// Runs tools/demo/windows.ps1 and returns what it saw.
///
/// Read-only: nothing is closed, moved or hidden. [repo] is the repository root.
Future<WindowScan> scanWindows(String repo) async {
  final script = '$repo\\tools\\demo\\windows.ps1';
  if (!File(script).existsSync()) {
    throw StateError('no window scanner at $script');
  }
  final result = await Process.run('powershell', [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    script,
  ], stdoutEncoding: utf8);
  if (result.exitCode != 0) {
    throw StateError(
      'the window scan failed (${result.exitCode}): ${result.stderr}',
    );
  }
  final text = (result.stdout as String).trim();
  if (text.isEmpty) throw StateError('the window scan printed nothing');
  return WindowScan.fromJson((jsonDecode(text) as Map).cast<String, dynamic>());
}

/// `dart run tools/demo/window_scan.dart --self-test`, and the showrunner's own
/// self-test: a faked window list for the Nov 5, 2026 case, the shell's own
/// helpers, and the hit test.
void windowScanSelfTest(void Function(String what, bool pass) check) {
  TopWindow window({
    int pid = 100,
    String process = 'app',
    String title = '',
    String cls = 'SomeWindow',
    bool visible = true,
    int w = 1920,
    int h = 1080,
    int z = 0,
  }) => TopWindow(
    pid: pid,
    process: process,
    title: title,
    cls: cls,
    visible: visible,
    left: 0,
    top: 0,
    right: w,
    bottom: h,
    z: z,
  );

  // The blocker exactly as it was: PickerHost, visible, 0x0, topmost.
  final picker = window(
    pid: 20228,
    process: 'PickerHost',
    title: 'Windows Security',
    cls: 'CredentialPickerWindow',
    w: 0,
    h: 0,
  );
  final strays = findStrayWindows([picker]);
  check(
    'the Nov 5 picker window is a stray: ${strays.join(' / ')}',
    strays.length == 1 &&
        strays.single.contains('20228') &&
        strays.single.contains('PickerHost') &&
        strays.single.contains('Windows Security'),
  );
  check(
    'a picker host is a stray even with a normal rect',
    findStrayWindows([window(process: 'PickerHost', title: 'Windows Security')])
            .length ==
        1,
  );

  // The shell's own topmost helpers are not strays: measured on this PC.
  final helpers = [
    window(
      pid: 14012,
      process: 'explorer',
      cls: 'IME',
      visible: false,
      w: 0,
      h: 0,
    ),
    window(
      pid: 14012,
      process: 'explorer',
      cls: 'MSCTFIME UI',
      visible: false,
      w: 0,
      h: 0,
    ),
    window(
      pid: 14012,
      process: 'explorer',
      cls: 'tooltips_class32',
      visible: false,
      w: 0,
      h: 0,
    ),
    window(
      pid: 14012,
      process: 'explorer',
      cls: 'ForegroundStaging',
      visible: false,
      w: 0,
      h: 0,
    ),
    window(
      pid: 14012,
      process: 'explorer',
      cls: 'ThumbnailDeviceHelperWnd',
      w: 1,
      h: 1,
    ),
    window(
      pid: 14012,
      process: 'explorer',
      cls: 'Shell_TrayWnd',
      w: 1920,
      h: 48,
    ),
    window(
      pid: 14012,
      process: 'explorer',
      cls: 'XamlExplorerHostIslandWindow',
      visible: false,
      w: 1920,
      h: 1032,
    ),
    window(
      pid: 14012,
      process: 'explorer',
      cls: 'XamlExplorerHostIslandWindow_WASDK',
      w: 0,
      h: 0,
    ),
    window(
      pid: 28284,
      process: 'RazerAppEngine',
      cls: 'RzMonitorForegroundWindowClass',
      w: 0,
      h: 0,
    ),
    window(
      pid: 14012,
      process: 'explorer',
      cls: 'ATL:00007FFC8EBAA050',
      visible: false,
      w: 0,
      h: 0,
    ),
  ];
  check(
    'the desktop\'s own helpers are not strays: '
    '${findStrayWindows(helpers).length} found',
    findStrayWindows(helpers).isEmpty,
  );

  // A new invisible topmost window from a program that is not in the list.
  final unknown = window(
    pid: 4242,
    process: 'SomeHelper',
    title: 'Hidden tool',
    cls: 'FancyOverlay',
    visible: false,
    w: 0,
    h: 0,
  );
  final unknownStrays = findStrayWindows([unknown]);
  check(
    'an unknown invisible topmost window is a stray: '
    '${unknownStrays.join(' / ')}',
    unknownStrays.length == 1 && unknownStrays.single.contains('4242'),
  );
  check(
    'a normal window is never a stray',
    findStrayWindows([
      window(
        process: 'ThumbPartyTV',
        title: 'Thumb Party TV',
        cls: 'FLUTTER_RUNNER_WIN32_WINDOW',
      ),
    ]).isEmpty,
  );

  // The hit test: the TV app owning its own pixels is fine, even with the
  // emulator and this harness on top of it; an impossible owner is not.
  final tv = window(
    pid: 36264,
    process: 'ThumbPartyTV',
    title: 'Thumb Party TV',
    cls: 'FLUTTER_RUNNER_WIN32_WINDOW',
  );
  final emulator = window(
    pid: 32952,
    process: 'qemu-system-x86_64',
    cls: 'Qt653QWindowIcon',
    w: 930,
    h: 450,
  );
  final good = [
    HitPoint(x: 192, y: 108, window: emulator),
    HitPoint(x: 960, y: 540, window: tv),
    HitPoint(x: 1728, y: 972, window: tv),
  ];
  check(
    'an ordinary window on top of the TV app is not a blocker',
    findBlockedPoints(good).isEmpty,
  );
  final blocked = [...good, HitPoint(x: 1063, y: 666, window: picker)];
  final problems = findBlockedPoints(blocked);
  check(
    'a click point owned by the picker is a blocker: ${problems.join(' / ')}',
    problems.length == 1 &&
        problems.single.contains('1063,666') &&
        problems.single.contains('PickerHost'),
  );
  final hiddenOwner = window(
    pid: 777,
    process: 'ghost',
    cls: 'Ghost',
    visible: false,
    w: 0,
    h: 0,
  );
  check(
    'a click point owned by an invisible window is a blocker',
    findBlockedPoints([HitPoint(x: 10, y: 10, window: hiddenOwner)]).length ==
        1,
  );
}

/// Prints PASS or FAIL for each case; true only when all of them pass.
bool selfTest() {
  var ok = true;
  windowScanSelfTest((what, pass) {
    stdout.writeln('${pass ? 'PASS' : 'FAIL'}  $what');
    if (!pass) ok = false;
  });
  return ok;
}

void main(List<String> args) async {
  if (args.contains('--self-test')) {
    final ok = selfTest();
    stdout.writeln(
      ok ? 'window scan self-test: PASS' : 'window scan self-test: FAIL',
    );
    exit(ok ? 0 : 1);
  }
  final repo = Directory.current.path;
  final scan = await scanWindows(repo);
  stdout.writeln('tv pid ${scan.tvPid}, foreground ${scan.foreground}');
  stdout.writeln(
    '${scan.topmost.length} topmost windows, ${scan.hitTest.length} hit points',
  );
  final problems = windowProblems(scan);
  if (problems.isEmpty) {
    stdout.writeln('no stray windows');
  } else {
    for (final problem in problems) {
      stdout.writeln('STRAY  $problem');
    }
  }
}
