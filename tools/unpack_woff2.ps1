param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\assets\fonts\Galmuri14.woff2'),
    [string]$DestinationPath = (Join-Path $PSScriptRoot '..\assets\fonts\Galmuri14.ttf')
)
$ErrorActionPreference = 'Stop'

# Uses the installed Windows DirectWrite decoder; no downloads or glyph changes.
# SDK 10.0.19041 dwrite_3.h: IDWriteFactory5 IID below; inherited vtable has
# 43 entries before Factory5, AnalyzeContainerType=46, UnpackFontFile=47.
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;

public static class AsteraWoffUnpacker {
    [DllImport("dwrite.dll", CallingConvention=CallingConvention.StdCall)]
    private static extern int DWriteCreateFactory(uint factoryType, ref Guid iid, out IntPtr factory);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate uint Analyze(IntPtr self, IntPtr data, uint size);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int Unpack(IntPtr self, uint containerType, IntPtr data, uint size, out IntPtr stream);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int FileSize(IntPtr self, out ulong size);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate int ReadFragment(IntPtr self, out IntPtr start, ulong offset, ulong size, out IntPtr context);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate void ReleaseFragment(IntPtr self, IntPtr context);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    private delegate uint ReleaseObject(IntPtr self);

    private static Delegate Method(IntPtr instance, int slot, Type type) {
        IntPtr table = Marshal.ReadIntPtr(instance);
        return Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(table, slot * IntPtr.Size), type);
    }
    private static void Release(IntPtr instance) {
        if (instance != IntPtr.Zero) ((ReleaseObject)Method(instance, 2, typeof(ReleaseObject)))(instance);
    }
    public static long Convert(string source, string destination) {
        byte[] compressed = File.ReadAllBytes(source);
        if (compressed.Length < 48 || compressed[0] != 0x77 || compressed[1] != 0x4f || compressed[2] != 0x46 || compressed[3] != 0x32)
            throw new InvalidDataException("Source is not a WOFF2 font.");
        IntPtr factory = IntPtr.Zero, stream = IntPtr.Zero, fragmentContext = IntPtr.Zero;
        bool fragmentAcquired = false;
        GCHandle pinned = GCHandle.Alloc(compressed, GCHandleType.Pinned);
        try {
            Guid iid = new Guid("958DB99A-BE2A-4F09-AF7D-65189803D1D3");
            Marshal.ThrowExceptionForHR(DWriteCreateFactory(0, ref iid, out factory));
            IntPtr data = pinned.AddrOfPinnedObject();
            uint container = ((Analyze)Method(factory, 46, typeof(Analyze)))(factory, data, (uint)compressed.Length);
            if (container != 2) throw new InvalidDataException("DirectWrite did not recognize WOFF2.");
            Marshal.ThrowExceptionForHR(((Unpack)Method(factory, 47, typeof(Unpack)))(factory, container, data, (uint)compressed.Length, out stream));
            ulong length;
            Marshal.ThrowExceptionForHR(((FileSize)Method(stream, 5, typeof(FileSize)))(stream, out length));
            if (length < 12 || length > 100000000) throw new InvalidDataException("Unexpected decompressed font size.");
            IntPtr fragment;
            Marshal.ThrowExceptionForHR(((ReadFragment)Method(stream, 3, typeof(ReadFragment)))(stream, out fragment, 0, length, out fragmentContext));
            fragmentAcquired = true;
            byte[] unpacked = new byte[checked((int)length)];
            Marshal.Copy(fragment, unpacked, 0, unpacked.Length);
            if (!(unpacked[0] == 0 && unpacked[1] == 1 && unpacked[2] == 0 && unpacked[3] == 0))
                throw new InvalidDataException("Decompressed data is not a TrueType SFNT font.");
            File.WriteAllBytes(destination, unpacked);
            return unpacked.LongLength;
        } finally {
            if (fragmentAcquired) ((ReleaseFragment)Method(stream, 4, typeof(ReleaseFragment)))(stream, fragmentContext);
            Release(stream);
            Release(factory);
            pinned.Free();
        }
    }
}
'@
$fontSource = (Resolve-Path -LiteralPath $SourcePath).Path
$fontDestination = [System.IO.Path]::GetFullPath($DestinationPath)
$fontBytes = [AsteraWoffUnpacker]::Convert($fontSource, $fontDestination)
Write-Output ('DIRECTWRITE_WOFF2_UNPACK bytes={0} output={1}' -f $fontBytes, $fontDestination)
