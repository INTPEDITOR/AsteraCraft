"""Read-only component audit of every existing command-card icon."""
from pathlib import Path
from collections import deque
from PIL import Image, ImageDraw
import json,numpy as np
root=Path(__file__).resolve().parents[1]
out=root/'build/feedback4-20261024/icons';out.mkdir(parents=True,exist_ok=True)
records=[]
for race in range(3):
    jobs=[]
    for category,count in [('commands',32),('units',16),('buildings',16)]:
        for index in range(count):
            path=root/f'assets/ui/clean_icons_20261024/{category}_r{race}_{index:02}.png'
            if category=='commands' and index in [29,30]:path=root/f'assets/ui/page_icons_20261024/r{race}_{index}.png'
            jobs.append((f'{category}_r{race}_{index:02}',path))
    if race==1:
        jobs.extend((f'support_r1_{index:02}',root/f'assets/ui/clean_icons_20261024/support_r1_{index:02}.png') for index in range(3))
    data=json.loads((root/'data/game.json').read_text(encoding='utf-8'))
    jobs.extend((item['id'],root/f"assets/ui/passive_upgrades_20261024/{item['id']}.png") for item in data['research'] if item.get('race')==race and 'unit_kind' in item)
    gallery=Image.new('RGB',(8*160,((len(jobs)+7)//8)*168),(24,29,33));draw=ImageDraw.Draw(gallery)
    for number,(name,path) in enumerate(jobs):
        original=Image.open(path).convert('RGBA');image=original.resize((128,128),Image.Resampling.LANCZOS)
        alpha=np.asarray(image)[:,:,3]>16;seen=np.zeros(alpha.shape,bool);components=[]
        for y,x in zip(*np.where(alpha)):
            if seen[y,x]:continue
            q=deque([(y,x)]);seen[y,x]=True;points=[]
            while q:
                cy,cx=q.popleft();points.append((cy,cx))
                for dy in [-1,0,1]:
                    for dx in [-1,0,1]:
                        ny,nx=cy+dy,cx+dx
                        if 0<=ny<128 and 0<=nx<128 and alpha[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;q.append((ny,nx))
            if len(points)>=8:
                ys,xs=zip(*points);components.append({'area':len(points),'bbox':[int(min(xs)),int(min(ys)),int(max(xs)+1),int(max(ys)+1)]})
        components.sort(key=lambda c:c['area'],reverse=True)
        px=number%8*160+16;py=number//8*168+22
        gallery.paste(image,(px,py),image)
        draw.text((px-12,py-18),name,fill='white')
        for index,component in enumerate(components[1:],1):
            box=component['bbox'];draw.rectangle((px+box[0],py+box[1],px+box[2],py+box[3]),outline=(255,75,75));draw.text((px+box[0],py+box[1]),str(index),fill='yellow')
        records.append({'name':name,'file':str(path.relative_to(root)),'source_size':original.size,'components':components})
    gallery.save(out/f'components-r{race}.png')
(out/'components.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print(json.dumps({'icons':len(records),'multiple_components':sum(len(r['components'])>1 for r in records)}))
