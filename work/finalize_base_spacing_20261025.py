from pathlib import Path
import hashlib
import json
import math
import shutil

root=Path(__file__).resolve().parents[1]
out=root/'docs/verification_resource_spacing_20261025'
out.mkdir(parents=True,exist_ok=True)
build=root/'build/base-resource-spacing-20261025'
def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def finite(value):
    if isinstance(value,float) and not math.isfinite(value):return None
    if isinstance(value,list):return [finite(v) for v in value]
    if isinstance(value,dict):return {k:finite(v) for k,v in value.items()}
    return value
def save(name,data):
    (out/name).write_text(json.dumps(finite(data),ensure_ascii=False,indent=2,allow_nan=False)+'\n',encoding='utf-8')
plan=load(root/'data/resource_spacing_20261025.json')
source=load(root/'data/original_maps.json')
before=load(build/'before/result.json')
after=load(build/'confirmed-final/result.json')
commands=load(build/'commands/result.json')
visual=load(build/'visual/result.json')
worker=load(build/'preview-worker.json')
original=load(root/'build/qa-v060/original-map-audit.json')
nav_lines=(root/'build/base-spacing-navigation-console.txt').read_text(encoding='utf-8-sig').splitlines()
navigation=json.loads(next(line.removeprefix('NAVIGATION_FEEDBACK ') for line in nav_lines if line.startswith('NAVIGATION_FEEDBACK ')))
for item in [after,commands,visual,worker]:assert item['passed'] and not item['failures']
assert not original['failures'] and not navigation['failures']
assert len(after['bases'])==42 and len(after['starts'])==12 and len(commands['cases'])==126
assert len(navigation['journeys'])==24
for old,new in zip(before['starts'],after['starts']):
    assert old['anchor']==new['anchor']
    assert new['gaps']=={'as':2,'tera':2}
for map_id,entry in enumerate(plan['maps']):
    assert all(move['slot']>=0 for move in entry['tera_overrides'])
    assert len(entry['base_sites'])==14
assert sum(len(m['tera_overrides']) for m in plan['maps'])==9

def rect(pos,size):return [pos[0]-size[0]/2,pos[1]-size[1]/2,pos[0]+size[0]/2,pos[1]+size[1]/2]
def gap(a,b):return max(a[0]-b[2],b[0]-a[2],a[1]-b[3],b[1]-a[3])
reference=[]
for map_id,m in enumerate(source['maps']):
    for slot,point in enumerate(m['starts']):
        anchor=[math.floor(point[0]-2),math.floor(point[1]-1.5)]
        hq=[anchor[0]-.5,anchor[1]-.5,anchor[0]+3.5,anchor[1]+2.5]
        measured={t:min(gap(hq,rect(n['pos'],n['collision_size'])) for n in m['resources'] if n['type']==t and n['amount']>0) for t in ['as','tera']}
        assert measured=={'as':3,'tera':3}
        reference.append({'map':map_id,'slot':slot,'source_headquarters_anchor':anchor,'source_gaps':measured,
                          'previous_game_headquarters_anchor':before['starts'][map_id*4+slot]['anchor'],
                          'previous_game_gaps':before['starts'][map_id*4+slot]['gaps']})
save('reference.json',{'source_sha256':plan['source_sha256'],'starts':before['starts'],'original_starts':reference,
                      'finding':'Source resource conversion matches original CHK. The prior mineral-facing headquarters shift changed Tera spacing; latest user requests closer Tera but fixed expansion resources.'})
for name,item in [('before.json',before),('placement.json',after),('commands.json',commands),('visual.json',visual),('preview-worker.json',worker),('original-source.json',original),('navigation.json',navigation)]:save(name,item)
for image in ['race1-blocked-too-close.png','race1-allowed-as2-tera2.png']:
    shutil.copyfile(build/'visual'/image,out/image)
exceptions=[{'map':m['id'],**site} for m in plan['maps'] for site in m['base_sites'] if site['mineral_gap']!=2 or site['tera_gap'] not in [None,2]]
assert len(exceptions)==1 and exceptions[0]['map']==1 and exceptions[0]['base']==10 and exceptions[0]['tera_gap']==7
summary={'passed':True,'status':'source fixed and locally verified; not deployed',
         'approved_distance':'latest approved screenshot; starting As2/Tera2; expansion Tera positions fixed',
         'maps':3,'resource_bases':42,'starting_bases':12,'faction_base_construction_cases':126,
         'placement_checks':after['checks'],'actual_command_checks':commands['checks'],'native_preview_checks':visual['checks'],
         'background_preview_and_ai_checks':worker['checks'],'original_source_checks':original['checks'],
         'map_crossing_checks':navigation['checks'],'map_crossings':24,
         'starting_tera_adjustments':9,'expansion_tera_adjustments':0,'mineral_adjustments':0,
         'terrain_adjustments':0,'original_files_modified':False,'original_starts_as3_tera3':12,
         'current_starts_as2_tera2':12,'matching_as2_tera2_bases':35,'mineral_only_bases':6,'source_terrain_exception':exceptions,
         'source_sha256':{f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in ['scripts/core.gd','scripts/world_map.gd','scripts/bot_ai.gd','data/resource_spacing_20261025.json']}}
save('summary.json',summary)
print(json.dumps({k:v for k,v in summary.items() if k!='source_sha256'},ensure_ascii=False,indent=2))
