param([string]$Manifest, [string]$Output)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null=[Windows.Media.SpeechSynthesis.SpeechSynthesizer,Windows.Media.SpeechSynthesis,ContentType=WindowsRuntime]
$null=[Windows.Storage.Streams.DataReader,Windows.Storage.Streams,ContentType=WindowsRuntime]
$asTask=([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await-Result($operation,$type) {
    $task=$asTask.MakeGenericMethod($type).Invoke($null,@($operation))
    $task.Wait()
    return $task.Result
}
$synth=New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$synth.Voice=[Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object Language -eq 'ko-KR' | Select-Object -First 1
if (-not $synth.Voice) { throw 'No Korean TTS voice installed' }
$catalog=Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
[IO.Directory]::CreateDirectory($Output) | Out-Null
$count=0
foreach ($clip in $catalog.clips) {
    if ($clip.type -ne 'speech') { continue }
    $path=Join-Path $Output ($clip.id+'.wav')
    if (Test-Path -LiteralPath $path) { continue }
    $stream=Await-Result ($synth.SynthesizeTextToStreamAsync($clip.text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
    $reader=New-Object Windows.Storage.Streams.DataReader($stream)
    $null=Await-Result ($reader.LoadAsync([uint32]$stream.Size)) ([uint32])
    $bytes=New-Object byte[] ([int]$stream.Size)
    $reader.ReadBytes($bytes)
    [IO.File]::WriteAllBytes($path,$bytes)
    $reader.Dispose();$stream.Dispose()
    $count++
    if ($count%25 -eq 0) { Write-Output "TTS rendered: $count" }
}
$synth.Dispose()
Write-Output "TTS complete: $count new clips"
