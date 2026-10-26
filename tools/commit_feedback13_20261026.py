from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
files=['AGENTS.md','README.md','project.godot','data/game.json','data/ai_tactics.json','data/update_channel.json','data/ai_tactic_results_20261026.json','docs/USER_FEEDBACK.md','docs/FEEDBACK_FIXES13_20261026.md']
files += ['scripts/'+name+'.gd' for name in ['abilities','assets','bot_ai','bot_missions','bot_skills','bot_tactics','burst_weapon','citrus_brood','core','data','main','new_units','research','rts_hud','startup_screen','world_map','action_meter','bot_action_budget','bot_ara_policy','bot_citrus_air_raids','bot_combat_policy','bot_difficulty','bot_economy','bot_fortress_policy','bot_harassment','bot_raid_orders','bot_recon','bot_tactic_learning','worker_motion']]
files += ['tests/'+name+'.gd' for name in ['feedback13_balance_difficulty_20261026_test','two_workers_per_as_20261026_test','bot_apm_20261026_test','ai_combat_v3_20261026_test','ara_restore_behaviour_20261026_test','ai_environment_benchmark_20261026','golem_shield_cap_20261026_test','shield_ranged_reduction_20261026_test']]
files += ['tools/'+name for name in ['prepare_feedback13_20261026.cjs','export_feedback13_20261026.cjs','verify_feedback13_pack_20261026.cjs','verify_feedback13_release_20261026.cjs','package_feedback13_20261026.py','publish_feedback13_20261026.cjs','commit_feedback13_20261026.py']]
files += [str(p.relative_to(root)).replace('\\','/') for p in (root/'docs/verification_feedback13_20261026').glob('*.json')]
for item in files[:]:
    if item.endswith('.gd') and (root/(item+'.uid')).is_file():files.append(item+'.uid')
assert all((root/p).is_file() for p in files)
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip(),'Preserve unrelated staged work'
subprocess.run(['git','add','--',*files],cwd=root,check=True)
subprocess.run(['git','add','-f','--','work/.gdignore','build/.gdignore'],cwd=root,check=True)
subprocess.run(['git','commit','-m','Release 0.6.7 with balanced armies, tactical research and six AI difficulty goals'],cwd=root,check=True)
