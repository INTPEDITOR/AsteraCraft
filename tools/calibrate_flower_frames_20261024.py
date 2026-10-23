"""Normalize authored flower body area per heading, never the reaching leaves."""
from pathlib import Path
import json, math
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
def area(image):
    a=np.asarray(image).astype(float);r,g,b,alpha=[a[:,:,i] for i in range(4)]
    return int(((alpha>224)&(r>155)&(g>60)&(g<r*.85)&(b<100)).sum())

def main():
    u=json.loads((ROOT/'data/art_staged16_units.json').read_text('utf-8'))['units']['1:7']
    path=ROOT/'data/art_sprite_display_corrections_20261024.json';catalog=json.loads(path.read_text('utf-8'));change=catalog['units']['1:7'];cache={}
    def pixels(clip,f):
        file=f.get('file',clip['file'])
        if file not in cache:cache[file]=Image.open(ROOT/file.removeprefix('res://')).convert('RGBA')
        x,y,w,h=f['region'];return area(cache[file].crop((x,y,x+w,y+h)))
    targets=[]
    for heading,f in enumerate(u['actions']['idle']['frames']):
        hint=f.get('scale_hint',u['scale_hint'])*change['scale_hint']/u['scale_hint']*change.get('heading_factors',{}).get(str(heading),1)
        targets.append(pixels(u['actions']['idle'],f)/hint**2)
    rows=[]
    for action in ['idle','walk','attack']:
        clip=u['actions'][action];overrides=[]
        for index,frame in enumerate(clip['frames']):
            count=pixels(clip,frame);assert count>30
            corrected=frame.copy();corrected['file']=frame.get('file',clip['file']);corrected['scale_hint']=math.sqrt(count/targets[index%16]);corrected['index']=index
            overrides.append(corrected)
            rows.append({'action':action,'index':index,'hint':corrected['scale_hint'],'orange_body_area':count})
        change.setdefault('actions',{})[action]={'frame_overrides':overrides}
    change['body_normalization']='All 240 living frames match the orange body area of that heading idle pose, after the NNW idle-size correction. Leaves/feet and death effects are excluded.'
    path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n','utf-8')
    (ROOT/'build/visual_feedback_20261024/flower-size-corrections.json').write_text(json.dumps(rows,indent=2)+'\n','utf-8')
    print('Flower:',len(rows),'living frames calibrated to fixed body size per heading')

if __name__=='__main__':main()
