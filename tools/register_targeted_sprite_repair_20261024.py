"""Pack complete authored figures only. Never mirror, rotate or synthesize poses."""
import argparse, hashlib, json, statistics
from pathlib import Path
import numpy as np
from PIL import Image
from review_radial_headings_20261023 import components, isolate

ROOT=Path(__file__).resolve().parents[1]

def metric(image,race,kind):
    a=np.asarray(image).astype(float);r,g,b,alpha=[a[:,:,i] for i in range(4)]
    if race==1:mask=(alpha>224)&(r>155)&(g>60)&(g<r*.85)&(b<100)
    elif kind==10:mask=(alpha>224)&(r>20)&(g>18)&(b>18)&(r<g*1.45)&(g<b*1.7)
    else:mask=(alpha>224)&(r>125)&(g>100)&(b>65)&(r<g*1.65)&(g<b*1.8)
    yy,xx=np.nonzero(mask);assert len(xx)>40,('No stable body material',race,kind)
    return len(xx),np.array([xx.mean(),yy.mean()])

def main():
    p=argparse.ArgumentParser();p.add_argument('--unit',required=True);p.add_argument('--source',required=True);p.add_argument('--rows',nargs='+',required=True);p.add_argument('--source-rows',type=int,nargs='*');p.add_argument('--idle-from',type=int,nargs='*',default=[]);p.add_argument('--alias',nargs='*',default=[]);args=p.parse_args()
    race,kind=map(int,args.unit.split(':'));source=Path(args.source).resolve()
    im=Image.open(source).convert('RGBA');figures=None
    selected=args.source_rows if args.source_rows is not None else list(range(len(args.rows)))
    assert len(selected)==len(args.rows)
    source_row_count=max(selected)+1
    expected=source_row_count*7
    for threshold in [32,128,224]:
        found=components(im,threshold,600)
        if len(found)>expected:
            ranked=sorted(found,key=lambda f:f['area'],reverse=True);count=expected
            # Fired arrows are separate components; the game already renders
            # its real projectile. Keep only the seven complete large bodies.
            if ranked[count-1]['area']>ranked[count]['area']*10:found=ranked[:count]
        if len(found)==expected:figures=found;break
    assert figures is not None,('Complete figure count mismatch',len(found),expected)
    original=json.loads((ROOT/'data/art_staged16_units.json').read_text('utf-8'))['units'][args.unit]
    file=ROOT/'data/art_sprite_display_corrections_20261024.json';catalog=json.loads(file.read_text('utf-8'));change=catalog['units'].setdefault(args.unit,{})
    base_hint=original.get('scale_hint',200);hint=change.get('scale_hint',base_hint)
    out=ROOT/f'assets/staged16_20261023/race{race}/u{kind:02d}_targeted_fix_20261024';out.mkdir(parents=True,exist_ok=True)
    atlas_name=source.stem+'_packed.png'
    sheet=Image.new('RGBA',(2240,320*len(args.rows)));ordered=sorted(figures,key=lambda f:f['center'][1]);report=[]
    for row,target in enumerate(args.rows):
        action,heading=target.split(':');heading=int(heading)
        source_row=selected[row]
        group=sorted(ordered[source_row*7:source_row*7+7],key=lambda f:f['center'][0])
        assert max(f['center'][1] for f in group)-min(f['center'][1] for f in group)<im.height/source_row_count*.5,'Ambiguous row order'
        for f in group:
            l,t,r,b=f['bounds'];assert l>0 and t>0 and r<im.width and b<im.height,'Source is cut off'
        tiles=[isolate(im,f) for f in group];metrics=[metric(t,race,kind) for t in tiles]
        idle=original['actions']['idle'];ref=idle['frames'][heading];x,y,w,h=ref['region']
        reference=Image.open(ROOT/ref.get('file',idle['file']).removeprefix('res://')).convert('RGBA').crop((x,y,x+w,y+h))
        area,pivot=metric(reference,race,kind);scale=(area/statistics.median(a for a,p in metrics))**.5
        # A shared row scale retains the exact apparent body size. Larger arm
        # reaches get extra transparent canvas space via the matching hint.
        extent=np.array([0.,0.])
        for tile,(a,center) in zip(tiles,metrics):extent=np.maximum(extent,np.maximum(center,np.array(tile.size)-center)*scale)
        shrink=min(1.,150/max(extent));scale*=shrink
        row_hint=ref.get('scale_hint',base_hint)*hint/base_hint*change.get('heading_factors',{}).get(str(heading),1)*shrink
        anchor=(np.array([160.,160.])-(pivot-np.array(ref['anchor']))*shrink).tolist()
        overrides=change.setdefault('actions',{}).setdefault(action,{}).setdefault('frame_overrides',[])
        for phase,(tile,(a,center)) in enumerate(zip(tiles,metrics)):
            tile=tile.resize((max(1,round(tile.width*scale)),max(1,round(tile.height*scale))),Image.Resampling.LANCZOS)
            xy=np.rint(np.array([160.,160.])-center*scale).astype(int)
            frame=Image.new('RGBA',(320,320));frame.alpha_composite(tile,tuple(xy))
            bounds=frame.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox();assert bounds and min(bounds)>3 and max(bounds)<317
            sheet.alpha_composite(frame,(phase*320,row*320))
            f={'index':phase*16+heading,'file':'res://'+(out/atlas_name).relative_to(ROOT).as_posix(),'region':[phase*320,row*320,320,320],'anchor':anchor,'scale_hint':row_hint,'bounds':[bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]]}
            overrides[:]=[v for v in overrides if v['index']!=f['index']];overrides.append(f)
            if phase==0 and row in args.idle_from:
                neutral=f.copy();neutral['index']=heading
                idle_overrides=change['actions'].setdefault('idle',{}).setdefault('frame_overrides',[])
                idle_overrides[:]=[v for v in idle_overrides if v['index']!=heading];idle_overrides.append(neutral)
        report.append({'row':row,'source_row':source_row,'action':action,'heading':heading,'frames':7,'constant_scale':scale,'hint':row_hint})
    for alias in args.alias:
        target,action=alias.split(':');change['actions'][target]=json.loads(json.dumps(change['actions'][action]))
    sheet.save(out/atlas_name)
    change.setdefault('targeted_repairs',[]).append({'source':source.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'rows':report,'original_atlas_preserved':True,'mirroring_used':False})
    file.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n','utf-8')
    (out/(source.stem+'_registration.json')).write_text(json.dumps(report,indent=2)+'\n','utf-8')
    print(args.unit,'registered',len(args.rows)*7,'authored poses')

if __name__=='__main__':main()
