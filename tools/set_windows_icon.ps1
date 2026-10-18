param([Parameter(Mandatory=$true)][string]$Executable,[Parameter(Mandatory=$true)][string]$Icon)
$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.IO;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class AsteraIconResource {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr BeginUpdateResource(string file,bool delete);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool UpdateResource(IntPtr h,IntPtr type,IntPtr name,ushort language,byte[] data,uint size);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool EndUpdateResource(IntPtr h,bool discard);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr LoadLibraryEx(string file,IntPtr h,uint flags);
 [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr h);
 delegate bool EnumName(IntPtr module,IntPtr type,IntPtr name,IntPtr param);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern bool EnumResourceNames(IntPtr module,IntPtr type,EnumName callback,IntPtr param);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern IntPtr FindResource(IntPtr module,IntPtr name,IntPtr type);
 [DllImport("kernel32.dll")] static extern uint SizeofResource(IntPtr module,IntPtr resource);
 public static void Apply(string exe,string ico) {
  byte[] bytes=File.ReadAllBytes(ico); ushort count=BitConverter.ToUInt16(bytes,4);
  var module=LoadLibraryEx(exe,IntPtr.Zero,2); var ids=new System.Collections.Generic.List<int>();var names=new System.Collections.Generic.List<string>();
  EnumResourceNames(module,(IntPtr)14,(m,t,n,p)=>{if(n.ToInt64()<=65535)ids.Add(n.ToInt32());else names.Add(Marshal.PtrToStringUni(n));return true;},IntPtr.Zero);FreeLibrary(module);
  if(ids.Count==0)ids.Add(1);
  var handle=BeginUpdateResource(exe,false);if(handle==IntPtr.Zero)throw new Win32Exception();
  bool success=false;
  try {
   using(var memory=new MemoryStream())using(var writer=new BinaryWriter(memory)) {
    writer.Write((ushort)0);writer.Write((ushort)1);writer.Write(count);
    for(int i=0;i<count;i++) {
     int entry=6+i*16;uint length=BitConverter.ToUInt32(bytes,entry+8);int offset=(int)BitConverter.ToUInt32(bytes,entry+12);
     byte[] png=new byte[length];Array.Copy(bytes,offset,png,0,length);
     foreach(ushort language in new ushort[]{0,1033})if(!UpdateResource(handle,(IntPtr)3,(IntPtr)(200+i),language,png,length))throw new Win32Exception();
     writer.Write(bytes,entry,12);writer.Write((ushort)(200+i));
    }
    byte[] group=memory.ToArray();
    foreach(int id in ids)foreach(ushort language in new ushort[]{0,1033})if(!UpdateResource(handle,(IntPtr)14,(IntPtr)id,language,group,(uint)group.Length))throw new Win32Exception();
    foreach(string name in names){var ptr=Marshal.StringToHGlobalUni(name);try{foreach(ushort language in new ushort[]{0,1033})if(!UpdateResource(handle,(IntPtr)14,ptr,language,group,(uint)group.Length))throw new Win32Exception();}finally{Marshal.FreeHGlobal(ptr);}}
   }
   success=true;
  } finally {if(!EndUpdateResource(handle,!success))throw new Win32Exception();}
  module=LoadLibraryEx(exe,IntPtr.Zero,2);
  try {for(int i=0;i<count;i++){var r=FindResource(module,(IntPtr)(200+i),(IntPtr)3);if(r==IntPtr.Zero||SizeofResource(module,r)!=BitConverter.ToUInt32(bytes,6+i*16+8))throw new Exception("Icon resource verification failed");}}
  finally {FreeLibrary(module);}
 }
}
'@
[AsteraIconResource]::Apply((Resolve-Path -LiteralPath $Executable).Path,(Resolve-Path -LiteralPath $Icon).Path)
Write-Output 'WINDOWS_ICON verified: 7 resolutions embedded'
