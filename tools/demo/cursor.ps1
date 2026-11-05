# Hides the Windows pointer while a take records, then puts it back.
#
# Why: the TV app runs borderless full screen, so the pointer is always over the
# window, and OBS's window capture composites it into the TV half even with
# `capture_cursor` false (measured Nov 5, 2026: M1 take 12 and M3 takes 4 and 6
# all show the white arrow while the OBS setting reads false). 2.8's cursor
# check and P1's "no cursor" rule therefore need the pointer gone from the
# picture itself.
#
#   tools/demo/cursor.ps1 hide        # blank the pointer (fast, exits)
#   tools/demo/cursor.ps1 show        # restore the owner's cursor scheme
#   tools/demo/cursor.ps1 watchdog N  # sleep N s, then restore
#
# The showrunner runs `hide`, starts `watchdog` detached, records, then runs
# `show`. The watchdog is the safety net: if the showrunner crashes mid-take the
# owner still gets a pointer back after N seconds. The owner's scheme is
# reloaded with SystemParametersInfo(SPI_SETCURSORS) - the same call Windows
# makes when the mouse settings change - so nothing is written to the registry.
param([string]$Action = '', [int]$Seconds = 300)
$ErrorActionPreference = 'Stop'
if (-not ('DemoCursor' -as [type])) {
  Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class DemoCursor {
  [DllImport("user32.dll")] public static extern IntPtr CreateCursor(IntPtr hInst, int xHot, int yHot, int w, int h, IntPtr andPlane, IntPtr xorPlane);
  [DllImport("user32.dll", SetLastError = true)] public static extern bool SetSystemCursor(IntPtr hcur, uint id);
  [DllImport("user32.dll", SetLastError = true)] public static extern bool SystemParametersInfo(uint action, uint param, IntPtr pv, uint winIni);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
}
"@
}

# A 32x32 cursor that draws nothing: the AND mask all ones (keep the screen),
# the XOR mask zero (invert nothing).
#
# Both masks zero - the first version - does NOT hide the pointer: it paints a
# solid 32x32 BLACK square at the hotspot. Windows composites a monochrome
# cursor as "screen AND mask, then XOR mask", so AND=0 blackens every pixel of
# the cursor's box. The desktop looks right, but OBS's window capture writes the
# square into the footage (measured Nov 5, 2026: M1 take 1 has it at 616,157,
# exactly where the last TV click left the pointer).
function BlankCursor {
  $and = New-Object byte[] 128
  for ($i = 0; $i -lt 128; $i++) { $and[$i] = 0xFF }
  $xor = New-Object byte[] 128
  $pa = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(128)
  $px = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(128)
  try {
    [System.Runtime.InteropServices.Marshal]::Copy($and, 0, $pa, 128)
    [System.Runtime.InteropServices.Marshal]::Copy($xor, 0, $px, 128)
    return [DemoCursor]::CreateCursor([IntPtr]::Zero, 0, 0, 32, 32, $pa, $px)
  } finally {
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($pa)
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($px)
  }
}

# Every system cursor the pointer can be (OCR_* ids). SetSystemCursor takes
# ownership of the handle, so each id gets its own blank cursor.
$ids = @(32512, 32513, 32514, 32515, 32516, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650)
$tokenFile = Join-Path $env:TEMP 'thumbparty-cursor-hide.token'
function HidePointer {
  # Park on the black margin left of the home panels. A button under the
  # pointer can put its own cursor back (Flutter's hover cursor), which is why
  # P3 take 2 still showed the arrow over "Drop connections" (Nov 5, 2026).
  [DemoCursor]::SetCursorPos(8, [int]([DemoCursor]::GetSystemMetrics(1) / 2)) | Out-Null
  Start-Sleep -Milliseconds 200
  foreach ($id in $ids) {
    $h = BlankCursor
    if ($h -eq [IntPtr]::Zero) { throw "CreateCursor failed for id $id" }
    if (-not [DemoCursor]::SetSystemCursor($h, [uint32]$id)) { throw "SetSystemCursor failed for id $id" }
  }
}
function ShowPointer {
  # SPI_SETCURSORS (0x57) with SPIF_SENDCHANGE: reload the owner's scheme.
  if (-not [DemoCursor]::SystemParametersInfo(0x57, 0, [IntPtr]::Zero, 2)) {
    throw 'SystemParametersInfo(SPI_SETCURSORS) failed'
  }
  Remove-Item $tokenFile -ErrorAction SilentlyContinue
}

switch ($Action) {
  'hide' {
    # The token must exist before the cursor is hidden: a watchdog covers the
    # case where this process dies before the matching `show`.
    Set-Content -Path $tokenFile -Value ([guid]::NewGuid().ToString()) -NoNewline
    HidePointer
    Write-Output 'cursor: pointer hidden'
    break
  }
  'show' {
    ShowPointer
    Write-Output 'cursor: pointer restored'
    break
  }
  'watchdog' {
    # Restore only if no newer take has hidden the pointer since this watchdog
    # started. Otherwise a take longer than N seconds shows the arrow again
    # halfway through the next take.
    $token = if (Test-Path $tokenFile) { Get-Content $tokenFile -Raw } else { '' }
    try {
      Start-Sleep -Seconds $Seconds
    } finally {
      $now = if (Test-Path $tokenFile) { Get-Content $tokenFile -Raw } else { '' }
      if ($token -and $now -eq $token) {
        ShowPointer
        Write-Output 'cursor: pointer restored (watchdog)'
      } else {
        Write-Output 'cursor: a newer hide is active; watchdog left it alone'
      }
    }
    break
  }
  default { throw "usage: cursor.ps1 hide | show | watchdog <seconds>" }
}
