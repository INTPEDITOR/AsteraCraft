from pathlib import Path
p=Path('build/fog-north-20261025')
profile=Path('tests/render_profile_main_v061.gd').read_text(encoding='utf-8').replace('res://tests/menu_v04_harness.gd','res://build/fog-north-20261025/legacy-main.gd')
(p/'legacy-profile.gd').write_text(profile,encoding='utf-8')
test=Path('tests/fog_render_v061_test.gd').read_text(encoding='utf-8').replace('res://tests/render_profile_main_v061.gd','res://build/fog-north-20261025/legacy-profile.gd').replace('res://build/qa-v061-fog-','res://build/legacy-qa-v061-fog-')
(p/'legacy-performance.gd').write_text(test,encoding='utf-8')
