$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$demoPath = Join-Path (Get-Location) 'build\AsteraCraft-v0.4-gameplay.gif'
$demoImage = [Drawing.Image]::FromFile([IO.Path]::GetFullPath($demoPath))
$demoFrames = $demoImage.GetFrameCount([Drawing.Imaging.FrameDimension]::Time)
foreach ($demoIndex in @(0, [int]($demoFrames / 2), ($demoFrames - 1))) {
    [void]$demoImage.SelectActiveFrame([Drawing.Imaging.FrameDimension]::Time, $demoIndex)
    $demoBitmap = New-Object Drawing.Bitmap($demoImage)
    $demoColor = $demoBitmap.GetPixel(240, 150)
    Write-Output ('GIF_DECODE frame={0} size={1}x{2} center={3},{4},{5}' -f $demoIndex, $demoImage.Width, $demoImage.Height, $demoColor.R, $demoColor.G, $demoColor.B)
    $demoBitmap.Dispose()
}
Write-Output ('GIF_VERIFIED frames={0}' -f $demoFrames)
$demoImage.Dispose()
