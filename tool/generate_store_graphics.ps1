param(
  [string]$GeneratedBackground = 'C:\Users\M3X\.codex\generated_images\01a021a3-3fce-7e02-bcdc-02fc95943479\exec-69db218c-e23d-40d1-ab04-843172f4d3dd.png'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $repoRoot 'store-assets'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

function New-HighQualityGraphics([System.Drawing.Image]$image) {
  $graphics = [System.Drawing.Graphics]::FromImage($image)
  $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  return $graphics
}

# Google Play icon: 512 x 512, PNG with the original alpha channel preserved.
$iconSource = [System.Drawing.Image]::FromFile((Join-Path $repoRoot 'assets\brand\icon.png'))
$icon = New-Object System.Drawing.Bitmap 512, 512, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$icon.SetResolution(96, 96)
$graphics = New-HighQualityGraphics $icon
$graphics.Clear([System.Drawing.Color]::Transparent)
$graphics.DrawImage($iconSource, 0, 0, 512, 512)
$graphics.Dispose()
$iconSource.Dispose()
$icon.Save((Join-Path $outputRoot 'icon-512.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$icon.Dispose()

# Google Play feature graphic: crop the generated background to 1024 x 500 and add the real mark.
# The output bitmap is RGB (no alpha), as required by Play Console.
$background = [System.Drawing.Image]::FromFile($GeneratedBackground)
$feature = New-Object System.Drawing.Bitmap 1024, 500, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$feature.SetResolution(96, 96)
$graphics = New-HighQualityGraphics $feature
$graphics.Clear([System.Drawing.Color]::FromArgb(18, 21, 24))

$targetRatio = 1024.0 / 500.0
$sourceRatio = $background.Width / [double]$background.Height
if ($sourceRatio -gt $targetRatio) {
  $cropHeight = $background.Height
  $cropWidth = [int][Math]::Round($cropHeight * $targetRatio)
  $cropX = [int][Math]::Round(($background.Width - $cropWidth) / 2.0)
  $cropY = 0
} else {
  $cropWidth = $background.Width
  $cropHeight = [int][Math]::Round($cropWidth / $targetRatio)
  $cropX = 0
  $cropY = [int][Math]::Round(($background.Height - $cropHeight) / 2.0)
}
$graphics.DrawImage(
  $background,
  (New-Object System.Drawing.Rectangle 0, 0, 1024, 500),
  (New-Object System.Drawing.Rectangle $cropX, $cropY, $cropWidth, $cropHeight),
  [System.Drawing.GraphicsUnit]::Pixel
)
$background.Dispose()

$mark = [System.Drawing.Image]::FromFile((Join-Path $repoRoot 'assets\brand\mark.png'))
$markHeight = 126
$markWidth = [int][Math]::Round($mark.Width * ($markHeight / [double]$mark.Height))
$graphics.DrawImage($mark, 74, 112, $markWidth, $markHeight)
$mark.Dispose()

$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(248, 246, 240))
$muted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(197, 203, 208))
$accent = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(216, 174, 39))
$titleFont = New-Object System.Drawing.Font 'Segoe UI', 48, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$subtitleFont = New-Object System.Drawing.Font 'Segoe UI', 19, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$eyebrowFont = New-Object System.Drawing.Font 'Segoe UI', 13, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)

$graphics.DrawString('KIBOARD', $eyebrowFont, $accent, 74, 72)
$graphics.DrawString('Tu PC, a un toque.', $titleFont, $white, 74, 254)
$graphics.DrawString('Control automático desde Android · Wi-Fi local', $subtitleFont, $muted, 78, 324)

$eyebrowFont.Dispose()
$subtitleFont.Dispose()
$titleFont.Dispose()
$accent.Dispose()
$muted.Dispose()
$white.Dispose()
$graphics.Dispose()

$feature.Save((Join-Path $outputRoot 'feature-graphic-1024x500.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$feature.Dispose()

Write-Output "Generated $outputRoot\icon-512.png"
Write-Output "Generated $outputRoot\feature-graphic-1024x500.png"
