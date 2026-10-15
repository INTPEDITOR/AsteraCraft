const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
let s=fs.readFileSync(path.join(root,'tests/feedback_v051_test.gd'),'utf8');
s=s.replace('var building=c.entity(int(worker.target))\n\t\tif building.is_empty():continue\n\t\tc._tick_building(building,.1)\n\t\tcheck(worker.hp>0 and building.progress==0,"worker survives before reaching site %d"%race)\n\t\tworker.pos=ACData.packed(c.building_approach(building,c.center(worker)))',`check(worker.order=="build_move" and c.entity(int(worker.target)).is_empty(),"no foundation before arrival %d"%race)
\t\tcheck(c.players[0].as==10000,"no payment before arrival %d"%race)
\t\tcheck(c.map.walkable(Vector2i(site)),"pending footprint remains walkable %d"%race)
\t\tworker.pos=ACData.packed(c.building_approach(worker.build_plan,c.center(worker),worker))
\t\tc._tick_unit_behavior(worker,.05)
\t\tvar building=c.entity(int(worker.target))
\t\tcheck(not building.is_empty(),"foundation created at arrival %d"%race)
\t\tif building.is_empty():continue
\t\tcheck(c.players[0].as==10000-ACData.building(race,2).as,"payment on arrival %d"%race)`);
s=s.replace('FEEDBACK_V051','FEEDBACK_V052');
s=s.replace('\tprint("FEEDBACK_V052',`\tfor race in range(3):
\t\tvar canceled=prepared(race)
\t\tvar w=canceled.units.filter(func(u):return u.owner==0 and u.kind==0)[0]
\t\tvar home=canceled.entity(int(canceled.players[0].home))
\t\tvar site=(canceled.center(home)+Vector2(6,0)).floor()
\t\tvar before_count=canceled.buildings.size()
\t\tcheck(canceled.command(0,{"type":"build","kind":2,"pos":ACData.packed(site),"ids":[w.id]})=="","pending order accepted")
\t\tcanceled.command(0,{"type":"stop","ids":[w.id]})
\t\tcanceled.step(.05)
\t\tcheck(canceled.buildings.size()==before_count and canceled.players[0].as==10000 and not w.has("build_plan"),"stop cancels unpaid pending order")
\t\tfor kind in range(13):
\t\t\tvar d=ACData.unit(race,kind)
\t\t\tif not d.air and d.damage>0 and d.range>1.5:check(d.targets=="ga","ranged ground unit targets both layers")
\tprint("FEEDBACK_V052`);
fs.writeFileSync(path.join(root,'tests/feedback_v052_test.gd'),s);
