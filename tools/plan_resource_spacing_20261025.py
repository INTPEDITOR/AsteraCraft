"""Balance only Tera positions against unchanged source terrain and minerals."""
from pathlib import Path
import hashlib
import json
import math

root=Path(__file__).resolve().parents[1]
source=root/'data/original_maps.json'
catalog=json.loads(source.read_text(encoding='utf-8'))
reference=root/'docs/verification_resource_spacing_20261025/reference.json'
baseline=json.loads((reference if reference.is_file() else root/'build/base-resource-spacing-20261025/before/result.json').read_text(encoding='utf-8'))
start_anchors={(row['map'],row['slot']):row['anchor'] for row in baseline['starts']}
result={'schema':1,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'headquarters_size':[4,3],'mineral_gap':2,'tera_gap':2,
        'policy':'Keep current starting headquarters, source minerals/terrain, ALL expansion Tera and resource counts. Balance starting Tera only. Prefer As2/Tera2 headquarters anchors; where source terrain prevents both, keep resources fixed and move headquarters toward Tera. Edge-to-edge build-grid distance.',
        'maps':[]}

def body(pos,size):
    return (pos[0]-size[0]/2,pos[1]-size[1]/2,pos[0]+size[0]/2,pos[1]+size[1]/2)
def hq_box(anchor):
    return (anchor[0]-.5,anchor[1]-.5,anchor[0]+3.5,anchor[1]+2.5)
def gap(a,b):
    return max(a[0]-b[2],b[0]-a[2],a[1]-b[3],b[1]-a[3])
def overlaps(a,b,pad=0):
    return a[0]<b[2]+pad and a[2]>b[0]-pad and a[1]<b[3]+pad and a[3]>b[1]-pad
def surface(m,anchor,size,height):
    x,y=anchor;w,h=size
    return x>=1 and y>=1 and x+w<=127 and y+h<=127 and all(
        m['buildable_map'][yy*128+xx] and m['height_map'][yy*128+xx]==height
        for yy in range(y,y+h) for xx in range(x,x+w))
def mineral_score(box,ore):
    return sum((n['pos'][0]-min(max(n['pos'][0],box[0]),box[2]))**2+
               (n['pos'][1]-min(max(n['pos'][1],box[1]),box[3]))**2 for n in ore)/len(ore)

for map_id,m in enumerate(catalog['maps']):
    nodes=json.loads(json.dumps(m['resources']))
    originals={n['id']:n['pos'][:] for n in nodes}
    sites=[]
    for base_id,base in enumerate(m['bases']):
        local=[n for n in nodes if n['id'] in base['resources']]
        ore=[n for n in local if n['type']=='as' and n['amount']>=500]
        if len(ore)<3:continue
        vents=[n for n in local if n['type']=='tera']
        assert len(vents)<=1,(map_id,base_id,'multiple Tera in one base')
        vent=vents[0] if vents else None
        sx,sy=base['pos'];level=m['height_map'][int(sy)*128+int(sx)]
        anchors=[list(map(int,start_anchors[(map_id,base['slot'])]))] if base['main'] else [
            [x,y] for y in range(max(1,int(sy)-18),min(125,int(sy)+18))
            for x in range(max(1,int(sx)-18),min(124,int(sx)+18))]
        choices=[]
        for anchor in anchors:
            if not surface(m,anchor,[4,3],level):continue
            box=hq_box(anchor)
            if any(overlaps(box,body(n['pos'],n['collision_size']),2)
                   for n in nodes if n is not vent and (n['type']!='as' or n['amount']>0)):continue
            ore_gap=min(gap(box,body(n['pos'],[2,1])) for n in ore)
            if ore_gap<2:continue
            choices.append(((ore_gap-2)*1000000+mineral_score(box,ore),anchor,box))
        choices.sort()
        assert choices,(map_id,base_id,'no mineral-distance headquarters on source terrain')
        best=None
        offsets=sorted((dx*dx+dy*dy,abs(dx)+abs(dy),dx,dy) for dx in range(-12,13) for dy in range(-12,13)) if vent and base['main'] else [(0,0,0,0)]
        for distance,_,dx,dy in offsets:
            if best and distance>best[0][0]:break
            pos=[originals[vent['id']][0]+dx,originals[vent['id']][1]+dy] if vent else None
            if vent:
                gas_anchor=[round(pos[0]-1.5),round(pos[1]-.5)]
                old_height=m['height_map'][int(originals[vent['id']][1])*128+int(originals[vent['id']][0])]
                if not surface(m,gas_anchor,[4,2],old_height):continue
                gas_box=body(pos,[4,2])
                if any(overlaps(gas_box,body(n['pos'],n['collision_size'])) for n in nodes if n is not vent and (n['type']!='as' or n['amount']>0)):continue
            for score,anchor,box in choices:
                gas_gap=gap(box,gas_box) if vent else 2
                if gas_gap<2 or (base['main'] and gas_gap!=2):continue
                key=(distance,(gas_gap-2)*1000000000+score,(anchor[0]+1.5-sx)**2+(anchor[1]+1-sy)**2)
                if best is None or key<best[0]:best=(key,anchor,pos)
        assert best,(map_id,base_id,'no balanced Tera within twelve source tiles')
        _,anchor,pos=best
        if vent:vent['pos']=pos
        sites.append({'base':base_id,'kind':base['kind'],'access':base['access'],'slot':base['slot'],
                      'headquarters_anchor':anchor,'mineral_gap':min(gap(hq_box(anchor),body(n['pos'],[2,1])) for n in ore),'tera_gap':gap(hq_box(anchor),body(pos,[4,2])) if vent else None,
                      'tera_id':vent['id'] if vent else None})
    moves=[{'id':n['id'],'source_pos':n['source_pos'],'original_pos':originals[n['id']],
            'pos':n['pos'],'delta':[n['pos'][0]-originals[n['id']][0],n['pos'][1]-originals[n['id']][1]],
            'base':n['base'],'slot':n['slot']} for n in nodes if n['pos']!=originals[n['id']]]
    assert all(next(n for n in nodes if n['id']==move['id'])['type']=='tera' for move in moves)
    assert all(move['slot']>=0 for move in moves),'Expansion Tera must remain at source positions'
    result['maps'].append({'id':map_id,'name':m['name'],'source':m['source'],'source_sha256':m['source_sha256'],
                           'starting_headquarters_anchors':[start_anchors[(map_id,slot)] for slot in range(4)],
                           'tera_overrides':moves,'base_sites':sites})
    print(json.dumps({'map':map_id,'bases':len(sites),'tera_moves':moves},ensure_ascii=False))
(root/'data/resource_spacing_20261025.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('RESOURCE_SPACING_PLAN',sum(len(m['tera_overrides']) for m in result['maps']),'Tera moves')
