from pathlib import Path
import json, shutil, subprocess, sys

root=Path(__file__).resolve().parents[1]
out=root/'build/feedback8_20261025'
qa=root/'docs/verification_feedback8_20261025'
checks={}
for name,file in {
    'source-menus':qa/'source-menu-validation.json',
    'pack':out/'pack-result.json',
    'windows-startup':out/'exe-smoke.json',
    'packaged-menus':out/'menu-pack-result.json',
    'archive':out/'package-result.json',
    'update-install':root/'build/updater-feedback8-e2e-20261025/result.json',
}.items():
    data=json.loads(file.read_text(encoding='utf-8'))
    assert data['passed'],(name,data)
    if file.resolve()!=(qa/(name+'.json')).resolve():shutil.copy2(file,qa/(name+'.json'))
    checks[name]=data
assert checks['source-menus']['checks']==107 and checks['packaged-menus']['checks']==107
assert checks['packaged-menus']['factions']==3
assert checks['update-install']['tag']=='feedback8-20261025'
for race in range(3):shutil.copy2(out/f'menu-captures/pause-r{race}.png',qa/f'export-menu-r{race}.png')
result={'passed':True,'version':'0.6.2','release':'feedback8-20261025','checks':checks}
(qa/'exports.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
if '--committed' in sys.argv:
    sha=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    package=checks['archive']
    manifest={'passed':True,'commit':sha,'source_menu_checks':107,'exported_menu_checks':107,'factions':3,'native_images':12,'update_checks':checks['update-install']['checks'],'sha256':package['sha256'],'bytes':package['bytes'],'validation':'docs/verification_feedback8_20261025/exports.json'}
    (out/'release-validation.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('FEEDBACK8_EXPORTS_VERIFIED',json.dumps({'passed':True,'bytes':checks['archive']['bytes'],'checks':107}))
