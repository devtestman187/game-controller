# Drives the development copy of the TV app's window on Windows: screenshots,
# clicks and keys. Only the window of THIS repository's debug build
# (tv_test_app\build\windows\x64\runner\Debug\ThumbPartyTV.exe), never a release
# copy someone is using. Documented in docs/dev-tools.md.
#
#   tools\tv-window.ps1 shot  out.png          # the whole window, even if covered
#   tools\tv-window.ps1 click 707,67           # x,y from the window's top left (as in the screenshot)
#   tools\tv-window.ps1 key   space            # press and release (keys below)
#   tools\tv-window.ps1 hold  right 900        # hold for 900 ms; several keys: right+space
#   tools\tv-window.ps1 find                   # the process ID, or exit code 1
#
# Keys: left right up down space enter esc tab backspace, a to z, 0 to 9.
# Windows PowerShell 5.1 or PowerShell 7. If scripts are blocked, run it as
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\tv-window.ps1 ...
param([string]$Action = '', [string]$Arg = '', [int]$Ms = 80)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $repo 'tv_test_app\build\windows\x64\runner\Debug\ThumbPartyTV.exe'

Add-Type -AssemblyName System.Drawing
if (-not ('TvWindow' -as [type])) {
  Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class TvWindow {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
}

if ($Action -eq '' -or $Action -eq 'help') {
  Get-Content $PSCommandPath | Select-Object -Skip 1 -First 14 | ForEach-Object { $_ -replace '^# ?', '' }
  exit 0
}

$p = Get-Process ThumbPartyTV -ErrorAction SilentlyContinue |
  Where-Object { $_.Path -and ($_.Path -ieq $exe) -and $_.MainWindowHandle -ne 0 } |
  Select-Object -First 1
if (-not $p) {
  Write-Output "No development TV window ($exe). Start it with tools/tv-dev.sh start."
  exit 1
}
$h = $p.MainWindowHandle

function Front { [TvWindow]::ShowWindow($h, 9) | Out-Null; [TvWindow]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 150 }
function Rect { $r = New-Object TvWindow+RECT; [TvWindow]::GetWindowRect($h, [ref]$r) | Out-Null; $r }
function KeyCode([string]$k) {
  $named = @{ left = 0x25; up = 0x26; right = 0x27; down = 0x28; space = 0x20; enter = 0x0D; esc = 0x1B; tab = 0x09; backspace = 0x08 }
  if ($named.ContainsKey($k)) { return [byte]$named[$k] }
  if ($k -match '^[a-zA-Z0-9]$') { return [byte][char]$k.ToUpper() }
  throw "Unknown key '$k'. Keys: $($named.Keys -join ' '), a-z, 0-9"
}
function Hold([string]$keys, [int]$ms) {
  $codes = @($keys -split '\+' | ForEach-Object { KeyCode $_ })
  Front
  foreach ($c in $codes) { [TvWindow]::keybd_event($c, 0, 1, [UIntPtr]::Zero) }
  Start-Sleep -Milliseconds $ms
  foreach ($c in $codes) { [TvWindow]::keybd_event($c, 0, 3, [UIntPtr]::Zero) }
}

trap {
  # A short message instead of PowerShell's error record.
  Write-Output "tv-window: $($_.Exception.Message)"
  exit 2
}

switch ($Action) {
  'find' { Write-Output $p.Id }
  'shot' {
    if ($Arg -eq '') { throw 'Give a file name: shot out.png' }
    $file = if ([System.IO.Path]::IsPathRooted($Arg)) { $Arg } else { Join-Path (Get-Location) $Arg }
    $r = Rect
    $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
    # 2 = PW_RENDERFULLCONTENT: works for Flutter's GPU-drawn window, even when covered.
    [TvWindow]::PrintWindow($h, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc); $g.Dispose()
    $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Output "saved $file ($($r.R - $r.L)x$($r.B - $r.T))"
  }
  'click' {
    $x, $y = $Arg -split ','
    $r = Rect
    Front
    [TvWindow]::SetCursorPos($r.L + [int]$x, $r.T + [int]$y) | Out-Null
    [TvWindow]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60
    [TvWindow]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
    Write-Output "clicked $Arg"
  }
  'key' { Hold $Arg 80; Write-Output "pressed $Arg" }
  'hold' { Hold $Arg $Ms; Write-Output "held $Arg $Ms ms" }
  default { throw "Unknown action '$Action'. Actions: shot, click, key, hold, find" }
}
