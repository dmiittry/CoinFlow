$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
$source = New-Object System.Drawing.Bitmap 1024,1024
$graphics = [System.Drawing.Graphics]::FromImage($source)
$graphics.SmoothingMode = 'AntiAlias'
$graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#00C99A'))
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White),44
$pen.LineJoin = 'Round'
$graphics.DrawRectangle($pen,250,310,530,410)
$graphics.DrawLine($pen,250,310,680,240)
$graphics.DrawLine($pen,680,240,680,310)
$graphics.FillRectangle([System.Drawing.Brushes]::White,590,450,220,150)
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#00C99A'))
$graphics.FillEllipse($brush,630,500,48,48)
function Save-Icon([string]$RelativePath, [int]$Size) {
  $target = Join-Path $projectRoot $RelativePath
  $bitmap = New-Object System.Drawing.Bitmap $Size,$Size
  $canvas = [System.Drawing.Graphics]::FromImage($bitmap)
  $canvas.InterpolationMode = 'HighQualityBicubic'
  $canvas.DrawImage($source,0,0,$Size,$Size)
  $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
  $canvas.Dispose()
  $bitmap.Dispose()
}
foreach ($entry in @{mdpi=48;hdpi=72;xhdpi=96;xxhdpi=144;xxxhdpi=192}.GetEnumerator()) {
  Save-Icon "android/app/src/main/res/mipmap-$($entry.Key)/ic_launcher.png" $entry.Value
}
$iconFolder = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
$manifest = Get-Content (Join-Path $projectRoot "$iconFolder/Contents.json") -Raw | ConvertFrom-Json
foreach ($entry in $manifest.images) {
  $size = [double]($entry.size.Split('x')[0]) * [double]($entry.scale.Replace('x',''))
  Save-Icon "$iconFolder/$($entry.filename)" ([int]$size)
}
Save-Icon 'web/favicon.png' 32
Save-Icon 'web/icons/Icon-192.png' 192
Save-Icon 'web/icons/Icon-512.png' 512
Save-Icon 'web/icons/Icon-maskable-192.png' 192
Save-Icon 'web/icons/Icon-maskable-512.png' 512
$pen.Dispose()
$brush.Dispose()
$graphics.Dispose()
$source.Dispose()
