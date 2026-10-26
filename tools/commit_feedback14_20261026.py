from pathlib import Path
import subprocess, json
root=Path(__file__).resolve().parents[1]
files=['AGENTS.md','README.md','project.godot','data/game.json','data/update_channel.json','docs/USER_FEEDBACK.md','docs/FEEDBACK_FIXES14_20261026.md','scripts/game_updater.gd','tests/updater_startup_lifecycle_20261026_test.gd']
files += ['tools/'+name for name in ['prepare_feedback14_20261026.cjs','export_feedback14_20261026.cjs','verify_feedback14_startup_20261026.cjs','verify_feedback14_release_20261026.cjs','package_feedback14_20261026.py','publish_feedback14_20261026.cjs','commit_feedback14_20261026.py']]
files += [str(p.relative_to(root)).replace('\\','/') for p in (root/'docs/verification_feedback14_20261026').glob('*.json')]
for item in files[:]:
    if item.endswith('.gd') and (root/(item+'.uid')).is_file():files.append(item+'.uid')
assert all((root/p).is_file() for p in files)
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip(),'Preserve unrelated staged work'
subprocess.run(['git','add','--',*files],cwd=root,check=True)
subprocess.run(['git','commit','-m','Fix update check stalled during prepared title-to-menu transition (0.6.8)'],cwd=root,check=True)
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
p=root/'build/feedback14_20261026/release-validation.json';r=json.loads(p.read_text(encoding='utf-8'));r['commit']=commit;p.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'commit':commit,'files':len(files)}))
