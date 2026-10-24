from pathlib import Path
from zipfile import ZipFile
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[1]
out=root/'build/updater-test-20261024';out.mkdir(parents=True,exist_ok=True)
runner=out/'apply-update.ps1';runner.write_bytes((root/'data/windows_updater.txt').read_bytes())
required=['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll']
checks=0
def check(value,label):
 global checks
 checks+=1
 if not value:raise AssertionError(label)
def case(name,extras=None,missing=None,bad_hash=False,fail_after=False):
 directory=out/name;directory.mkdir(exist_ok=True)
 check(directory.resolve().is_relative_to(out.resolve()),'fixture remains inside workspace')
 for item in required:(directory/item).write_bytes(('old:'+item).encode())
 (directory/'settings.keep').write_text('user settings untouched')
 archive=directory/'update.zip'
 with ZipFile(archive,'w') as z:
  for item in required+['README.txt','game_icon.ico','LICENSES-LevelUp.txt']:
   if item!=missing:z.writestr(item,('new:'+item).encode())
  for item in extras or []:z.writestr(item,b'not allowed')
 digest='0'*64 if bad_hash else hashlib.sha256(archive.read_bytes()).hexdigest()
 args=['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',str(runner),'-GameDirectory',str(directory),'-Archive',str(archive),'-ArchiveSha256',digest,'-Tag','feedback-test-20261024','-StateFile',str(directory/'state.json'),'-SkipRestart']
 if fail_after:args.append('-SimulateFailureAfterCopy')
 p=subprocess.run(args,capture_output=True,text=True,encoding='cp949',errors='replace',timeout=45,creationflags=0x08000000)
 success=not(extras or missing or bad_hash or fail_after)
 check(p.returncode==(0 if success else 1),name+' expected result '+p.stderr[-400:])
 for item in required:check((directory/item).read_bytes()==(('new:' if success else 'old:')+item).encode(),name+' current '+item)
 check((directory/'settings.keep').read_text()=='user settings untouched',name+' preserves unrelated files')
 state=json.loads((directory/'state.json').read_text(encoding='utf-8-sig'))
 check(state['phase']==('confirmed' if success else 'failed'),name+' persists terminal state')
 if success or fail_after:
  for item in required:check((directory/'.asteracraft-update-backup'/item).read_bytes()==('old:'+item).encode(),name+' previous files backed up')
 if fail_after:check(not(directory/'LICENSES-LevelUp.txt').exists(),'rollback removes only newly introduced allowed files')
case('valid')
case('bad-digest',bad_hash=True)
case('traversal',extras=['../escape.txt'])
check(not(out/'escape.txt').exists(),'traversal did not escape')
case('unknown-file',extras=['unknown.exe'])
case('nested',extras=['nested/AsteraCraft.exe'])
case('missing-pck',missing='AsteraCraft.pck')
case('case-duplicate',extras=['ASTERACRAFT.EXE'])
case('rollback',fail_after=True)
result={'passed':True,'checks':checks,'cases':8,'scope':'Real Windows helper exercised on disposable files: verified install, digest rejection, path/entry allowlist, duplicates, missing files, interrupted-copy rollback and saved terminal state; restart confirmation tested separately with exported game'}
(out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
