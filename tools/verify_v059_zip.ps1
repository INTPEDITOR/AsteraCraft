$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath=(Resolve-Path '../deliverables/AsteraCraft-Windows-v0.5.9-20261018.zip').Path
$archive=[System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
 $manifestEntry=$archive.Entries | Where-Object {$_.FullName.EndsWith('/BUILD_MANIFEST.json') -or $_.FullName.EndsWith('\BUILD_MANIFEST.json')}
 $reader=[System.IO.StreamReader]::new($manifestEntry.Open())
 try {$manifest=$reader.ReadToEnd() | ConvertFrom-Json} finally {$reader.Dispose()}
 $prefix=$manifestEntry.FullName.Substring(0,$manifestEntry.FullName.Length-'BUILD_MANIFEST.json'.Length).Replace('\','/')
 $checked=0
 foreach($file in $manifest.files){
  $expected=$prefix+$file.file
  $entry=$archive.Entries | Where-Object {$_.FullName.Replace('\','/') -eq $expected}
  if($null -eq $entry -or $entry.Length -ne $file.bytes){throw "Missing or wrong size: $($file.file)"}
  $stream=$entry.Open();$hash=[System.Security.Cryptography.SHA256]::Create()
  try {$actual=[Convert]::ToHexString($hash.ComputeHash($stream)).ToLowerInvariant()} finally {$stream.Dispose();$hash.Dispose()}
  if($actual -ne $file.sha256){throw "Hash mismatch: $($file.file)"}
  $checked++
 }
 Write-Output "ZIP_CONTENTS verified $checked files"
} finally {$archive.Dispose()}
Get-FileHash -LiteralPath $zipPath -Algorithm SHA256 | Select-Object Hash,Path
