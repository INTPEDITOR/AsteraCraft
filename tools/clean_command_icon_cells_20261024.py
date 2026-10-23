"""Extract existing icon cells with transparent padding; never repaint portraits."""
from pathlib import Path
from collections import deque
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/ui/clean_icons_20261024';OUT.mkdir(parents=True,exist_ok=True)
records=[];preview=Image.new('RGBA',(16*80,9*80),(26,31,34,255));draw=ImageDraw.Draw(preview)
for race in range(3):
 for kind,columns in [('units',4),('commands',8),('buildings',4)]+([('support',8)] if race==1 else []):
  path=ROOT/'assets/sap_support_v060.png' if kind=='support' else ROOT/f'assets/icons_{kind}_{race}_v060.png'
  source=Image.open(path).convert('RGBA');w,h=source.width//columns,source.height//4
  for index in range(3 if kind=='support' else columns*4):
   x,y=index%columns*w,index//columns*h;cell=source.crop((x,y,x+w,y+h));a=np.asarray(cell).copy();mask=a[:,:,3]>8;seen=np.zeros(mask.shape,bool);components=[]
   for yy,xx in zip(*np.where(mask)):
    if seen[yy,xx]:continue
    q=deque([(yy,xx)]);seen[yy,xx]=True;points=[]
    while q:
     cy,cx=q.popleft();points.append((cy,cx))
     for dy in [-1,0,1]:
      for dx in [-1,0,1]:
       ny,nx=cy+dy,cx+dx
       if 0<=ny<h and 0<=nx<w and mask[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;q.append((ny,nx))
    components.append(points)
   components.sort(key=len,reverse=True)
   if not components:continue
   keep=np.zeros(mask.shape,bool);largest=len(components[0]);removed=0
   # A detached rotor/wing can be substantial; tiny isolated border dots cannot.
   for component in components:
    ys,xs=zip(*component)
    edge_strip=(min(xs)<=12 and max(xs)<=20) or (max(xs)>=w-13 and min(xs)>=w-21) or (min(ys)<=12 and max(ys)<=20) or (max(ys)>=h-13 and min(ys)>=h-21)
    if len(component)>=max(16,largest*.012) and (component is components[0] or not edge_strip):
     keep[ys,xs]=True
    else:removed+=len(component)
   a[~keep]=0;cut=Image.fromarray(a);box=cut.getbbox()
   if not box:continue
   cut=cut.crop(box);cut.thumbnail((116,116),Image.Resampling.LANCZOS)
   final=Image.new('RGBA',(128,128));final.alpha_composite(cut,((128-cut.width)//2,(128-cut.height)//2))
   file=f'{kind}_r{race}_{index:02}.png';final.save(OUT/file)
   records.append({'race':race,'kind':kind,'index':index,'removed_isolated_pixels':removed,'source_bounds':box,'file':file})
   if kind in ['units','commands']:
    position=(index%16*80,(race*3+(0 if kind=='units' else 1+index//16))*80)
    small=final.resize((66,66),Image.Resampling.LANCZOS);preview.alpha_composite(small,(position[0]+7,position[1]+9));draw.text(position,f'{race}:{kind[0]}{index}',fill='white')
(ROOT/'build/player_colors_20261024/icon-crops.json').write_text(json.dumps(records,indent=2))
preview.save(ROOT/'build/player_colors_20261024/icon-crops.png')
print('Clean original icon cells:',len(records),'isolated pixels removed:',sum(r['removed_isolated_pixels'] for r in records))
