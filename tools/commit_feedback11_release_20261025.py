"""Stage only this approved release; leave unrelated original artwork untouched."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
files=[
 'AGENTS.md','README.md','docs/USER_FEEDBACK.md','docs/RESOURCE_SPACING_20261025.md','docs/RESOURCE_FOG_AI_FOLLOWUP_20261025.md','docs/FEEDBACK_FIXES11_20261025.md',
 'project.godot','data/game.json','data/update_channel.json','data/resource_spacing_20261025.json',
 'scripts/bot_ai.gd','scripts/fog_canvas.gd','scripts/main.gd','scripts/world_map.gd',
 'tests/base_resource_spacing_20261025_test.gd','tests/base_spacing_commands_20261025_test.gd','tests/bot_ai_v062_test.gd','tests/tera_source_comparison_20261025_test.gd',
 'tests/ai_forward_staging_20261025_test.gd','tests/ai_staging_source_walk_20261025_test.gd','tests/fog_north_visual_20261025.gd','tests/fog_projection_cache_20261025_test.gd','tests/python_island_mining_20261025_test.gd','tests/side_bottom_boundary_20261025_test.gd','tests/spacing3_visual_20261025.gd','tests/feedback11_pack_test.gd',
 'tools/plan_resource_spacing_20261025.py','tools/plan_resource_spacing_3_20261025.py','tools/verify_resource_fog_ai_followup_20261025.py',
 'tools/prepare_feedback11_release_20261025.py','tools/test_feedback11_pack_export_20261025.cjs','tools/verify_feedback11_release_20261025.py','tools/publish_feedback11_20261025.cjs','tools/verify_feedback11_public_20261025.cjs','tools/commit_feedback11_release_20261025.py',
 'work/prepare_fog_legacy_20261025.py','work/fog_performance_baseline_20261025.py',
]
for item in files[:]:
 if item.endswith('.gd') and (root/(item+'.uid')).is_file():files.append(item+'.uid')
for folder in ['docs/verification_resource_fog_ai_20261025','docs/verification_feedback11_20261025']:
 files.extend(str(p.relative_to(root)).replace('\\','/') for p in sorted((root/folder).rglob('*')) if p.is_file())
assert all((root/p).is_file() for p in files)
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip(),'Unrelated staged work must be reviewed before release'
subprocess.run(['git','add','--',*files],cwd=root,check=True)
subprocess.run(['git','diff','--cached','--check'],cwd=root,check=True)
subprocess.run(['git','commit','-m','Fix source-map resource spacing, fog projection, camera edges and staged AI attacks'],cwd=root,check=True)
