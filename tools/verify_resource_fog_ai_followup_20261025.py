"""Collect current local runtime evidence; does not export or publish a release."""
from pathlib import Path
from datetime import datetime
import hashlib,json,re,shutil,subprocess

root=Path(__file__).resolve().parents[1]
out=root/'docs/verification_resource_fog_ai_20261025'
out.mkdir(parents=True,exist_ok=True)
reports=[
 'build/base-resource-spacing-20261025/spacing3/result.json',
 'build/base-resource-spacing-20261025/commands/result.json',
 'build/base-resource-spacing-20261025/preview-worker.json',
 'build/tera-source-comparison-20261025/result.json',
 'build/spacing3-20261025/island-mining.json',
 'build/spacing3-20261025/native/result.json',
 'build/qa-v060/original-map-audit.json',
 'build/fog-north-20261025/after-fog/result.json',
 'build/fog-north-20261025/after-north/result.json',
 'build/fog-north-20261025/projection-cache.json',
 'build/qa-v061-fog-render.json',
 'build/camera-side-bottom-20261025/result.json',
 'build/ai-staging-20261025/result.json',
 'build/ai-staging-20261025/source-walk.json',
 'build/ai-staging-20261025/source-walk-level0.json',
 'build/group-move-continuity-20261025/spacing3/result.json',
 'build/worker-passages-20261025/result.json',
 'build/worker-passages-20261025/jobs.json',
 'build/cliff-fix-20261025/spacing3/result.json',
 'build/difficulty-progression-20261025/response-0.json',
]
rows=[]
for index,name in enumerate(reports):
 p=root/name;data=json.loads(p.read_text(encoding='utf-8'))
 assert data.get('passed',True) and not data.get('failures'),(name,data.get('failures'))
 if 'camera-side-bottom' in name:
  assert p.stat().st_mtime> (root/'tests/side_bottom_boundary_20261025_test.gd').stat().st_mtime,'Latest zoom-boundary run is not finished'
  assert sorted({r['zoom'] for r in data['records']})==[1.0,1.75,2.5]
 if 'after-fog' in name:
  assert all(not r['incorrect_dark'] for r in data['records'])
 target=out/('%02d-'%index+name.split('build/')[1].replace('/','-'))
 shutil.copyfile(p,target)
 rows.append({'report':str(target.relative_to(root)).replace('\\','/'),'origin':name,'checks':data.get('checks'),'cases':data.get('cases') if isinstance(data.get('cases'),int) else len(data.get('records',[])),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})

for name,marker in [('build/highground-3-console.txt','HIGHGROUND_BEAM'),('build/fog-revision-3-console.txt','FOG_REVISION_V061'),('build/fog-memory-3-console.txt','FOG_BUILDING_MEMORY'),('build/ai-staging-parse-console.txt','BOT_AI_V062'),('build/spacing3-melee-console.txt','MELEE_FOLLOW')]:
 content=(root/name).read_text(encoding='utf-8-sig')
 data=json.loads(next(line.split(marker+' ',1)[1] for line in content.splitlines() if marker+' ' in line))
 assert not data['failures'],name
 rows.append({'origin':name,'checks':data['checks'],'passed':True})

sources=['scripts/world_map.gd','scripts/fog_canvas.gd','scripts/main.gd','scripts/bot_ai.gd','data/resource_spacing_20261025.json','data/original_maps.json','data/source_terrain_detail.json','data/terrain_visual_roles.json']
summary={'passed':True,'generated_at':datetime.now().astimezone().isoformat(),'scope':'Local source/runtime verification after feedback10; not a published release','baseline_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'sources':{name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in sources},'reports':rows,'screenshots':{name:len(list((root/name).glob('*.png'))) for name in ['build/spacing3-20261025/native','build/fog-north-20261025/after-fog','build/fog-north-20261025/after-north','build/camera-side-bottom-20261025']}}
(out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'passed':True,'reports':len(rows),'screenshots':summary['screenshots']},ensure_ascii=False))
