param([string]$Installation='E:\StarCraft')
$ErrorActionPreference='Stop'
$dll=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../.work/CascLib/bin/CascLib_dll/x64/Release/CascLib.dll'))
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class TerrainCasc {
 [DllImport(@"$dll",CharSet=CharSet.Ansi,SetLastError=true)] [return:MarshalAs(UnmanagedType.I1)] public static extern bool CascOpenStorage(string path,uint locale,out IntPtr handle);
 [DllImport(@"$dll",CharSet=CharSet.Ansi,SetLastError=true)] [return:MarshalAs(UnmanagedType.I1)] public static extern bool CascOpenFile(IntPtr storage,string path,uint locale,uint flags,out IntPtr file);
 [DllImport(@"$dll",SetLastError=true)] [return:MarshalAs(UnmanagedType.I1)] public static extern bool CascGetFileSize64(IntPtr file,out ulong size);
 [DllImport(@"$dll",SetLastError=true)] [return:MarshalAs(UnmanagedType.I1)] public static extern bool CascReadFile(IntPtr file,byte[] data,uint length,out uint read);
 [DllImport(@"$dll")] [return:MarshalAs(UnmanagedType.I1)] public static extern bool CascCloseFile(IntPtr file);
 [DllImport(@"$dll")] [return:MarshalAs(UnmanagedType.I1)] public static extern bool CascCloseStorage(IntPtr storage);
}
"@
$storage=[IntPtr]::Zero
if(-not [TerrainCasc]::CascOpenStorage($Installation,0,[ref]$storage)){throw ('CASC open failed: '+[Runtime.InteropServices.Marshal]::GetLastWin32Error())}
$outDir=Join-Path $PSScriptRoot '../build/terrain-metadata'
New-Item -ItemType Directory -Force $outDir | Out-Null
try {
 foreach($name in 'tileset\jungle.vx4ex','tileset\jungle.vr4','tileset\jungle.wpe'){
  $file=[IntPtr]::Zero
  if(-not [TerrainCasc]::CascOpenFile($storage,$name,0,0,[ref]$file)){throw ('Missing '+$name+': '+[Runtime.InteropServices.Marshal]::GetLastWin32Error())}
  try {
   [ulong]$size=0; if(-not [TerrainCasc]::CascGetFileSize64($file,[ref]$size)){throw 'Size failed'}
   $bytes=[byte[]]::new($size);[uint32]$read=0
   if(-not [TerrainCasc]::CascReadFile($file,$bytes,$size,[ref]$read) -or $read -ne $size){throw 'Read failed'}
   [IO.File]::WriteAllBytes((Join-Path $outDir ([IO.Path]::GetFileName($name))),$bytes)
   Write-Output ($name+' '+$size+' bytes')
  } finally {[void][TerrainCasc]::CascCloseFile($file)}
 }
} finally {[void][TerrainCasc]::CascCloseStorage($storage)}
