"""Commit the approved release source; preserve unrelated untracked artwork."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
files=[
 'AGENTS.md','README.md','project.godot','data/game.json','data/update_channel.json','data/ai_tactics.json',
 'scripts/bot_ai.gd','scripts/bot_tactics.gd','scripts/bot_missions.gd','scripts/bot_skills.gd','scripts/core.gd','scripts/world_map.gd','scripts/menu_pages.gd',
 'docs/USER_FEEDBACK.md','docs/passive-research-20261024.json','docs/AI_TACTICS_IMPLEMENTED_20261026.md','docs/ai-tactics-review-20261025.json','docs/melee-balance-20261025.json','docs/FEEDBACK_FIXES12_20261026.md',
 'docs/verification_ai_tactics_20261026/checks.json','docs/verification_melee_balance_20261025/checks.json',
 'tests/bot_ai_v062_test.gd','tests/ai_coordination_20261026_test.gd','tests/ai_match_20261026_test.gd','tests/ai_missions_20261026_test.gd','tests/ai_tactics_20261026_test.gd','tests/ai_tactics_parse_20261026_test.gd','tests/melee_balance_20261025_test.gd','tests/single_mirror_match_20261025_test.gd','tests/worker_centerline_20261026_test.gd','tests/worker_passage_equivalence_20261026_test.gd',
 'tools/define_passive_research_20261024.cjs','tools/define_ai_tactics_20261026.cjs','tools/verify_ai_tactics_20261026.cjs','tools/verify_melee_balance_20261025.py',
 'tools/prepare_feedback12_release_20261026.py','tools/export_feedback12_20261026.cjs','tools/package_feedback12_20261026.py','tools/publish_feedback12_20261026.cjs','tools/commit_feedback12_release_20261026.py',
 'work/define_army_tactics_75_20261026.cjs','work/apply_melee_balance_20261025.py',
]
for item in files[:]:
    if item.endswith('.gd') and (root/(item+'.uid')).is_file():files.append(item+'.uid')
assert all((root/p).is_file() for p in files)
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip(),'Unrelated staged work must be preserved'
subprocess.run(['git','add','--',*files],cwd=root,check=True)
subprocess.run(['git','commit','-m','Release 0.6.6 with faction tactics, Hell AI and centered worker passages'],cwd=root,check=True)
