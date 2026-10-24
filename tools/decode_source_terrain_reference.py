"""Read-only decoding for local source-map comparison; never ships source pixels."""
import json, struct, hashlib
from pathlib import Path
from collections import Counter
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/rock-terrain-20261024/source-reference'
OUT.mkdir(parents=True,exist_ok=True)
data=json.loads((ROOT/'data/original_maps.json').read_text(encoding='utf-8'))
meta=ROOT/'build/terrain-metadata'
cv=(meta/'jungle.cv5').read_bytes()
vx=np.frombuffer((meta/'jungle.vx4ex').read_bytes(),dtype='<u4').reshape(-1,16)
vr=np.frombuffer((meta/'jungle.vr4').read_bytes(),dtype=np.uint8).reshape(-1,8,8)
palette=np.frombuffer((meta/'jungle.wpe').read_bytes(),dtype=np.uint8).reshape(-1,4)[:,:3]
cache={}
def tile_pixels(tile):
    if tile in cache:return cache[tile]
    group=tile>>4;mega=struct.unpack_from('<H',cv,group*52+20+(tile&15)*2)[0]
    dest=np.empty((32,32),dtype=np.uint8)
    for j,ref in enumerate(vx[mega]):
        pixels=vr[int(ref)>>1]
        if int(ref)&1:pixels=pixels[:,::-1]
        dest[(j//4)*8:(j//4+1)*8,(j%4)*8:(j%4+1)*8]=pixels
    cache[tile]=dest
    return dest
water=Counter()
for m in data['maps']:
    atlas=np.empty((4096,4096),dtype=np.uint8)
    for i,tile in enumerate(m['source_tiles']):
        pixels=tile_pixels(tile);x=i%128;y=i//128
        atlas[y*32:(y+1)*32,x*32:(x+1)*32]=pixels
        if struct.unpack_from('<H',cv,(tile>>4)*52)[0]==5:water.update(pixels.ravel().tolist())
    image=Image.fromarray(palette[atlas]);name=str(data['maps'].index(m))
    image.save(OUT/f'original-map-{name}.png')
    image.resize((1024,1024),Image.Resampling.LANCZOS).save(OUT/f'original-overview-{name}.png')
print('water_palette',[(int(k),tuple(int(v) for v in palette[k]),n) for k,n in water.most_common()])
print('source references saved',OUT)
# Only semantic bitmasks are consumed by the game. Source image pixels remain
# in ignored build/reference files and are never copied into runtime artwork.
water_indices=np.array(sorted(water),dtype=np.uint8)
semantics=[]
vf=(meta/'jungle.vf4').read_bytes()
for m in data['maps']:
    masks=[];tile_types=[];count=0;edge_count=0
    for i,tile in enumerate(m['source_tiles']):
        pixels=tile_pixels(tile);mask=0;o=(tile>>4)*52
        typ=struct.unpack_from('<H',cv,o)[0];mega=struct.unpack_from('<H',cv,o+20+(tile&15)*2)[0]
        for j in range(16):
            flags=struct.unpack_from('<H',vf,mega*32+j*2)[0]
            piece=pixels[(j//4)*8:(j//4+1)*8,(j%4)*8:(j%4+1)*8]
            if not flags&1 and (typ==5 or np.isin(piece,water_indices).mean()>=.5):mask|=1<<j;count+=1
        if mask and m['terrain'][i]!=2:edge_count+=1
        masks.append(mask);tile_types.append(typ)
    semantics.append({'water_masks':masks,'cv5_types':tile_types,'water_minitiles':count,'recovered_water_edge_tiles':edge_count})
    print('semantic map',len(semantics)-1,'water minitiles',count,'recovered edge tiles',edge_count)
record={'schema':1,'source_sha256':hashlib.sha256((ROOT/'data/original_maps.json').read_bytes()).hexdigest(),
        'provenance':{'cv5_sha256':hashlib.sha256(cv).hexdigest(),'vx4ex_sha256':hashlib.sha256((meta/'jungle.vx4ex').read_bytes()).hexdigest(),'vr4_sha256':hashlib.sha256((meta/'jungle.vr4').read_bytes()).hexdigest(),'wpe_sha256':hashlib.sha256((meta/'jungle.wpe').read_bytes()).hexdigest()},
        'policy':'Visual-only water at original 8px nonwalkable minitiles: >=32 of 64 pixels use the exact palette of CV5 Water core tiles. Walkable bridges excluded. Original collision, heights, resources and map source files unchanged.',
        'reference_documentation':'https://docs.scmjs.dev/game-data/how-terrain-is-drawn/','maps':semantics}
(ROOT/'data/source_terrain_semantics_20261024.json').write_text(json.dumps(record,separators=(',',':')),encoding='utf8')
