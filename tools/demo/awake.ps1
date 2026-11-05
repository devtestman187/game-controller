# Keeps the PC awake for a capture block (docs/demo-video-runbook.md 3.1).
#
# Why: at 08:0x on Nov 5, 2026 the session locked while a block was between
# takes. A locked session is not just an inconvenience: OBS's window capture
# then records a black frame (CUR_take2_tv.mkv is 1920x1080, 60 fps and every
# frame black) and nothing that needs a click or a key can run, because the
# lock screen owns the foreground. QA cannot see this - a black take passes
# every 2.8 rule - so the block is simply wasted.
#
#   tools/demo/awake.ps1 [minutes]   # default 240; Start-Process it detached
#
# SetThreadExecutionState(ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED) resets the
# idle timer, so the display does not sleep and the screen saver (and with it
# the auto-lock) does not start while the helper runs. Nothing is written to
# the registry; closing the process ends the request.
param([int]$Minutes = 240)
$ErrorActionPreference = 'Stop'
if (-not ('DemoAwake' -as [type])) {
  Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class DemoAwake {
  [DllImport("kernel32.dll", SetLastError = true)] public static extern uint SetThreadExecutionState(uint flags);
}
"@
}
$ES_SYSTEM_REQUIRED = 0x00000001
$ES_DISPLAY_REQUIRED = 0x00000002
$flags = $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED
$until = (Get-Date).AddMinutes($Minutes)
try {
  while ((Get-Date) -lt $until) {
    if ([DemoAwake]::SetThreadExecutionState($flags) -eq 0) { throw 'SetThreadExecutionState failed' }
    Start-Sleep -Seconds 30
  }
} finally {
  [DemoAwake]::SetThreadExecutionState(0x80000000) | Out-Null # ES_CONTINUOUS off
}
