$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class NativeV04 {
 [StructLayout(LayoutKind.Sequential)] public struct POINT {public int x,y;}
 [StructLayout(LayoutKind.Sequential)] public struct RECT {public int left,top,right,bottom;}
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c,string t);
 public delegate bool EnumProc(IntPtr w,IntPtr p);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback,IntPtr p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr w,StringBuilder b,int n);
 public static IntPtr FindGame(){IntPtr found=IntPtr.Zero;EnumWindows((w,p)=>{var text=new StringBuilder(1024);GetWindowText(w,text,1024);if(text.ToString().Contains("AsteraCraftNativeInputV04")){found=w;return false;}return true;},IntPtr.Zero);return found;}
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr w);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr w,int n);
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr w,ref POINT p);
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr w,out RECT r);
 [DllImport("user32.dll")] public static extern bool GetClipCursor(out RECT r);
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
 [DllImport("user32.dll",SetLastError=true)] public static extern bool PostMessage(IntPtr w,uint msg,IntPtr wp,IntPtr lp);
}
'@
$project=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$statePath=Join-Path $project 'build/native-input-v04-state.json'
$focusPath=Join-Path $project 'build/native-input-v04-focus.json'
$menuPath=Join-Path $project 'build/native-input-v04-menu.json'
$saved=[NativeV04+POINT]::new();[void][NativeV04]::GetCursorPos([ref]$saved)
$stage=-1;$deadline=[DateTime]::UtcNow.AddSeconds(45)
try {
 while([DateTime]::UtcNow -lt $deadline){
  if(!(Test-Path -LiteralPath $statePath)){Start-Sleep -Milliseconds 100;continue}
  try {$s=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json}catch{Start-Sleep -Milliseconds 100;continue}
  if($s.stage -eq $stage){Start-Sleep -Milliseconds 100;continue}
  $w=[NativeV04]::FindGame()
  if($w -eq [IntPtr]::Zero){Start-Sleep -Milliseconds 100;continue}
  $stage=[int]$s.stage
  [void][NativeV04]::ShowWindow($w,5)
  $focused=[NativeV04]::SetForegroundWindow($w);Start-Sleep -Milliseconds 180
  Write-Output "NATIVE_WINDOW hwnd=$w foreground=$focused stage=$stage"
  if($stage -le 2){
   $origin=[NativeV04+POINT]::new();[void][NativeV04]::ClientToScreen($w,[ref]$origin)
   $client=[NativeV04+RECT]::new();[void][NativeV04]::GetClientRect($w,[ref]$client)
   $x=$origin.x+[int]($s.point[0]*($client.right-$client.left)/$s.size[0]);$y=$origin.y+[int]($s.point[1]*($client.bottom-$client.top)/$s.size[1])
   [void][NativeV04]::SetCursorPos($x,$y)
   $key=if($stage -eq 1){[byte]82}else{[byte]65}
   $scan=if($stage -eq 1){[byte]19}else{[byte]30}
   [NativeV04]::keybd_event($key,$scan,0,[UIntPtr]::Zero);[NativeV04]::keybd_event($key,$scan,2,[UIntPtr]::Zero)
   Start-Sleep -Milliseconds 150
   [NativeV04]::mouse_event(2,0,0,0,[UIntPtr]::Zero);[NativeV04]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
   $lx=[int]($s.point[0]*($client.right-$client.left)/$s.size[0]);$ly=[int]($s.point[1]*($client.bottom-$client.top)/$s.size[1]);$packed=($ly -shl 16) -bor ($lx -band 65535)
   [void][NativeV04]::PostMessage($w,256,[IntPtr][int]$key,[IntPtr](1 -bor ([int]$scan -shl 16)))
   [void][NativeV04]::PostMessage($w,257,[IntPtr][int]$key,[IntPtr](1073741825 -bor ([int]$scan -shl 16)))
   Start-Sleep -Milliseconds 120
   [void][NativeV04]::PostMessage($w,512,[IntPtr]::Zero,[IntPtr]$packed)
   $posted=[NativeV04]::PostMessage($w,513,[IntPtr]1,[IntPtr]$packed)
   [void][NativeV04]::PostMessage($w,514,[IntPtr]::Zero,[IntPtr]$packed)
   Write-Output "WIN32_SENT stage=$stage at=$x,$y posted=$posted"
  } elseif($stage -eq 3){
   $clip=[NativeV04+RECT]::new();[void][NativeV04]::GetClipCursor([ref]$clip)
   $confined=($clip.right-$clip.left -le $client.right-$client.left+2 -and $clip.bottom-$clip.top -le $client.bottom-$client.top+2)
   [void][NativeV04]::ShowWindow($w,6);Start-Sleep -Milliseconds 850
   $unfocused=[NativeV04+RECT]::new();[void][NativeV04]::GetClipCursor([ref]$unfocused)
   [void][NativeV04]::ShowWindow($w,9);[void][NativeV04]::SetForegroundWindow($w);Start-Sleep -Milliseconds 450
   $restored=[NativeV04+RECT]::new();[void][NativeV04]::GetClipCursor([ref]$restored)
   @{confined=$confined;unfocused_released=($unfocused.right-$unfocused.left -gt $clip.right-$clip.left);refocused_confined=($restored.right-$restored.left -eq $clip.right-$clip.left);clip=@($clip.left,$clip.top,$clip.right,$clip.bottom);unfocused=@($unfocused.left,$unfocused.top,$unfocused.right,$unfocused.bottom)} | ConvertTo-Json | Set-Content -LiteralPath $focusPath
  } elseif($stage -eq 4){
   Start-Sleep -Milliseconds 250
   $clip=[NativeV04+RECT]::new();[void][NativeV04]::GetClipCursor([ref]$clip)
   @{released=($clip.right-$clip.left -gt 1440)} | ConvertTo-Json | Set-Content -LiteralPath $menuPath
   break
  }
 }
} finally {[void][NativeV04]::SetCursorPos($saved.x,$saved.y)}
