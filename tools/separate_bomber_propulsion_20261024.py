"""Separate baked exhaust without repainting the approved bomber hull."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import numpy as np,json,hashlib
root=Path(__file__).resolve().parents[1]
catalog=json.loads((root/'data/art_staged16_units.json').read_text(encoding='utf-8'))
unit=catalog['units']['0:10'];clip=unit['actions']['idle']
source=root/clip['file'].replace('res://','');sheet=Image.open(source).convert('RGBA')
out=root/'assets/bomber_propulsion_20261024';out.mkdir(exist_ok=True)
hulls=Image.new('RGBA',sheet.size);jets=Image.new('RGBA',sheet.size)
frames=[];counts=[];gallery=Image.new('RGBA',(1280,1280),(31,34,38,255));draw=ImageDraw.Draw(gallery)
south=sheet.crop((8*320,0,9*320,320)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
for heading in range(16):
    tile=sheet.crop((heading*320,0,(heading+1)*320,320))
    if heading==0:
        # The opposite heading already has the correct two engine collars.
        # Reuse only that small rear assembly; all other hull pixels stay intact.
        patch=(122,194,200,267);tile.paste(south.crop(patch),patch[:2])
    pixels=np.asarray(tile).copy();original=pixels.copy();rgb=pixels[:,:,:3].astype(int)
    yy,xx=np.mgrid[:320,:320];angle=heading*np.pi/8
    back=(xx-160)*(-np.sin(angle))+(yy-160)*np.cos(angle)
    blue=(pixels[:,:,3]>0)&(rgb[:,:,2]>100)&(rgb[:,:,2]>rgb[:,:,0]+12)&(rgb[:,:,1]>rgb[:,:,0]+8)&(back>30)
    assert blue.sum()>50,heading
    threshold=float(np.percentile(back[blue],12))
    near_blue=np.asarray(Image.fromarray((blue*255).astype('uint8')).filter(ImageFilter.MaxFilter(9)))>0
    white_core=near_blue&(rgb.min(axis=2)>155)&(back>threshold+2)&(pixels[:,:,3]>0)
    # Darken the inner glow inside the nozzle; isolate the external flame.
    inner=blue&(back<=threshold);external=(blue&(back>threshold))|white_core
    pixels[inner,:3]=[16,21,26];pixels[external]=0
    plume=np.zeros_like(pixels);plume[external]=original[external]
    body=Image.fromarray(pixels);exhaust=Image.fromarray(plume)
    hulls.alpha_composite(body,(heading*320,0));jets.alpha_composite(exhaust,(heading*320,0))
    entry=dict(clip['frames'][heading]);entry['file']='res://assets/bomber_propulsion_20261024/hulls.png';entry['region']=[heading*320,0,320,320]
    box=body.getbbox();entry['bounds']=[box[0],box[1],box[2]-box[0],box[3]-box[1]];frames.append(entry)
    counts.append({'heading':heading,'engine_nozzles':2,'removed_baked_flame_pixels':int(external.sum())})
    gallery.alpha_composite(body,((heading%4)*320,(heading//4)*320));draw.text(((heading%4)*320,(heading//4)*320),str(heading),fill='white')
hulls.save(out/'hulls.png');jets.save(out/'exhaust.png')
correction_path=root/'data/art_sprite_display_corrections_20261024.json'
corrections=json.loads(correction_path.read_text(encoding='utf-8'))
change=corrections['units'].setdefault('0:10',{})
change.setdefault('actions',{})['idle']={'frame_overrides':[{'index':i,**f} for i,f in enumerate(frames)]}
correction_path.write_text(json.dumps(corrections,separators=(',',':')),encoding='utf-8')
meta={'file':'res://assets/bomber_propulsion_20261024/exhaust.png','columns':16,'directions':16,'rows':1,'fps':1,'loop':True,'frames':[{'region':[i*320,0,320,320]} for i in range(16)]}
(root/'data/bomber_propulsion_20261024.json').write_text(json.dumps({'scale_hint':unit['scale_hint'],'anchor':unit['anchor'],'directions':16,'full_circle':True,'actions':{'idle':meta}},indent=2),encoding='utf-8')
review=root/'build/feedback4-20261024';review.mkdir(exist_ok=True);gallery.save(review/'bomber-idle-separated.png')
report={'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'method':'Preserve source hull, isolate cool rear exhaust by color and heading; north rear collars copied from the existing two-engine south assembly. No new full-body art.','original_preserved':True,'headings':counts,'runtime_hull':'assets/bomber_propulsion_20261024/hulls.png','runtime_exhaust':'assets/bomber_propulsion_20261024/exhaust.png'}
(root/'docs/bomber-propulsion-fix-20261024.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('BOMBER separated baked flames for16 headings; north has two source-authored engine collars')
