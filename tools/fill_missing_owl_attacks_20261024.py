"""Pack only the 42 newly requested attack poses; no visual QA or test run."""
import argparse
import copy
import datetime
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from pack_owl_staged16_20261023 import grid, ivory, contact

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'data/art_staged16_units.json'
EXPECTED={2:{7,15},10:{11},13:{7,11,15}}

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def write(path,value):
    tmp=path.with_name(path.name+'.fill-tmp')
    tmp.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    tmp.replace(path)

def local(path):
    return ROOT/path.removeprefix('res://') if path.startswith('res://') else Path(path)

def cell(definition,clip,index):
    item=clip['frames'][index]
    im=Image.open(local(item.get('file',clip['file']))).convert('RGBA')
    x,y,w,h=item['region']
    return im.crop((int(x),int(y),int(x+w),int(y+h))),item

def run(jobs):
    assert {int(u):{int(h) for h in sources} for u,sources in jobs.items()}==EXPECTED
    manifest=read(MANIFEST)
    drafts_path=ROOT/'data/art_staged16_race2_drafts.json'
    drafts=read(drafts_path)
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup=ROOT/'build/staged16_20261024'/('missing42-backup-'+stamp)
    backup.mkdir(parents=True,exist_ok=True)
    for p in [MANIFEST,drafts_path]: (backup/p.name).write_bytes(p.read_bytes())
    results=[]
    for unit,sources in jobs.items():
        key='2:'+unit
        definition=copy.deepcopy(manifest['units'][key])
        clip=definition['actions']['attack']
        atlas_path=local(clip['file'])
        (backup/('u'+unit+'-attack.png')).write_bytes(atlas_path.read_bytes())
        atlas=Image.open(atlas_path).convert('RGBA')
        filled=[]
        for raw_heading,source in sources.items():
            heading=int(raw_heading)
            parts=grid(local(source),7,4)
            tiles=[parts[(p//4,p%4)]['tile'] for p in range(7)]
            base,item=cell(definition,definition['actions']['idle'],heading)
            base_area,_=ivory(base)
            metrics=[ivory(tile) for tile in tiles]
            scale=float(np.sqrt(base_area/np.median([m[0] for m in metrics])))
            scale=min(scale,min(285/max(tile.size) for tile in tiles))
            anchor=np.array(item.get('anchor',definition.get('anchor',[160,220])),dtype=float)
            for phase,tile in enumerate(tiles):
                origin=np.array([metrics[phase][1][0],contact(tile)])
                resized=tile.resize((max(1,round(tile.width*scale)),max(1,round(tile.height*scale))),Image.Resampling.LANCZOS)
                xy=np.rint(anchor-origin*scale).astype(int)
                b=np.array(resized.getbbox()); bounds=b+np.array([*xy,*xy])
                shift=np.maximum(12-bounds[:2],0)-np.maximum(bounds[2:]-308,0)
                xy+=shift
                canvas=Image.new('RGBA',(320,320));canvas.alpha_composite(resized,tuple(xy))
                box=canvas.getbbox()
                atlas.paste(canvas,(heading*320,phase*320))
                clip['frames'][phase*16+heading]={'region':[heading*320,phase*320,320,320], 'bounds':[box[0],box[1],box[2]-box[0],box[3]-box[1]], 'anchor':(anchor+shift).tolist()}
            filled.append({'heading':heading,'poses':7,'source':source,'source_sha256':hashlib.sha256(local(source).read_bytes()).hexdigest()})
        atlas.save(atlas_path)
        clip.pop('unavailable_headings',None)
        clip['authored_frames']=112
        clip['authored_attack_frames']=112
        provenance=definition.setdefault('provenance',{})
        limits=provenance.get('limitations',[])
        resolved=[v for v in limits if v.get('action')=='attack' and v.get('unavailable_headings')]
        provenance['limitations']=[v for v in limits if v not in resolved]
        provenance['resolved_missing_attack_limits']=resolved
        provenance['requested_missing_attack_fill_20261024']={'sources':filled,'poses_added':len(filled)*7,'qa_performed':False,'original_preserved_at':str(backup.relative_to(ROOT))}
        for field in ['missing_attack_headings','unavailable_attack_headings']:
            provenance.pop(field,None)
        manifest['units'][key]=definition
        drafts['units'][key]=copy.deepcopy(definition)
        results.append({'unit':key,'poses_added':len(filled)*7,'attack_sha256':hashlib.sha256(atlas_path.read_bytes()).hexdigest(),'status':definition['status']})
    write(MANIFEST,manifest);write(drafts_path,drafts)
    state_path=ROOT/'docs/art-work-state.json';state=read(state_path)
    state.update(known_missing_authored_actions=[],missing_authored_frame_count=0,current_phase='all44_connected_missing42_added_export_in_progress')
    state['requested_missing_attack_fill_20261024']={'poses_added':42,'units':results,'qa_performed':False}
    write(state_path,state)
    inventory_path=ROOT/'build/staged16_20261023/raw-source-inventory-20261024.json'
    inventory=read(inventory_path)
    inventory.update(known_missing_authored_actions=[],missing_authored_frame_count=0,requested_missing_frames_added=42)
    write(inventory_path,inventory)
    write(backup/'fill-result.json',{'poses_added':42,'units':results,'qa_performed':False})
    print(json.dumps({'poses_added':42,'units':results,'backup':str(backup)}))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--jobs',required=True)
    run(read(Path(parser.parse_args().jobs)))
