"""Normalize existing orange body landmarks; keep leaves/equipment/pixels."""
from pathlib import Path
import json,copy,math,statistics
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'data/art_sprite_display_corrections_20261024.json';catalog=json.loads(p.read_text(encoding='utf-8'))
u=json.loads((ROOT/'data/art_staged16_units.json').read_text(encoding='utf-8'))['units']['1:2']
c=catalog['units'].setdefault('1:2',{'scale_hint':u['scale_hint']});cache={};existing=copy.deepcopy(c.get('actions',{}))
def get(action,index):
 clip=u['actions'][action];frame=next((f for f in existing.get(action,{}).get('frame_overrides',[]) if f['index']==index),clip['frames'][index]);file=frame.get('file',clip['file'])
 if file not in cache:cache[file]=Image.open(ROOT/file.removeprefix('res://')).convert('RGBA')
 x,y,w,h=frame['region'];im=cache[file].crop((x,y,x+w,y+h));a=np.asarray(im).astype(float);r,g,b,alpha=[a[:,:,i] for i in range(4)];mask=(alpha>224)&(r>155)&(g>60)&(g<r*.85)&(b<110)
 old=frame.get('scale_hint',u['scale_hint'])*c.get('scale_hint',u['scale_hint'])/u['scale_hint'] if 'index' not in frame else frame.get('scale_hint',c.get('scale_hint',u['scale_hint']))
 return frame,int(mask.sum()),old,im
areas=[]
for index in range(16):
 f,area,hint,im=get('idle',index);areas.append(area/hint**2)
target=statistics.median(areas);rows=[];preview=Image.new('RGBA',(1280,340),(30,35,40,255));draw=ImageDraw.Draw(preview)
for action in ['idle','walk','attack']:
 clip=u['actions'][action];over=[]
 for index in range(len(clip['frames'])):
  f,area,old,im=get(action,index);assert area>50,(action,index,area)
  corrected=copy.deepcopy(f);corrected['file']=corrected.get('file',clip['file']);corrected['scale_hint']=math.sqrt(area/target);corrected['index']=index;over.append(corrected)
  rows.append({'action':action,'index':index,'body_pixels':area,'old_hint':old,'hint':corrected['scale_hint']})
  if action=='idle':
   factor=70/corrected['scale_hint'];im=im.resize((round(im.width*factor),round(im.height*factor)),Image.Resampling.LANCZOS);h=index%16;pos=(h%8*160+80-round(corrected['anchor'][0]*factor),h//8*170+145-round(corrected['anchor'][1]*factor));preview.alpha_composite(im,pos);draw.text((h%8*160+3,h//8*170+3),str(h),fill='white')
 c.setdefault('actions',{})[action]={'frame_overrides':over}
c['body_normalization']='All240 living frames normalized to shared median orange body area across16 headings; cyan equipment/green leaves/death pixels preserved.'
p.write_text(json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
(ROOT/'build/player_colors_20261024/spitter-sizes.json').write_text(json.dumps(rows,indent=2));preview.save(ROOT/'build/player_colors_20261024/spitter-size-after.png')
print('Spitter normalized:',len(rows),'frames')
