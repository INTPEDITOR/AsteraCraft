from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
out=root/'build/feedback9_20261025'
qa=root/'docs/verification_feedback9_20261025'
checks={}
for name,file in {
    'source-movement':root/'docs/verification_movement_20261025/summary.json',
    'source-attack':root/'docs/verification_move_attack_20261025/summary.json',
    'pack':out/'pack-result.json',
    'windows-startup':out/'exe-smoke.json',
    'packaged-siege':out/'siege-pack-result.json',
    'archive':out/'package-result.json',
    'update-install':root/'build/updater-feedback9-e2e-20261025/result.json',
}.items():
    data=json.loads(file.read_text(encoding='utf-8'))
    assert data['passed'],(name,data)
    shutil.copy2(file,qa/(name+'.json'))
    checks[name]=data
assert checks['pack']['checks']==35382
assert checks['packaged-siege']['checks']==8 and checks['packaged-siege']['distance']==11.5
assert checks['packaged-siege']['damage']>0
assert checks['update-install']['tag']=='feedback9-20261025' and checks['update-install']['checks']==11
for file in ['scripts/core.gd','scripts/data.gd','scripts/rts_hud.gd']:
    assert hashlib.sha256((root/file).read_bytes()).hexdigest()==checks['source-attack']['source_sha256'][file]
channel=json.loads((root/'data/update_channel.json').read_text(encoding='utf-8'))
assert channel['tag']=='feedback9-20261025'
assert json.loads((root/'data/game.json').read_text(encoding='utf-8'))['version']=='0.6.3'
for file in ['tank-mobile-range7.png','tank-deployed-range12.png']:
    shutil.copy2(out/'siege-captures'/file,qa/file)
result={'passed':True,'version':'0.6.3','release':'feedback9-20261025','checks':checks}
(qa/'exports.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if '--committed' in sys.argv:
    sha=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    package=checks['archive']
    manifest={'passed':True,'commit':sha,'pack_checks':checks['pack']['checks'],'native_hud_checks':8,'native_images':12,'update_checks':11,'sha256':package['sha256'],'bytes':package['bytes'],'validation':'docs/verification_feedback9_20261025/exports.json'}
    (out/'release-validation.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('FEEDBACK9_EXPORTS_VERIFIED',json.dumps({'passed':True,'bytes':checks['archive']['bytes'],'pack_checks':checks['pack']['checks']}))
