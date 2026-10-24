from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'data/art_sprite_display_corrections_20261024.json'
data=json.loads(path.read_text(encoding='utf-8-sig'));unit=data['units']['1:10']
removed={}
for action,clip in unit.get('actions',{}).items():
    old=clip.get('frame_overrides',[])
    bad=[f for f in old if int(f['index'])%16 in (2,3) and f.get('mirror_x',False)]
    removed[action]=[int(f['index']) for f in bad]
    clip['frame_overrides']=[f for f in old if f not in bad]
unit['rejected_direction_correction']='Prior NE/ENE mirror overrides were incorrect: original frame heads already face upper-right. Removed after native raw/applied comparison and user screenshot 338c7ddb.'
unit['direction_correction']='Use original unreflected NE/ENE idle, seven wingbeat phases and seven attack phases. Other headings and median scale retained.'
path.write_text(json.dumps(data,separators=(',',':'),ensure_ascii=False),encoding='utf8')
report={'unit':'1:10','removed_mirror_overrides':removed,'original_sprite_files_unchanged':True,'evidence':'Native raw-v-applied gallery: original NE/ENE heads point upper-right; erroneous reflected runtime heads point upper-left.'}
(ROOT/'docs/citrus-bat-heading-fix-20261024.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report))
