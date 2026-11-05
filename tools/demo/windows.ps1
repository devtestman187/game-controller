# Scans the desktop for windows that would swallow a click meant for the demo
# TV window (docs/demo-video-runbook.md 3.1, and the Nov 5, 2026 block, where
# two invisible topmost "Windows Security" PickerHost.exe windows owned the
# foreground and every click went to them).
#
# Prints one JSON object:
#   topmost: every top-level window with WS_EX_TOPMOST, in z-order (index 0 is
#            the top of the z-order, which is how EnumWindows enumerates), with
#            pid, process, title, class and rect;
#   hitTest: what WindowFromPoint answers at a 3x3 grid over the demo TV window,
#            so the caller can prove the TV window owns its own pixels;
#   tvPid:   the demo TV's pid, or 0 when it is not running.
#
# Read-only: it never closes, moves or hides anything.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/demo/windows.ps1
param()
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class WinScan2 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr GetWindowLongPtrW(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  public static List<IntPtr> ZOrder() {
    var list = new List<IntPtr>();
    EnumWindows((h, l) => { list.Add(h); return true; }, IntPtr.Zero);
    return list;
  }
}
"@
function ProcName([uint32]$procId) {
  $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
  if ($p) { return $p.ProcessName }
  return '?'
}
function Describe([IntPtr]$h) {
  $sb = New-Object System.Text.StringBuilder 512
  [WinScan2]::GetWindowTextW($h, $sb, 512) | Out-Null
  $cb = New-Object System.Text.StringBuilder 256
  [WinScan2]::GetClassNameW($h, $cb, 256) | Out-Null
  $r = New-Object WinScan2+RECT
  [WinScan2]::GetWindowRect($h, [ref]$r) | Out-Null
  $procId = 0
  [WinScan2]::GetWindowThreadProcessId($h, [ref]$procId) | Out-Null
  [pscustomobject]@{
    pid     = [int]$procId
    process = (ProcName $procId)
    title   = $sb.ToString()
    cls     = $cb.ToString()
    visible = [WinScan2]::IsWindowVisible($h)
    iconic  = [WinScan2]::IsIconic($h)
    left    = $r.L
    top     = $r.T
    right   = $r.R
    bottom  = $r.B
  }
}
$topmost = New-Object System.Collections.ArrayList
$index = 0
foreach ($h in [WinScan2]::ZOrder()) {
  $ex = [WinScan2]::GetWindowLongPtrW($h, -20).ToInt64()
  $isTop = ($ex -band 0x8) -ne 0
  $d = Describe $h
  if ($isTop) {
    $d | Add-Member -NotePropertyName topmost -NotePropertyValue $true
    $d | Add-Member -NotePropertyName z -NotePropertyValue $index
    [void]$topmost.Add($d)
  }
  $index++
}
# The demo TV window (the Profile build tv.ps1 also drives).
$tvPid = 0
$tv = Get-Process ThumbPartyTV -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$points = New-Object System.Collections.ArrayList
if ($tv) {
  $tvPid = $tv.Id
  $r = New-Object WinScan2+RECT
  [WinScan2]::GetWindowRect($tv.MainWindowHandle, [ref]$r) | Out-Null
  $w = $r.R - $r.L
  $hgt = $r.B - $r.T
  foreach ($fx in 0.1, 0.5, 0.9) {
    foreach ($fy in 0.1, 0.5, 0.9) {
      $pt = New-Object WinScan2+POINT
      $pt.X = [int]($r.L + $w * $fx)
      $pt.Y = [int]($r.T + $hgt * $fy)
      $hit = [WinScan2]::WindowFromPoint($pt)
      $root = [WinScan2]::GetAncestor($hit, 2)
      $d = Describe $root
      $d | Add-Member -NotePropertyName x -NotePropertyValue $pt.X
      $d | Add-Member -NotePropertyName y -NotePropertyValue $pt.Y
      [void]$points.Add($d)
    }
  }
}
$fg = [WinScan2]::GetForegroundWindow()
$fgd = Describe $fg
[pscustomobject]@{
  topmost = @($topmost)
  hitTest = @($points)
  tvPid   = [int]$tvPid
  foreground = $fgd
} | ConvertTo-Json -Depth 6 -Compress
