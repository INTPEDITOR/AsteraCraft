param([string]$ReleaseDirectory='')
$ErrorActionPreference='Stop'
$releaseRoot=if($ReleaseDirectory){[IO.Path]::GetFullPath($ReleaseDirectory)}else{[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../deliverables/AsteraCraft-Windows-v0.5.8-20261018'))}
$archivePath=$releaseRoot+'.zip'
Add-Type -AssemblyName System.IO.Compression.FileSystem
if(Test-Path -LiteralPath $archivePath){throw 'Release archive already exists; preserve it and choose a new name.'}
[IO.Compression.ZipFile]::CreateFromDirectory($releaseRoot,$archivePath,[IO.Compression.CompressionLevel]::Optimal,$true)
$manifest=Get-Content -LiteralPath (Join-Path $releaseRoot 'BUILD_MANIFEST.json') -Raw | ConvertFrom-Json
$zip=[IO.Compression.ZipFile]::OpenRead($archivePath)
try {
 $prefix=[IO.Path]::GetFileName($releaseRoot)+'/'
 foreach($item in $manifest.files){
  $entry=$zip.GetEntry($prefix+$item.file)
  if($null -eq $entry -or $entry.Length -ne $item.bytes){throw ('Missing or wrong size: '+$item.file)}
  $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
  try{$actual=[Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant()}finally{$stream.Dispose();$sha.Dispose()}
  if($actual -ne $item.sha256){throw ('Hash mismatch: '+$item.file)}
 }
} finally {$zip.Dispose()}
$hash=(Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($archivePath+'.sha256',$hash+'  '+[IO.Path]::GetFileName($archivePath)+[Environment]::NewLine)
Write-Output ('ARCHIVE_VERIFIED '+$manifest.files.Count+' files; '+$archivePath+'; SHA256 '+$hash)
