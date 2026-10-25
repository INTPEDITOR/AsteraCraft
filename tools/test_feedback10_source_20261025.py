from pathlib import Path
import subprocess,json,time
root=Path(__file__).resolve().parents[1]
out=root/'build/feedback10-source';out.mkdir(exist_ok=True)
tests=[
 ('worker','worker_passages_20261025_test.gd',[]),
 ('bot-budget','bot_ai_v062_test.gd',[]),
 ('bot-research','passive_bot_20261024_test.gd',[]),
 ('placement','base_resource_spacing_20261025_test.gd',['feedback10']),
 ('construction','base_spacing_commands_20261025_test.gd',[]),
 ('preview','base_spacing_preview_worker_20261025_test.gd',[]),
 ('cliff','cliff_guard_20261025_test.gd',['feedback10']),
 ('formations','group_move_continuity_20261025_test.gd',['feedback10']),
 ('types','move_continuity_20261025_test.gd',['feedback10']),
 ('melee','melee_follow_20261024_test.gd',[]),
 ('brood','brood_collision_policy_test.gd',[]),
 ('ramps','source_terrain_detail_test.gd',[]),
]
records=[]
for name,script,args in tests:
 t=time.monotonic()
 result=subprocess.run(['node','tools_run_godot.js','--headless','--path','.','--script','tests/'+script,'--',*args],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
 text=result.stdout.decode('utf-8',errors='replace');(out/(name+'.log')).write_text(text,encoding='utf-8')
 passed=result.returncode==0 and not any(s in text for s in ['SCRIPT ERROR','ERROR:','FAIL '])
 records.append({'name':name,'passed':passed,'exit_code':result.returncode,'seconds':round(time.monotonic()-t,2)})
 print(json.dumps(records[-1]),flush=True)
 if not passed:print(text[-4000:],flush=True)
 (out/'result.json').write_text(json.dumps({'passed':all(r['passed'] for r in records),'runs':records},indent=2),encoding='utf-8')
 if not passed:raise SystemExit(1)
