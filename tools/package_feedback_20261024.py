from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib, json
root=Path(__file__).resolve().parents[1]
out=root/'build/feedback_fixed_20261024'
name='AsteraCraft-Windows-feedback-20261024.zip'
files=['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll','README.txt','game_icon.ico']
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
