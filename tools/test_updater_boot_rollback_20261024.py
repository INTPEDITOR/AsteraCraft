"""A deliberately failing, self-authored test executable must roll back once."""
from pathlib import Path
from zipfile import ZipFile
import hashlib, json, subprocess, time

root=Path(__file__).resolve().parents[1]
out=root/'build/updater-boot-rollback-20261024'
game=out/'game'
new=out/'new'
for folder in [out,game,new]:folder.mkdir(parents=True,exist_ok=True)
assert game.resolve().is_relative_to(out.resolve())
csc=Path('C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe')
for folder,marker,status in [(game,'old-starts.txt',0),(new,'new-starts.txt',1)]:
    source=folder/'stub.cs'
    source.write_text('using System;using System.IO;class Program{static void Main(){File.AppendAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"'+marker+'"),"started\\n");Environment.Exit('+str(status)+');}}',encoding='utf-8')
    done=subprocess.run([str(csc),'/nologo','/target:winexe','/out:'+str(folder/'AsteraCraft.exe'),str(source)],capture_output=True,creationflags=0x08000000,timeout=30)
    assert done.returncode==0,done.stdout
for name in ['AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll']:
    (game/name).write_bytes(('old:'+name).encode())
    (new/name).write_bytes(('new:'+name).encode())
archive=out/'update.zip'
with ZipFile(archive,'w') as z:
    for name in ['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll']:z.write(new/name,name)
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
helper=out/'apply-update.ps1';helper.write_bytes((root/'data/windows_updater.txt').read_bytes())
state=out/'state.json'
done=subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',str(helper),'-GameDirectory',str(game),'-Archive',str(archive),'-ArchiveSha256',digest,'-Tag','feedback-test-crash','-StateFile',str(state)],capture_output=True,creationflags=0x08000000,timeout=45)
checks=0
def check(value,label):
    global checks
    checks+=1
    if not value:raise AssertionError(label)
check(done.returncode==1,'failed new startup returns a terminal failure')
record=json.loads(state.read_text(encoding='utf-8-sig'))
check(record['phase']=='failed' and 'confirm startup' in record['detail'],'failure persisted for manual retry')
for name in ['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll']:
    check((game/name).read_bytes()==(game/'.asteracraft-update-backup'/name).read_bytes(),'previous file restored: '+name)
for attempt in range(20):
    if (game/'old-starts.txt').exists():break
    time.sleep(.1)
check((game/'new-starts.txt').read_text().splitlines()==['started'],'new build attempted once')
check((game/'old-starts.txt').read_text().splitlines()==['started'],'previous build restarted once')
result={'passed':True,'checks':checks,'new_start_attempts':1,'recovery_start_attempts':1,'phase':record['phase'],'scope':'Real Windows helper launched a deliberately crashing self-authored executable, restored all previous files, persisted failure and restarted the previous test executable exactly once.'}
(out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
