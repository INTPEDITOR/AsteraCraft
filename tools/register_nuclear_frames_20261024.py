"""Register unchanged generated VFX cells by the connected central stem.

Pixel data are copied unchanged. Only sampling offsets in metadata are added.
"""
from pathlib import Path
from collections import deque
import json, shutil, hashlib, sys
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1])
destination=ROOT/'assets/effects/nuclear_stable_20261024.png'
destination.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(source,destination)
image=np.array(Image.open(source).convert('RGBA'))
assert image.shape==(1024,1536,4)
offsets=[];anchors=[]
for frame in range(24):
    alpha=image[frame//6*256:(frame//6+1)*256,frame%6*256:(frame%6+1)*256,3]
    mask=alpha>max(30,float(alpha.max())*.65)
    seen=np.zeros_like(mask,dtype=bool);components=[]
    for yy,xx in zip(*np.where(mask)):
        if seen[yy,xx]:continue
        queue=deque([(int(xx),int(yy))]);seen[yy,xx]=True;points=[]
        while queue:
            x,y=queue.popleft();points.append((x,y))
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                nx,ny=x+dx,y+dy
                if 0<=nx<256 and 0<=ny<248 and mask[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;queue.append((nx,ny))
        if len(points)>=8:components.append(points)
    assert components
    connected=min(components,key=lambda ps:min((x-128)**2+(y-190)**2 for x,y in ps))
    bottom=max(y for x,y in connected)
    # Register the whole cloud's horizontal axis, rather than the last
    # flickering ember at the foot, which would introduce lateral wobble.
    foot=(min(x for x,y in connected)+max(x for x,y in connected))*.5
    anchors.append([foot,bottom]);offsets.append([(foot-128)/256,(bottom-225.28)/256])
effect={'status':'accepted','file':'res://assets/effects/nuclear_stable_20261024.png','columns':6,'rows':4,'count':24,'pivot':[.5,.88],'scale_hint':224,'phase_frames':[0,5,10,17,23],'frame_offsets':offsets,'edge_feather':.035,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'registration':'Connected cloud horizontal silhouette axis and vertical stem foot -> fixed world origin; unchanged source pixels and common scale across all frames.'}
(ROOT/'data/art_nuclear_stable_20261024.json').write_text(json.dumps({'effects':{'nuclear':effect}},indent=2),encoding='utf8')
print(json.dumps({'frames':24,'source_feet':anchors,'pixel_sha256_preserved':hashlib.sha256(source.read_bytes()).digest()==hashlib.sha256(destination.read_bytes()).digest()},indent=2))
