from pathlib import Path
import json,hashlib,copy
root=Path(__file__).resolve().parents[1]
base=json.loads((root/'data/art_staged16_units.json').read_text(encoding='utf-8'))['units']['2:2']
path=root/'data/art_sprite_display_corrections_20261024.json';data=json.loads(path.read_text(encoding='utf-8'))
change=data['units']['2:2'];clip=base['actions']['walk'];overrides=change.setdefault('actions',{}).setdefault('walk',{}).setdefault('frame_overrides',[])
indices=[row*16+10 for row in range(clip['rows'])];overrides[:]=[item for item in overrides if item['index'] not in indices]
for row in range(clip['rows']):
    item=copy.deepcopy(clip['frames'][row*16+6]);item['index']=row*16+10;item['file']=clip['file'];item['mirror_x']=not item.get('mirror_x',False)
    item['scale_hint']=float(item.get('scale_hint',base['scale_hint']))/base['scale_hint']*change.get('scale_hint',base['scale_hint'])*change.get('heading_factors',{}).get('6',1)
    overrides.append(item)
path.write_text(json.dumps(data,separators=(',',':')),encoding='utf-8')
source=root/clip['file'].replace('res://','')
(root/'docs/owl-archer-sw-fix-20261024.json').write_text(json.dumps({'unit':'2:2','action':'walk','heading':10,'source_heading':6,'rows':clip['rows'],'operation':'Reflect the existing southeast walking sequence for southwest, preserving every other heading and action.','source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'original_preserved':True},indent=2),encoding='utf-8')
print('OWL_ARCHER_SW existing southeast reflected for7 southwest walk frames')
