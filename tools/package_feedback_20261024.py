from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib, json, re, sys
root=Path(__file__).resolve().parents[1]
folder=sys.argv[1] if len(sys.argv)>1 else 'feedback_fixed_20261024'
tag=sys.argv[2] if len(sys.argv)>2 else 'feedback-20261024'
if not re.fullmatch(r'[a-z0-9_-]{1,80}',folder) or not re.fullmatch(r'[a-z0-9_-]{1,80}',tag):
    raise ValueError('Invalid build folder or release tag')
out=root/'build'/folder
name='AsteraCraft-Windows-'+tag+'.zip'
files=['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll','README.txt','game_icon.ico']
if (out/'LICENSES-LevelUp.txt').is_file():files.append('LICENSES-LevelUp.txt')
archive=out/name
with ZipFile(archive,'w',compression=ZIP_DEFLATED,compresslevel=1,allowZip64=True) as z:
    for item in files:z.write(out/item,item)
with ZipFile(archive) as z:
    assert z.namelist()==files
    assert z.testzip() is None
with archive.open('rb') as f:sha=hashlib.file_digest(f,'sha256').hexdigest()
(out/(name+'.sha256')).write_text(sha+'  '+name+'\n',encoding='ascii')
result={'passed':True,'bytes':archive.stat().st_size,'sha256':sha,'files':files}
(out/'package-result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
