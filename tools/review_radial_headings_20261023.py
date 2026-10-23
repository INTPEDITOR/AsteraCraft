"""Lossless figure separation and labelled direction review; never invents poses."""
from pathlib import Path
import json, math, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'build/visual_qa_20261023'
NAMES = ['N','NNE','NE','ENE','E','ESE','SE','SSE','S','SSW','SW','WSW','W','WNW','NW','NNW']

def components(im, threshold=32, min_area=500):
    mask = np.asarray(im)[:,:,3] > threshold
    parent=[]; runs=[]; previous=[]
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i=parent[i]
        return i
    for y,row in enumerate(mask):
        edge=np.diff(np.r_[False,row,False].astype(np.int8))
        current=[]; cursor=0
        for left,right in zip(np.flatnonzero(edge==1),np.flatnonzero(edge==-1)):
            index=len(parent);parent.append(index)
            runs.append((y,int(left),int(right)));current.append(index)
            while cursor<len(previous) and runs[previous[cursor]][2]<=left:cursor+=1
            j=cursor
            while j<len(previous) and runs[previous[j]][1]<right:
                parent[find(previous[j])]=find(index);j+=1
        previous=current
    groups={}
    for i,run in enumerate(runs):groups.setdefault(find(i),[]).append(run)
    result=[]
    for group in groups.values():
        area=sum(r-l for y,l,r in group)
        if area<min_area:continue
        bounds=(min(l for y,l,r in group),min(y for y,l,r in group),max(r for y,l,r in group),max(y for y,l,r in group)+1)
        center=(sum((l+r-1)*.5*(r-l) for y,l,r in group)/area,sum(y*(r-l) for y,l,r in group)/area)
        result.append(dict(area=area,bounds=bounds,center=center,runs=group))
    return result

def circle(im):
    figures=components(im)
    if len(figures)!=16:raise ValueError(f'Expected 16 separate silhouettes, found {len(figures)}')
    for figure in figures:
        x,y=figure['center']
        angle=math.atan2((x-im.width/2)/im.width,(im.height/2-y)/im.height)%(2*math.pi)
        figure['slot']=round(angle/(math.pi/8))%16
    if sorted(f['slot'] for f in figures)!=list(range(16)):raise ValueError('Circle slots overlap or are missing')
    return sorted(figures,key=lambda f:f['slot'])

def isolate(im, figure):
    l,t,r,b=figure['bounds'];box=(max(0,l-3),max(0,t-3),min(im.width,r+3),min(im.height,b+3))
    tile=im.crop(box);support=Image.new('L',tile.size);draw=ImageDraw.Draw(support)
    for y,left,right in figure['runs']:draw.line((left-box[0],y-box[1],right-1-box[0],y-box[1]),fill=255)
    support=support.filter(ImageFilter.MaxFilter(5));a=np.array(tile)
    a[:,:,3]=np.where(np.asarray(support)>0,a[:,:,3],0)
    return Image.fromarray(a)

def review(poses, path, title):
    canvas=Image.new('RGBA',(1400,1400),'#20262e');draw=ImageDraw.Draw(canvas)
    draw.text((560,630),title,fill='white');draw.text((560,650),'N=BACK / S=FRONT',fill='#b8c3ce')
    for slot,tile in enumerate(poses):
        angle=slot*math.pi/8;center=np.array([700+520*math.sin(angle),700-520*math.cos(angle)])
        scale=min(190/max(tile.width,tile.height),1)
        thumb=tile.resize((round(tile.width*scale),round(tile.height*scale)),Image.Resampling.LANCZOS)
        canvas.alpha_composite(thumb,tuple(np.rint(center-np.array(thumb.size)/2).astype(int)))
        label=center+np.array([math.sin(angle),-math.cos(angle)])*118
        draw.text(tuple(label-[24,6]),f'{slot:02d} {NAMES[slot]}',fill='#e2e8f0')
    path.parent.mkdir(parents=True,exist_ok=True);canvas.save(path)

def main():
    units=json.loads((ROOT/'build/staged16_20261023/units.json').read_text(encoding='utf-8-sig'))
    reports=[]
    for unit in units:
        race,kind=unit['race'],unit['id'];key=f'r{race}_u{kind:02d}'
        if race==0:
            old=json.loads((ROOT/f'assets/staged16_20261023/race0/u{kind:02d}_base/source-crop-check.json').read_text())
            source=Path(old['source'])
        else:source=ROOT/f'assets/staged16_20261023/race{race}/sources/u{kind:02d}_base16_circular_v1.png'
        im=Image.open(source).convert('RGBA');a=np.asarray(im)[:,:,3]
        record=dict(key=f'{race}:{kind}',name=unit['name'],source=str(source),sha256=hashlib.sha256(source.read_bytes()).hexdigest(),direction_semantics='pending_visual_review',integrated=unit['integrated'])
        try:
            figures=circle(im);poses=[isolate(im,f) for f in figures]
            dest=QA/'canonical'/key;dest.mkdir(parents=True,exist_ok=True)
            for slot,tile in enumerate(poses):tile.save(dest/f'{slot:02d}_{NAMES[slot]}.png')
            review(poses,QA/'canonical'/f'{key}.png',key+' '+unit['role'])
            record.update(separated=16,geometry_pass=True,bounds=[f['bounds'] for f in figures],source_border_clear=not any((a[0]>32).tolist()+(a[-1]>32).tolist()+(a[:,0]>32).tolist()+(a[:,-1]>32).tolist()))
        except ValueError as exc:record.update(geometry_pass=False,error=str(exc))
        reports.append(record)
    (QA/'all44-base-crop-review.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'units':len(reports),'separated':sum(r['geometry_pass'] for r in reports),'failed':[r for r in reports if not r['geometry_pass']]},ensure_ascii=True))

if __name__=='__main__':main()
