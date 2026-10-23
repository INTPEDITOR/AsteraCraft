"""Register seven authored west walk poses without mirroring other headings."""
import hashlib, json, statistics
from pathlib import Path
import numpy as np
from PIL import Image
from review_radial_headings_20261023 import components, isolate

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/staged16_20261023/race2/sources/u00_W_walk7_20261024_v1.png'
OUT=ROOT/'assets/staged16_20261023/race2/u00_W_walk_fix_20261024'

def torso(image):
    a=np.asarray(image).astype(float)
    r,g,b,alpha=[a[:,:,i] for i in range(4)]
    mask=(alpha>224)&(r>125)&(g>100)&(b>65)&(r<g*1.65)&(g<b*1.8)
    yy,xx=np.nonzero(mask)
    assert len(xx)>60
    return len(xx),np.array([xx.mean(),yy.mean()])

def main():
    unit=json.loads((ROOT/'data/art_staged16_units.json').read_text('utf-8'))['units']['2:0']
    clip=unit['actions']['idle'];reference=clip['frames'][12]
    x,y,w,h=reference['region']
    image=Image.open(ROOT/clip['file'].removeprefix('res://')).convert('RGBA').crop((x,y,x+w,y+h))
    area,pivot=torso(image)
    source=Image.open(SOURCE).convert('RGBA')
    figures=sorted(components(source,32,2000),key=lambda f:f['center'][0])
    assert len(figures)==7,('Expected seven separate complete poses',len(figures))
    tiles=[isolate(source,f) for f in figures]
    metrics=[torso(tile) for tile in tiles]
    scale=(area/statistics.median(a for a,p in metrics))**.5
    sheet=Image.new('RGBA',(2240,320));overrides=[]
    for phase,(tile,(a,p)) in enumerate(zip(tiles,metrics)):
        tile=tile.resize((round(tile.width*scale),round(tile.height*scale)),Image.Resampling.LANCZOS)
        xy=np.rint(pivot-p*scale).astype(int)
        frame=Image.new('RGBA',(320,320));frame.alpha_composite(tile,tuple(xy))
        bounds=frame.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
        assert bounds and min(bounds)>3 and max(bounds)<316
        sheet.alpha_composite(frame,(phase*320,0))
        overrides.append({'index':phase*16+12,'file':'res://assets/staged16_20261023/race2/u00_W_walk_fix_20261024/walk_W7.png','region':[phase*320,0,320,320],'anchor':reference['anchor'],'scale_hint':192.414,'bounds':[bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]]})
    OUT.mkdir(parents=True,exist_ok=True);sheet.save(OUT/'walk_W7.png')
    file=ROOT/'data/art_sprite_display_corrections_20261024.json'
    corrections=json.loads(file.read_text('utf-8'));entry=corrections['units']['2:0']
    for f in overrides:f['scale_hint']=entry['scale_hint']
    entry['actions']={'walk':{'frame_overrides':overrides}}
    entry['walk_repair']={'heading':12,'source':SOURCE.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'method':'Seven authored LEFT-facing walk poses, one constant torso scale, no mirrored or duplicate phases; other 105 walk frames preserved'}
    file.write_text(json.dumps(corrections,ensure_ascii=False,indent=2)+'\n','utf-8')
    print('Registered seven WEST walk poses. scale=',scale)

if __name__=='__main__':main()
