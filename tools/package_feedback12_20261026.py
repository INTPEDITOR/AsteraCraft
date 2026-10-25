"""Create archive and updater checksum, without gameplay/boot/update test runs."""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[1];out=root/'build/feedback12_20261026'
name='AsteraCraft-Windows-feedback12-20261026.zip'
files=['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll','README.txt','game_icon.ico','LICENSES-LevelUp.txt']
archive=out/name
with ZipFile(archive,'w',compression=ZIP_DEFLATED,compresslevel=1,allowZip64=True) as z:
    for item in files:z.write(out/item,item)
with archive.open('rb') as f:sha=hashlib.file_digest(f,'sha256').hexdigest()
(out/(name+'.sha256')).write_text(sha+'  '+name+'\n',encoding='ascii')
result={'passed':True,'bytes':archive.stat().st_size,'sha256':sha,'files':files,'scope':'Archive creation and updater checksum only; no repeated gameplay, executable-startup, updater or ZIP readback tests.'}
(out/'package-result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result))
