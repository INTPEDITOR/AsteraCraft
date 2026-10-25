from pathlib import Path
import subprocess
out=Path('build/fog-north-20261025');out.mkdir(exist_ok=True)
main=subprocess.check_output(['git','show','c62fa1d:scripts/main.gd']).decode('utf-8')
fog=subprocess.check_output(['git','show','c62fa1d:scripts/fog_canvas.gd']).decode('utf-8')
(out/'legacy-main.gd').write_text(main.replace('var _fog_canvas: ACFogCanvas','var _fog_canvas').replace('ACFogCanvas.new()','load("res://build/fog-north-20261025/legacy-fog.gd").new()'),encoding='utf-8')
(out/'legacy-fog.gd').write_text(fog.replace('class_name ACFogCanvas',''),encoding='utf-8')
