# Generates every icon, banner and store graphic for Thumb Party and Thumb Party TV
# (PRD v2 M8), so the artwork can be remade or tweaked without an image editor.
# Everything is drawn here with System.Drawing: no third-party content (CC0, see assets/CREDITS.md).
#
#   powershell -ExecutionPolicy Bypass -File tools\branding\make-artwork.ps1
#
# Writes the masters to assets/branding/ and copies the platform sizes into the apps.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$out = Join-Path $root 'assets\branding'
New-Item -ItemType Directory -Force $out | Out-Null

function Color([string]$hex, [int]$alpha = 255) {
  $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
  [System.Drawing.Color]::FromArgb($alpha, $c.R, $c.G, $c.B)
}

$navyTop = Color '#22305A'
$navyBottom = Color '#0E1424'
$tvTop = Color '#3A2466'
$tvBottom = Color '#140E26'
$buttons = @(
  @{ dx = 0; dy = -1; color = '#FDD835' },  # Y
  @{ dx = -1; dy = 0; color = '#1E88E5' },  # X
  @{ dx = 1; dy = 0; color = '#E53935' },   # B
  @{ dx = 0; dy = 1; color = '#4CAF50' }    # A
)

function New-Canvas([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'
  $g.TextRenderingHint = 'AntiAliasGridFit'
  return @($bmp, $g)
}

function Fill-Background($g, [int]$w, [int]$h, $top, $bottom, [double]$corner = 0) {
  $rect = New-Object System.Drawing.RectangleF 0, 0, $w, $h
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $top, $bottom, 90
  if ($corner -gt 0) {
    $path = Rounded-Rect 0 0 $w $h $corner
    $g.FillPath($brush, $path)
  } else {
    $g.FillRectangle($brush, $rect)
  }
}

function Rounded-Rect([double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2 * $r
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

# The mark: A, B, X and Y in a diamond, centred on (cx, cy), fitting a square of side s.
function Draw-Mark($g, [double]$cx, [double]$cy, [double]$s) {
  $r = $s * 0.19
  $d = $s * 0.29
  foreach ($b in $buttons) {
    $x = $cx + $b.dx * $d
    $y = $cy + $b.dy * $d
    $shadow = New-Object System.Drawing.SolidBrush (Color '#000000' 70)
    $g.FillEllipse($shadow, $x - $r, $y - $r + $s * 0.025, 2 * $r, 2 * $r)
    $fill = New-Object System.Drawing.SolidBrush (Color $b.color)
    $g.FillEllipse($fill, $x - $r, $y - $r, 2 * $r, 2 * $r)
    $shine = New-Object System.Drawing.SolidBrush (Color '#FFFFFF' 85)
    $g.FillEllipse($shine, $x - $r * 0.55, $y - $r * 0.7, $r * 0.7, $r * 0.45)
  }
}

# A few bits of confetti around the mark ("party").
function Draw-Confetti($g, [double]$cx, [double]$cy, [double]$s) {
  $bits = @(
    @{ x = -0.40; y = -0.36; a = 25; c = '#FF80AB' },
    @{ x = 0.40; y = -0.34; a = -30; c = '#80D8FF' },
    @{ x = 0.38; y = 0.40; a = 40; c = '#FFFFFF' },
    @{ x = -0.41; y = 0.36; a = -15; c = '#B9F6CA' }
  )
  foreach ($b in $bits) {
    $state = $g.Save()
    $g.TranslateTransform($cx + $b.x * $s, $cy + $b.y * $s)
    $g.RotateTransform($b.a)
    $brush = New-Object System.Drawing.SolidBrush (Color $b.c 230)
    $w = $s * 0.075
    $h = $s * 0.03
    $g.FillPath($brush, (Rounded-Rect (-$w / 2) (-$h / 2) $w $h ($h / 2)))
    $g.Restore($state)
  }
}

# A TV screen outline around the mark, for Thumb Party TV.
function Draw-Screen($g, [double]$cx, [double]$cy, [double]$s) {
  $pen = New-Object System.Drawing.Pen (Color '#FFFFFF' 235), ($s * 0.045)
  $w = $s * 0.92
  $h = $s * 0.70
  $g.DrawPath($pen, (Rounded-Rect ($cx - $w / 2) ($cy - $h / 2 - $s * 0.05) $w $h ($s * 0.08)))
  $g.FillRectangle((New-Object System.Drawing.SolidBrush (Color '#FFFFFF' 235)), $cx - $s * 0.16, $cy + $h / 2 + $s * 0.0, $s * 0.32, $s * 0.045)
}

# UTF-8 without a byte-order mark (Android's resource compiler wants plain XML).
function Write-Utf8([string]$path, [string]$text) {
  [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
}

function Save-Png($bmp, [string]$path) {
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

# A square icon. $kind: 'app' or 'tv'. $style: 'full' (opaque square, iOS and Play), 'rounded'
# (legacy Android launcher), 'foreground' (transparent, mark only, adaptive icon layer).
function Make-Icon([string]$kind, [int]$size, [string]$style) {
  $bmp, $g = New-Canvas $size $size
  $top = if ($kind -eq 'tv') { $tvTop } else { $navyTop }
  $bottom = if ($kind -eq 'tv') { $tvBottom } else { $navyBottom }
  if ($style -eq 'full') { Fill-Background $g $size $size $top $bottom }
  if ($style -eq 'rounded') { Fill-Background $g $size $size $top $bottom ($size * 0.18) }
  # The adaptive icon's safe zone is the middle 66%.
  $markSize = if ($style -eq 'foreground') { $size * 0.50 } else { $size * 0.72 }
  $c = $size / 2
  if ($kind -eq 'tv') {
    Draw-Screen $g $c $c $markSize
    Draw-Mark $g $c ($c - $markSize * 0.05) ($markSize * 0.62)
  } else {
    Draw-Confetti $g $c $c $markSize
    Draw-Mark $g $c $c ($markSize * 0.92)
  }
  $g.Dispose()
  return $bmp
}

# A wide graphic with the mark on the left and the name on the right.
function Make-Wide([string]$kind, [int]$w, [int]$h, [string]$title, [string]$subtitle) {
  $bmp, $g = New-Canvas $w $h
  $top = if ($kind -eq 'tv') { $tvTop } else { $navyTop }
  $bottom = if ($kind -eq 'tv') { $tvBottom } else { $navyBottom }
  Fill-Background $g $w $h $top $bottom
  $mark = [math]::Min($h * 0.72, $w * 0.30)
  $mx = $w * 0.05 + $mark / 2
  Draw-Confetti $g $mx ($h / 2) $mark
  Draw-Mark $g $mx ($h / 2) ($mark * 0.92)
  $textX = $mx + $mark * 0.62
  $room = $w - $textX - $w * 0.05
  # The biggest title that fits beside the mark.
  $fontPx = $h * 0.17
  do {
    $titleFont = New-Object System.Drawing.Font 'Segoe UI', $fontPx, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $titleSize = $g.MeasureString($title, $titleFont)
    $fontPx *= 0.95
  } while ($titleSize.Width -gt $room)
  $white = New-Object System.Drawing.SolidBrush (Color '#FFFFFF')
  $titleY = $h / 2 - $titleSize.Height * 0.85
  if ($subtitle) {
    $subFont = New-Object System.Drawing.Font 'Segoe UI', ($titleFont.Size * 0.44), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawString($title, $titleFont, $white, $textX, $titleY)
    $g.DrawString($subtitle, $subFont, (New-Object System.Drawing.SolidBrush (Color '#9EC9FF')), $textX + $h * 0.01, $titleY + $titleSize.Height * 0.95)
  } else {
    $g.DrawString($title, $titleFont, $white, $textX, $h / 2 - $titleSize.Height / 2)
  }
  $g.Dispose()
  return $bmp
}

function Resize($bmp, [int]$size) {
  $small, $g = New-Canvas $size $size
  $g.DrawImage($bmp, 0, 0, $size, $size)
  $g.Dispose()
  return $small
}

# Windows .ico with PNG frames (Vista and later).
function Save-Ico([string]$kind, [string]$path) {
  $sizes = @(16, 24, 32, 48, 64, 128, 256)
  $frames = foreach ($s in $sizes) {
    $bmp = Make-Icon $kind $s 'rounded'
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    , $ms.ToArray()
  }
  $fs = [System.IO.File]::Create($path)
  $bw = New-Object System.IO.BinaryWriter $fs
  $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
  $offset = 6 + 16 * $sizes.Count
  for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]
    $dim = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$frames[$i].Length); $bw.Write([uint32]$offset)
    $offset += $frames[$i].Length
  }
  foreach ($f in $frames) { $bw.Write($f) }
  $bw.Close()
}

# --- Masters -------------------------------------------------------------------------------
Save-Png (Make-Icon 'app' 1024 'full') (Join-Path $out 'icon-app-1024.png')
Save-Png (Make-Icon 'tv' 1024 'full') (Join-Path $out 'icon-tv-1024.png')
Save-Png (Make-Icon 'app' 512 'full') (Join-Path $out 'play-icon-app-512.png')
Save-Png (Make-Icon 'tv' 512 'full') (Join-Path $out 'play-icon-tv-512.png')
Save-Png (Make-Wide 'app' 1024 500 'Thumb Party' 'Play together on any screen') (Join-Path $out 'play-feature-app-1024x500.png')
Save-Png (Make-Wide 'tv' 1024 500 'Thumb Party TV' 'The big screen for Thumb Party') (Join-Path $out 'play-feature-tv-1024x500.png')
Save-Png (Make-Wide 'tv' 1280 720 'Thumb Party TV' $null) (Join-Path $out 'play-tv-banner-1280x720.png')
Save-Png (Make-Wide 'tv' 320 180 'Thumb Party TV' $null) (Join-Path $out 'tv_banner.png')

# --- Android launcher icons (legacy and adaptive) ------------------------------------------
$densities = @{ mdpi = 1.0; hdpi = 1.5; xhdpi = 2.0; xxhdpi = 3.0; xxxhdpi = 4.0 }
foreach ($app in @(@{ dir = 'controller_app'; kind = 'app'; bg = '#1A2440' }, @{ dir = 'tv_test_app'; kind = 'tv'; bg = '#271A47' })) {
  $res = Join-Path $root "$($app.dir)\android\app\src\main\res"
  foreach ($d in $densities.Keys) {
    $f = $densities[$d]
    Save-Png (Make-Icon $app.kind ([int](48 * $f)) 'rounded') (Join-Path $res "mipmap-$d\ic_launcher.png")
    Save-Png (Make-Icon $app.kind ([int](108 * $f)) 'foreground') (Join-Path $res "mipmap-$d\ic_launcher_foreground.png")
  }
  $any = Join-Path $res 'mipmap-anydpi-v26'
  New-Item -ItemType Directory -Force $any | Out-Null
  Write-Utf8 (Join-Path $any 'ic_launcher.xml') @'
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tools/branding/make-artwork.ps1. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'@
  New-Item -ItemType Directory -Force (Join-Path $res 'values') | Out-Null
  Write-Utf8 (Join-Path $res 'values\ic_launcher_background.xml') @"
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tools/branding/make-artwork.ps1. -->
<resources>
    <color name="ic_launcher_background">$($app.bg)</color>
</resources>
"@
}
Copy-Item (Join-Path $out 'tv_banner.png') (Join-Path $root 'tv_test_app\android\app\src\main\res\drawable-xhdpi\tv_banner.png') -Force

# --- iOS app icon (every size the asset catalog lists; no transparency) --------------------
$iconSet = Join-Path $root 'controller_app\ios\Runner\Assets.xcassets\AppIcon.appiconset'
$master = Make-Icon 'app' 1024 'full'
foreach ($file in Get-ChildItem $iconSet -Filter 'Icon-App-*.png') {
  if ($file.Name -match 'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png') {
    $px = [int][math]::Round([double]$Matches[1] * [int]$Matches[2])
    $img = Resize $master $px
    # Flatten onto opaque navy: the App Store rejects icons with an alpha channel.
    $flat = New-Object System.Drawing.Bitmap $px, $px, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $fg = [System.Drawing.Graphics]::FromImage($flat)
    $fg.Clear($navyBottom); $fg.DrawImage($img, 0, 0, $px, $px); $fg.Dispose()
    $flat.Save($file.FullName, [System.Drawing.Imaging.ImageFormat]::Png)
  }
}

# --- Windows executable icon for Thumb Party TV --------------------------------------------
Save-Ico 'tv' (Join-Path $root 'tv_test_app\windows\runner\resources\app_icon.ico')

"Artwork written to $out and the app folders."
