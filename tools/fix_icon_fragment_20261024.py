"""Remove only the reviewed foreign fragment; preserve every other icon."""
from pathlib import Path
from collections import deque
from PIL import Image
import numpy as np,json,hashlib
root=Path(__file__).resolve().parents[1]
source=root/'assets/ui/clean_icons_20261024/commands_r0_16.png'
image=Image.open(source).convert('RGBA');pixels=np.asarray(image).copy();mask=pixels[:,:,3]>8
seen=np.zeros(mask.shape,bool);parts=[]
for y,x in zip(*np.where(mask)):
    if seen[y,x]:continue
    q=deque([(y,x)]);seen[y,x]=True;part=[]
    while q:
        cy,cx=q.popleft();part.append((cy,cx))
        for dy in [-1,0,1]:
            for dx in [-1,0,1]:
                ny,nx=cy+dy,cx+dx
                if 0<=ny<128 and 0<=nx<128 and mask[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;q.append((ny,nx))
    parts.append(part)
parts.sort(key=len,reverse=True);keep=np.zeros(mask.shape,bool)
for y,x in parts[0]:keep[max(0,y-1):min(128,y+2),max(0,x-1):min(128,x+2)]=True
removed=int(np.count_nonzero(pixels[~keep,3]));pixels[~keep]=0
assert len(parts)>1 and removed>0
out=root/'assets/ui/icon_fragment_fixes_20261024';out.mkdir(exist_ok=True)
target=out/source.name;Image.fromarray(pixels).save(target)
report={'reviewed_icons':205,'multi_component_icons_inspected':17,'fixed_icons':[{'race':0,'kind':'commands','index':16,'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'output':str(target.relative_to(root)),'removed_foreign_pixels':removed,'kept_subject_pixels_unchanged':True}],'retained_detached_parts':'Other inspected components are intentional aim brackets, arrows, petals, stars or building spires; retained. Original atlas and original cleaned cells preserved.'}
(root/'docs/icon-fragment-review-20261024.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report['fixed_icons'][0]))
