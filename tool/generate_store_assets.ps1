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

function Draw-Orchestrate-Mark([System.Drawing.Graphics]$Graphics, [int]$Size, [bool]$Transparent = $false) {
  $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $Graphics.Clear([System.Drawing.Color]::Transparent)

  if (-not $Transparent) {
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
      (New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)),
      [System.Drawing.Color]::FromArgb(255, 6, 11, 23),
      [System.Drawing.Color]::FromArgb(255, 12, 28, 52),
      45
    )
    $Graphics.FillRectangle($bg, 0, 0, $Size, $Size)
    $bg.Dispose()
  }

  $scale = $Size / 1024.0
  $rect = New-Object System.Drawing.RectangleF(
    [single](194 * $scale),
    [single](194 * $scale),
    [single](636 * $scale),
    [single](636 * $scale)
  )
  $stroke = [single](108 * $scale)
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 248, 250, 252), $stroke)
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
  $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Flat
  $Graphics.DrawArc($pen, $rect, 206, 126)
  $Graphics.DrawArc($pen, $rect, 26, 126)
  $Graphics.DrawArc($pen, $rect, 386, 126)
  $pen.Dispose()

  $accentPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 87, 196, 255), [single](28 * $scale))
  $accentPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $accentPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $Graphics.DrawArc($accentPen, $rect, 292, 26)
  $Graphics.DrawArc($accentPen, $rect, 112, 26)
  $accentPen.Dispose()

  function Fill-Arrow([float]$AngleDegrees) {
    $angle = $AngleDegrees * [Math]::PI / 180.0
    $cx = 512 * $scale
    $cy = 512 * $scale
    $radius = 318 * $scale
    $tip = New-Object System.Drawing.PointF(
      [single]($cx + [Math]::Cos($angle) * $radius),
      [single]($cy + [Math]::Sin($angle) * $radius)
    )
    $tangent = $angle + [Math]::PI / 2.0
    $back = 150 * $scale
    $half = 95 * $scale
    $base = New-Object System.Drawing.PointF(
      [single]($tip.X - [Math]::Cos($tangent) * $back),
      [single]($tip.Y - [Math]::Sin($tangent) * $back)
    )
    $p1 = $tip
    $p2 = New-Object System.Drawing.PointF(
      [single]($base.X + [Math]::Cos($angle) * $half),
      [single]($base.Y + [Math]::Sin($angle) * $half)
    )
    $p3 = New-Object System.Drawing.PointF(
      [single]($base.X - [Math]::Cos($angle) * $half),
      [single]($base.Y - [Math]::Sin($angle) * $half)
    )
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 248, 250, 252))
    $Graphics.FillPolygon($brush, @($p1, $p2, $p3))
    $brush.Dispose()
  }

  Fill-Arrow 30
  Fill-Arrow 150
  Fill-Arrow 270
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
    [System.Drawing.Color]::FromArgb(255, 6, 11, 23),
    [System.Drawing.Color]::FromArgb(255, 17, 38, 64),
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
  $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 248, 250, 252))
  $muted = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 186, 202, 220))
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
