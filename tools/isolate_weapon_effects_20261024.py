"""Find painted-cell gaps instead of cutting fractional uniform grid cells."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import numpy as np,json,hashlib
root=Path(__file__).resolve().parents[1]
out=root/'assets/weapon_effects_isolated_20261024';out.mkdir(exist_ok=True)
review=root/'build/feedback4-20261024/effects';review.mkdir(parents=True,exist_ok=True)
result={'originals_preserved':True,'method':'Locate the low-opacity gaps between painted effects per row. Extract at integer bounds into separate padded textures; retain the original source artwork.','frames':[],'sources':[]}
def divisions(density,count):
    size=len(density);result=[0];smooth=np.convolve(density,np.ones(3)/3,mode='same')
    for i in range(1,count):
        middle=size*i/count;span=size/count*.27;lo=max(result[-1]+4,int(middle-span));hi=int(middle+span)
        x=np.arange(lo,hi);cost=smooth[lo:hi]+smooth.max()*.012*((x-middle)/span)**2
        result.append(int(x[np.argmin(cost)]))
    return result+[size]
for group,keys in [('projectiles',['bullet','shell','missile','acid','seed','thorn','plasma','bolt']),('impacts',['claw','slash','bash','spark','flame','vine','beam','explosion'])]:
    source=root/f'assets/weapon_{group}_v060.png';image=Image.open(source).convert('RGBA');rgba=np.asarray(image);alpha=rgba[:,:,3].astype(float)/255
    rows=divisions((alpha**2).sum(axis=1),8)
    result['sources'].append({'file':str(source.relative_to(root)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'row_boundaries':rows})
    gallery=Image.new('RGBA',(8*176,8*190),(25,29,33,255));draw=ImageDraw.Draw(gallery)
    for row,key in enumerate(keys):
        top,bottom=rows[row:row+2];columns=divisions((alpha[top:bottom]**2).sum(axis=0),8)
        for phase in range(8):
            left,right=columns[phase:phase+2];tile=image.crop((left,top,right,bottom));pixels=np.asarray(tile).copy()
            # Remove the 1px filtering fringe at a low-opacity cut; core pixels
            # touching a boundary are recorded for explicit review below.
            a=pixels[:,:,3];edge=np.concatenate([a[0,:],a[-1,:],a[:,0],a[:,-1]])
            strong=int((edge>=128).sum())
            yy,xx=np.mgrid[:a.shape[0],:a.shape[1]];distance=np.minimum.reduce([xx,yy,a.shape[1]-1-xx,a.shape[0]-1-yy])
            factor=np.clip(distance/3,0,1);pixels[:,:,3]=(a*factor).astype('uint8')
            tile=Image.fromarray(pixels);box=tile.getbbox()
            assert box,(key,phase)
            tile=tile.crop(box);tile.thumbnail((164,164),Image.Resampling.LANCZOS)
            padded=Image.new('RGBA',(192,192));padded.alpha_composite(tile,((192-tile.width)//2,(192-tile.height)//2))
            name=f'{key}_{phase}.png';padded.save(out/name)
            gallery.alpha_composite(padded.resize((168,168)),(phase*176,row*190+18));draw.text((phase*176,row*190),f'{key}:{phase} edge={strong}',fill='white')
            result['frames'].append({'key':'weapon_'+key,'phase':phase,'source_region':[left,top,right-left,bottom-top],'file':'res://assets/weapon_effects_isolated_20261024/'+name,'strong_boundary_pixels':strong})
    gallery.save(review/f'{group}-isolated.png')
for entry in result['frames']:
    key=entry['key'].replace('weapon_','');phase=entry['phase']
    if entry['strong_boundary_pixels']<=4:continue
    # These source rows join adjacent phases into one painting. Use a complete
    # source-painted pose rather than retaining an opaque cut edge.
    template='shell_6.png' if key=='explosion' and phase<5 else 'shell_7.png' if key=='explosion' else f'{key}_{6 if key=="vine" and phase>=5 else 0}.png'
    full=Image.open(out/template).convert('RGBA')
    amount=min(.98,(.72+.06*phase) if key=='explosion' else (.88+.03*phase))
    scaled=full.resize((round(192*amount),round(192*amount)),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(192,192));canvas.alpha_composite(scaled,((192-scaled.width)//2,(192-scaled.height)//2))
    canvas.save(out/f'{key}_{phase}.png');entry['complete_pose_replacement']=template
for group,keys in [('projectiles',['bullet','shell','missile','acid','seed','thorn','plasma','bolt']),('impacts',['claw','slash','bash','spark','flame','vine','beam','explosion'])]:
    gallery=Image.new('RGBA',(8*176,8*190),(25,29,33,255));draw=ImageDraw.Draw(gallery)
    for row,key in enumerate(keys):
        for phase in range(8):
            gallery.alpha_composite(Image.open(out/f'{key}_{phase}.png').resize((168,168)),(phase*176,row*190+18));draw.text((phase*176,row*190),f'{key}:{phase}',fill='white')
    gallery.save(review/f'{group}-isolated.png')
result['runtime_notes']='Continuous flame keeps its existing complete flame-stream atlas; beams use native connected-line drawing. Joined vine/explosion source phases use complete existing painted poses.'
(root/'data/weapon_effects_isolated_20261024.json').write_text(json.dumps({'frames':result['frames']},separators=(',',':')),encoding='utf-8')
(root/'docs/weapon-effect-review-20261024.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'frames':len(result['frames']),'boundary_review':[(f['key'],f['phase'],f['strong_boundary_pixels']) for f in result['frames'] if f['strong_boundary_pixels']>0]}))
