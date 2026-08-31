param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function New-Bitmap([int]$Width, [int]$Height) {
  return New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

# THE CANONICAL ORCHESTRATE MARK IS A FILE, NOT A DRAWING.
#
# This generator used to re-draw the mark in code. That is exactly how the
# product drifted: the drawing -- a two-arrow refresh glyph on a navy gradient
# with a cyan accent -- was never the canonical identity, so every asset this
# tool wrote was wrong, and the mark the Microsoft build actually ships (a
# four-arrow cycle, white on black) survived only in the few files the tool
# happened never to overwrite.
#
# Every asset is now RESAMPLED FROM THE MASTER. The identity is defined in
# exactly one place, and it is artwork -- not arithmetic that can be edited
# into a different logo without anyone noticing.

$script:MasterPath = Join-Path $Root "assets\branding\icons\orchestrate_app_icon_dark_1024.png"
if (-not (Test-Path -LiteralPath $script:MasterPath)) {
  throw "Canonical master missing at $($script:MasterPath). Refusing to invent a mark."
}
$script:Master = New-Object System.Drawing.Bitmap($script:MasterPath)

$script:AlphaFloor = 100
$script:AlphaCeil = 200

function ConvertTo-AlphaMark([System.Drawing.Bitmap]$Source) {
  # The master is a white mark on a black ground, so its luminance IS its
  # coverage. Deriving alpha from that gives the transparent foreground Android
  # adaptive icons and maskable web icons need, without a second piece of
  # artwork that could later drift away from the first.
  $w = $Source.Width
  $h = $Source.Height
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $src = $Source.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $buf = New-Object 'int[]' ($w * $h)
  [System.Runtime.InteropServices.Marshal]::Copy($src.Scan0, $buf, 0, $buf.Length)
  $Source.UnlockBits($src)
  for ($i = 0; $i -lt $buf.Length; $i++) {
    $p = $buf[$i]
    $r = ($p -shr 16) -band 0xFF
    $g = ($p -shr 8) -band 0xFF
    $b = $p -band 0xFF
    $lum = [int]((($r * 299) + ($g * 587) + ($b * 114)) / 1000)
    # The master's ground is not perfectly black -- it carries a faint vignette
    # that runs to ~70. Using raw luminance as alpha drags that haze into every
    # generated tile as a grey box around the mark. The artwork is cleanly
    # bimodal (ground 0-19, mark 220+), so alpha is gated on that knee: the
    # ground contributes nothing and the antialiased edge is preserved.
    if ($lum -le $script:AlphaFloor) {
      $a = 0
    } elseif ($lum -ge $script:AlphaCeil) {
      $a = 255
    } else {
      $a = [int]((($lum - $script:AlphaFloor) * 255) / ($script:AlphaCeil - $script:AlphaFloor))
    }
    $buf[$i] = ($a -shl 24) -bor 0x00FFFFFF
  }
  $out = New-Bitmap $w $h
  $dst = $out.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $dst.Scan0, $buf.Length)
  $out.UnlockBits($dst)
  return $out
}

$script:MasterAlpha = ConvertTo-AlphaMark $script:Master

# The mark fills 0.673 of the master's own canvas, measured off the artwork.
# Drawing the master edge-to-edge therefore reproduces that crop exactly, and
# at tile sizes the heavy ring reads boxed-in -- contained, with no air around
# it. Treatment is composition, not redrawing: the artwork is untouched and
# simply given a margin.
$script:MarkSpanInMaster = 0.673
$script:DefaultMarkSpan = 0.58   # opaque tiles
$script:MaskedMarkSpan = 0.52    # adaptive / maskable, which get cropped again

function Draw-Orchestrate-Mark(
  [System.Drawing.Graphics]$Graphics,
  [int]$Size,
  [bool]$Transparent = $false,
  [double]$MarkSpan = 0
) {
  if ($MarkSpan -le 0) {
    $MarkSpan = if ($Transparent) { $script:MaskedMarkSpan } else { $script:DefaultMarkSpan }
  }
  $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $Graphics.Clear([System.Drawing.Color]::Transparent)

  # Always composite the MARK, never the master bitmap: the master's ground is
  # #101010, so scaling the whole bitmap into a larger tile leaves its ground
  # visible as a lighter square. Painting a flat ground and laying the mark
  # over it gives one uniform field at every size.
  if (-not $Transparent) {
    $ground = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 0, 0))
    $Graphics.FillRectangle($ground, 0, 0, $Size, $Size)
    $ground.Dispose()
  }

  $source = $script:MasterAlpha
  $drawn = $Size * ($MarkSpan / $script:MarkSpanInMaster)
  $offset = ($Size - $drawn) / 2.0
  $Graphics.DrawImage($source, [single]$offset, [single]$offset, [single]$drawn, [single]$drawn)
}

function Save-Png([int]$Width, [int]$Height, [string]$Path, [scriptblock]$Draw) {
  Ensure-Dir (Split-Path -Parent $Path)
  $bitmap = New-Bitmap $Width $Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  & $Draw $graphics $Width $Height
  $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose()
  $bitmap.Dispose()
}

function Save-IconSet([string]$Path, [int[]]$Sizes) {
  Ensure-Dir (Split-Path -Parent $Path)
  $entries = @()
  foreach ($size in $Sizes) {
    $ms = New-Object System.IO.MemoryStream
    Save-Png $size $size "$env:TEMP\orchestrate-icon-$size.png" {
      param($g, $w, $h)
      Draw-Orchestrate-Mark $g $w
    }
    $bytes = [System.IO.File]::ReadAllBytes("$env:TEMP\orchestrate-icon-$size.png")
    $entries += [pscustomobject]@{ Size = $size; Bytes = $bytes }
    $ms.Dispose()
  }

  $fs = [System.IO.File]::Create($Path)
  $bw = New-Object System.IO.BinaryWriter($fs)
  $bw.Write([UInt16]0)
  $bw.Write([UInt16]1)
  $bw.Write([UInt16]$entries.Count)
  $offset = 6 + (16 * $entries.Count)
  foreach ($entry in $entries) {
    $dimension = if ($entry.Size -eq 256) { 0 } else { $entry.Size }
    $bw.Write([byte]$dimension)
    $bw.Write([byte]$dimension)
    $bw.Write([byte]0)
    $bw.Write([byte]0)
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]32)
    $bw.Write([UInt32]$entry.Bytes.Length)
    $bw.Write([UInt32]$offset)
    $offset += $entry.Bytes.Length
  }
  foreach ($entry in $entries) {
    $bw.Write($entry.Bytes)
  }
  $bw.Close()
  $fs.Close()
}

$store = Join-Path $Root "store_assets"
Ensure-Dir $store
Ensure-Dir (Join-Path $store "source")
Ensure-Dir (Join-Path $store "android\screenshots")
Ensure-Dir (Join-Path $store "ios\screenshots")
Ensure-Dir (Join-Path $store "windows\screenshots")

Save-Png 1024 1024 (Join-Path $store "source\orchestrate-app-icon-master-1024.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w
}

$androidMipmaps = @{
  "mipmap-mdpi\ic_launcher.png" = 48
  "mipmap-hdpi\ic_launcher.png" = 72
  "mipmap-xhdpi\ic_launcher.png" = 96
  "mipmap-xxhdpi\ic_launcher.png" = 144
  "mipmap-xxxhdpi\ic_launcher.png" = 192
}
foreach ($item in $androidMipmaps.GetEnumerator()) {
  Save-Png $item.Value $item.Value (Join-Path $Root "android\app\src\main\res\$($item.Key)") {
    param($g, $w, $h)
    Draw-Orchestrate-Mark $g $w
  }
}
Save-Png 432 432 (Join-Path $Root "android\app\src\main\res\drawable\ic_launcher_foreground.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w $true
}
Save-Png 512 512 (Join-Path $store "android\play-icon-512.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w
}
Save-Png 1024 500 (Join-Path $store "android\feature-graphic-1024x500.png") {
  param($g, $w, $h)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(0, 0, $w, $h)),
    [System.Drawing.Color]::FromArgb(255, 0, 0, 0),
    [System.Drawing.Color]::FromArgb(255, 18, 18, 18),
    25
  )
  $g.FillRectangle($brush, 0, 0, $w, $h)
  $brush.Dispose()
  $mark = New-Bitmap 220 220
  $markGraphics = [System.Drawing.Graphics]::FromImage($mark)
  Draw-Orchestrate-Mark $markGraphics 220 $true
  $g.DrawImage($mark, 50, 140, 220, 220)
  $markGraphics.Dispose()
  $mark.Dispose()
  $fontTitle = New-Object System.Drawing.Font("Segoe UI", 70, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $fontSub = New-Object System.Drawing.Font("Segoe UI", 30, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 245, 245, 245))
  $muted = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 170, 170, 170))
  $g.DrawString("Orchestrate", $fontTitle, $white, 280, 165)
  $g.DrawString("AI-governed revenue operations workspace", $fontSub, $muted, 286, 255)
  $fontTitle.Dispose()
  $fontSub.Dispose()
  $white.Dispose()
  $muted.Dispose()
}

Save-Png 64 64 (Join-Path $Root "web\favicon.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w
}
Save-Png 192 192 (Join-Path $Root "web\icons\Icon-192.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w
}
Save-Png 512 512 (Join-Path $Root "web\icons\Icon-512.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w
}
Save-Png 192 192 (Join-Path $Root "web\icons\Icon-maskable-192.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w
}
Save-Png 512 512 (Join-Path $Root "web\icons\Icon-maskable-512.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w
}

$iosIcons = @{
  "Icon-App-20x20@1x.png" = 20
  "Icon-App-20x20@2x.png" = 40
  "Icon-App-20x20@3x.png" = 60
  "Icon-App-29x29@1x.png" = 29
  "Icon-App-29x29@2x.png" = 58
  "Icon-App-29x29@3x.png" = 87
  "Icon-App-40x40@1x.png" = 40
  "Icon-App-40x40@2x.png" = 80
  "Icon-App-40x40@3x.png" = 120
  "Icon-App-60x60@2x.png" = 120
  "Icon-App-60x60@3x.png" = 180
  "Icon-App-76x76@1x.png" = 76
  "Icon-App-76x76@2x.png" = 152
  "Icon-App-83.5x83.5@2x.png" = 167
  "Icon-App-1024x1024@1x.png" = 1024
}
foreach ($item in $iosIcons.GetEnumerator()) {
  Save-Png $item.Value $item.Value (Join-Path $Root "ios\Runner\Assets.xcassets\AppIcon.appiconset\$($item.Key)") {
    param($g, $w, $h)
    Draw-Orchestrate-Mark $g $w
  }
}
Save-Png 1024 1024 (Join-Path $store "ios\app-store-icon-1024.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w
}

Save-Png 300 300 (Join-Path $store "windows\store-tile-300.png") {
  param($g, $w, $h)
  Draw-Orchestrate-Mark $g $w
}
Save-IconSet (Join-Path $Root "windows\runner\resources\app_icon.ico") @(16, 32, 48, 64, 128, 256)

$macIcons = @{
  "app_icon_16.png" = 16
  "app_icon_32.png" = 32
  "app_icon_64.png" = 64
  "app_icon_128.png" = 128
  "app_icon_256.png" = 256
  "app_icon_512.png" = 512
  "app_icon_1024.png" = 1024
}
foreach ($item in $macIcons.GetEnumerator()) {
  Save-Png $item.Value $item.Value (Join-Path $Root "macos\Runner\Assets.xcassets\AppIcon.appiconset\$($item.Key)") {
    param($g, $w, $h)
    Draw-Orchestrate-Mark $g $w
  }
}
