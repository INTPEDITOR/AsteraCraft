"""Measure the worker chassis pigment, excluding long silver drills/padding."""
from pathlib import Path
import json,copy,math,statistics
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
u=json.loads((ROOT/'data/art_staged16_units.json').read_text())['units']['0:0']
p=ROOT/'data/art_sprite_display_corrections_20261024.json';catalog=json.loads(p.read_text());change=catalog['units'].setdefault('0:0',{'scale_hint':u['scale_hint']});cache={}
def area(clip,f):
 file=f.get('file',clip['file'])
 if file not in cache:cache[file]=Image.open(ROOT/file.removeprefix('res://')).convert('RGBA')
 x,y,w,h=f['region'];im=cache[file].crop((x,y,x+w,y+h));a=np.asarray(im).astype(float);r,g,b,alpha=[a[:,:,i] for i in range(4)]
 mask=(alpha>224)&(r>60)&(r>g*1.04)&(g>b*1.35)
 return int(mask.sum()),im
idle=u['actions']['idle'];target=statistics.median(area(idle,f)[0]/u['scale_hint']**2 for f in idle['frames']);rows=[]
contact=Image.new('RGBA',(8*160,2*160),(30,35,40,255));draw=ImageDraw.Draw(contact)
for action in ['idle','walk','attack','work']:
 clip=u['actions'][action];overrides=[]
 for index,frame in enumerate(clip['frames']):
  count,im=area(clip,frame);assert count>100
  f=copy.deepcopy(frame);f['file']=f.get('file',clip['file']);f['scale_hint']=math.sqrt(count/target);f['index']=index;overrides.append(f)
  rows.append({'action':action,'index':index,'chassis_pixels':count,'hint_before':frame.get('scale_hint',u['scale_hint']),'hint_after':f['scale_hint']})
  if action=='idle':
   factor=60/f['scale_hint'];im=im.resize((round(im.width*factor),round(im.height*factor)),Image.Resampling.LANCZOS);h=index%16;pos=(h%8*160+80-im.width//2,h//8*160+125-round(frame['anchor'][1]*factor));contact.alpha_composite(im,pos);draw.text((h%8*160+4,h//8*160+3),str(h),fill='white')
 change.setdefault('actions',{})[action]={'frame_overrides':overrides}
change['body_normalization']='Same worker chassis pigment area across all16 headings and352 living frames; silver drill extensions, padding, death excluded. Original pixels and gameplay size untouched.'
p.write_text(json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
(ROOT/'build/player_colors_20261024/worker-sizes.json').write_text(json.dumps(rows,indent=2))
contact.save(ROOT/'build/player_colors_20261024/worker-size-after.png')
print('Worker calibrated:',len(rows),'frames; hints',min(r['hint_after'] for r in rows),max(r['hint_after'] for r in rows))
