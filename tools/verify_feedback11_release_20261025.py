from pathlib import Path
import hashlib,json,subprocess,sys,shutil
root=Path(__file__).resolve().parents[1];out=root/'build/feedback11_20261025';qa=root/'docs/verification_feedback11_20261025';qa.mkdir(parents=True,exist_ok=True)
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
reports={}
for name,file in {
 'pack':out/'pack-result.json','windows-startup':out/'exe-smoke.json','archive':out/'package-result.json',
 'update-install':root/'build/updater-feedback11-e2e-20261025/result.json',
 'source-regression':root/'docs/verification_resource_fog_ai_20261025/summary.json',
}.items():
 data=read(file);assert data['passed'],(name,data);reports[name]=data;shutil.copyfile(file,qa/(name+'.json'))
assert len(reports['pack']['runs'])==21 and all(r['passed'] for r in reports['pack']['runs'])
assert reports['update-install']['checks']==11 and reports['update-install']['tag']=='feedback11-20261025'
assert read(root/'data/update_channel.json')['tag']=='feedback11-20261025'
assert read(root/'data/game.json')['version']=='0.6.5'
results=out/'test-results'
fixtures={
 'spacing':results/'base-resource-spacing-20261025/feedback11/result.json',
 'construction':results/'base-resource-spacing-20261025/commands/result.json',
 'island-mining':results/'spacing3-20261025/island-mining.json',
 'tera':results/'tera-source-comparison-20261025/result.json',
 'ai-staging':results/'ai-staging-20261025/result.json',
 'ai-routes':results/'ai-staging-20261025/source-walk.json',
 'formations':results/'group-move-continuity-20261025/feedback11/result.json',
 'fog':results/'fog-north-20261025/after-fog/result.json',
 'north':results/'fog-north-20261025/after-north/result.json',
 'boundaries':results/'camera-side-bottom-20261025/result.json',
 'spacing-native':results/'spacing3-20261025/native/result.json',
 'fog-cache':results/'fog-north-20261025/projection-cache.json',
}
for name,file in fixtures.items():
 data=read(file);assert data.get('passed',True) and not data.get('failures'),(name,data)
 assert file.stat().st_mtime>= (out/'AsteraCraft.pck').stat().st_mtime,(name,'stale')
 shutil.copyfile(file,qa/(name+'.json'))
assert read(fixtures['tera'])['moved_starts']==0 and read(fixtures['tera'])['tera']==36
assert read(fixtures['island-mining'])['checks']==54
assert read(fixtures['boundaries'])['cases']==135
assert all(not r['incorrect_dark'] for r in read(fixtures['fog'])['records'])
baseline=read(root/'docs/verification_cliff_fix_20261025/formations-before.json')
assert baseline['cases']==read(fixtures['formations'])['cases'],'Existing formation movement changed'
images={
 'fog-same-level.png':results/'fog-north-20261025/after-fog/map0-fog.png',
 'north-units.png':results/'fog-north-20261025/after-north/map0-race0-north.png',
 'boundary-right.png':results/'camera-side-bottom-20261025/map0-race0-right.png',
 'boundary-bottom.png':results/'camera-side-bottom-20261025/map0-race1-bottom.png',
 'spacing3.png':results/'spacing3-20261025/native/map0-race0.png',
}
for name,file in images.items():shutil.copyfile(file,qa/name)
files=['scripts/bot_ai.gd','scripts/core.gd','scripts/fog_canvas.gd','scripts/world_map.gd','scripts/main.gd','data/game.json','data/resource_spacing_20261025.json','data/original_maps.json','data/source_terrain_detail.json']
hashes={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in files}
result={'passed':True,'version':'0.6.5','release':'feedback11-20261025','reports':reports,'source_sha256':hashes,'scope':'Final Windows PCK tests and native screenshots use production code/data/art only from the PCK with external QA drivers and an explicit test-only debug extension. Actual shipping EXE startup with release extension, ZIP CRC/SHA256 and disposable previous-version install/restart are checked separately. Does not claim a live network match or macOS support.'}
(qa/'exports.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if '--committed' in sys.argv:
 sha=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip();package=reports['archive']
 (out/'release-validation.json').write_text(json.dumps({'passed':True,'commit':sha,'sha256':package['sha256'],'bytes':package['bytes'],'validation':'docs/verification_feedback11_20261025/exports.json'},indent=2)+'\n',encoding='utf-8')
print('FEEDBACK11_VERIFIED',json.dumps({'passed':True,'pack_tests':21,'bytes':reports['archive']['bytes'],'sha256':reports['archive']['sha256']}))
