# Drives the demo (Profile) TV window for the showrunner: screenshots, clicks
# and keys. Same approach as tools/tv-window.ps1, but it finds the Profile
# build the showrunner starts (docs/demo-video-runbook.md 2.7).
#
#   tools/demo/tv.ps1 click 1353,36        # x,y from the window's top left
#   tools/demo/tv.ps1 key space            # press and release
#   tools/demo/tv.ps1 shot out.png
#   tools/demo/tv.ps1 find
param([string]$Action = '', [string]$Arg = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$exe = Join-Path $repo 'tv_test_app\build\windows\x64\runner\Profile\ThumbPartyTV.exe'
Add-Type -AssemblyName System.Drawing
if (-not ('DemoTv' -as [type])) {
  Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class DemoTv {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
}
$p = Get-Process ThumbPartyTV -ErrorAction SilentlyContinue |
  Where-Object { $_.Path -and ($_.Path -ieq $exe) -and $_.MainWindowHandle -ne 0 } |
  Select-Object -First 1
if (-not $p) { Write-Output "No demo TV window ($exe)."; exit 1 }
$h = $p.MainWindowHandle
function Rect { $r = New-Object DemoTv+RECT; [DemoTv]::GetWindowRect($h, [ref]$r) | Out-Null; $r }
function Front {
  [DemoTv]::ShowWindow($h, 9) | Out-Null
  for ($i = 0; $i -lt 6; $i++) {
    if ([DemoTv]::GetForegroundWindow() -eq $h) { Start-Sleep -Milliseconds 120; return $true }
    [DemoTv]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    [DemoTv]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [DemoTv]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 150
  }
  return ([DemoTv]::GetForegroundWindow() -eq $h)
}
function KeyCode([string]$k) {
  $named = @{ left = 0x25; up = 0x26; right = 0x27; down = 0x28; space = 0x20; enter = 0x0D; esc = 0x1B; tab = 0x09; backspace = 0x08 }
  if ($named.ContainsKey($k)) { return [byte]$named[$k] }
  if ($k -match '^[a-zA-Z0-9]$') { return [byte][char]$k.ToUpper() }
  throw "Unknown key '$k'"
}
function Click([int]$x, [int]$y) {
  if (-not (Front)) { throw 'the TV window did not come to the front' }
  $r = Rect
  [DemoTv]::SetCursorPos($r.L + $x, $r.T + $y) | Out-Null
  Start-Sleep -Milliseconds 400
  [DemoTv]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 80
  [DemoTv]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 500
}
trap { Write-Output "tv: $($_.Exception.Message)"; exit 2 }
switch ($Action) {
  'find' { Write-Output $p.Id }
  'click' { $x, $y = $Arg -split ','; Click ([int]$x) ([int]$y); Write-Output "clicked $Arg" }
  'key' {
    if (-not (Front)) { throw 'the TV window did not come to the front' }
    $c = KeyCode $Arg
    [DemoTv]::keybd_event($c, 0, 1, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [DemoTv]::keybd_event($c, 0, 3, [UIntPtr]::Zero); Start-Sleep -Milliseconds 200
    Write-Output "key $Arg"
  }
  'shot' {
    $r = Rect
    $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
    [DemoTv]::PrintWindow($h, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc); $g.Dispose()
    $bmp.Save($Arg, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Output "saved $Arg"
  }
  default { throw "Unknown action '$Action'. Actions: click, key, shot, find" }
}
