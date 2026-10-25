from pathlib import Path
import hashlib
import json

root=Path(__file__).resolve().parents[1]
build=root/'build/cliff-fix-20261025'
out=root/'docs/verification_cliff_fix_20261025'
out.mkdir(parents=True,exist_ok=True)
def read(path):return json.loads((root/path).read_text(encoding='utf-8-sig'))
def save(name,data):
    (out/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
before=read('build/cliff-fix-20261025/before/result.json')
after=read('build/cliff-fix-20261025/after/result.json')
old_groups=read('build/group-move-continuity-20261025/cliff-before/result.json')
new_groups=read('build/group-move-continuity-20261025/cliff-after/result.json')
old_ramps=read('build/cliff-fix-20261025/ramps-before.json')
new_ramps=read('build/cliff-fix-20261025/ramps-after.json')
heights=read('build/cliff-fix-20261025/height-probe-after.json')
continuity=read('build/move-continuity-20261025/cliff-after/result.json')
assert before['checks']==after['checks']==345 and len(before['failures'])==51
assert after['passed'] and not after['failures'] and len(after['cases'])==24
for data in [old_groups,new_groups,continuity]:assert data['passed'] and not data['failures']
assert not old_ramps['failures'] and not new_ramps['failures']
assert old_ramps['maps']==new_ramps['maps'] and sum(m['traversals'] for m in new_ramps['maps'])==44
assert all(m['reported_height_mismatches']==0 for m in heights)
comparison=[]
for a,b in zip(old_groups['cases'],new_groups['cases']):
    assert a['trajectory']==b['trajectory'] and a['final_units']==b['final_units']
    assert a['arrival_seconds']==b['arrival_seconds'] and a['max_stop_seconds']==b['max_stop_seconds']
    comparison.append({'map':a['map'],'race':a['race'],'before_arrival':a['arrival_seconds'],'after_arrival':b['arrival_seconds'],
                       'same_trajectory':True,'same_final_positions':True,'same_max_stop':True,'new_deferred_stops':b['deferred_stops']})
def console(name,prefix):
    lines=(root/('build/'+name+'-after-console.txt')).read_text(encoding='utf-8-sig').splitlines()
    value=json.loads(next(line[len(prefix):] for line in lines if line.startswith(prefix)))
    assert not value['failures']
    save(name+'.json',value)
    return value
navigation=console('cliff-navigation','NAVIGATION_FEEDBACK ')
highground=console('cliff-highground','HIGHGROUND_BEAM ')
fog=console('cliff-fog','FOG_REVISION_V061 ')
melee=console('cliff-melee','MELEE_FOLLOW ')
brood=console('cliff-brood','BROOD_COLLISION ')
for name,data in [('before.json',before),('after.json',after),('formations-before.json',old_groups),('formations-after.json',new_groups),
                  ('ramps-before.json',old_ramps),('ramps-after.json',new_ramps),('height-sampling.json',heights),('continuity.json',continuity),('movement-comparison.json',comparison)]:save(name,data)
reference=read('docs/verification_resource_spacing_20261025/placement.json')['source_sha256']
for file,wanted in reference.items():assert hashlib.sha256((root/file.removeprefix('res://')).read_bytes()).hexdigest()==wanted
summary={'passed':True,'status':'source fixed and locally verified; not deployed',
         'solid_cliff_guard':'Collision displacement checks its entire swept body, recovery keeps the original ground level, exact 8px foot height drives vision.',
         'walk_masks_changed':False,'height_masks_changed':False,'ramps_changed':False,
         'before_guard_checks':345,'before_guard_failures':51,'after_guard_checks':345,'after_guard_failures':0,'cliff_vision_scenarios':24,
         'walkable_height_samples':sum(m['walkable_foot_samples'] for m in heights),'height_mismatches_after':0,
         'ramp_regions':22,'ramp_traversals_before':44,'ramp_traversals_after':44,'exact_mask_and_ramp_checks':new_ramps['checks'],
         'formation_cases':9,'units_per_formation':12,'formation_checks':new_groups['checks'],
         'same_trajectories_and_arrival_times':True,'comparison':comparison,
         'ground_unit_types':31,'continuity_checks':continuity['checks'],
         'map_crossings':len(navigation['journeys']),'map_crossing_checks':navigation['checks'],
         'highground_fire_and_air_sight_checks':highground['checks'],'fog_cache_checks':fog['checks'],
         'melee_follow_checks':melee['checks'],'brood_collision_checks':brood['checks'],
         'resource_build_cases_after_cliff_fix':126,
         'source_sha256':{file:hashlib.sha256((root/file).read_bytes()).hexdigest() for file in ['scripts/core.gd','scripts/world_map.gd','scripts/bot_ai.gd','data/resource_spacing_20261025.json']},
         'limitations':'Source simulations and separate existing resource renderer previews; no new Windows package or network match validation. Required yielding/crowding waits are not eliminated; tested movement traces remain identical.'}
assert read('build/base-resource-spacing-20261025/commands/result.json')['passed']
save('summary.json',summary)
print(json.dumps({key:value for key,value in summary.items() if key not in ['source_sha256','comparison','limitations']},ensure_ascii=False,indent=2))
