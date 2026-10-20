const fs=require('fs');
function edit(file,fn){const raw=fs.readFileSync(file,'utf8');fs.writeFileSync(file,fn(raw.replace(/\r\n/g,'\n')),'utf8')}
function sub(s,a,b){if(!s.includes(a))throw Error('Missing '+a.slice(0,100));return s.replace(a,b)}
edit('scripts/core.gd',s=>{
 s=sub(s,'const RESEARCH=preload("res://scripts/research.gd")','const RESEARCH=preload("res://scripts/research.gd")\nconst ABILITIES=preload("res://scripts/abilities.gd")\nconst NEW_UNITS=preload("res://scripts/new_units.gd")');
 s=sub(s,'var effects: Array = []','var effects: Array = []\nvar ability_events: Array=[]\nvar ability_zones: Array=[]\nvar reveals: Array=[]');
 s=sub(s,'const ENERGY_REGEN: float = .3','const ENERGY_REGEN: float = .65');
 s=sub(s,'u.energy=minf(100,u.max_energy)','u.energy=minf(25,u.max_energy)');
 s=sub(s,'\n\tif race==0 and kind==7:u.energy=50.0','');
 s=sub(s,'if type=="research":return RESEARCH.enqueue','if type=="skill":return ABILITIES.command(self,owner,cmd)\n\tif type=="produce_nuke":return ABILITIES.produce_nuke(self,owner,entity(int(cmd.get("id",-1))))\n\tif type=="cancel_nuke":return ABILITIES.cancel_nuke(self,owner,entity(int(cmd.get("id",-1))))\n\tif type in ["produce_drone","cancel_drone"]:return NEW_UNITS.command(self,owner,cmd)\n\tif type=="research":return RESEARCH.enqueue');
 s=sub(s,'if type=="morph":return CITRUS_BROOD.train(self,owner,entity(int(cmd.get("id",-1))),int(cmd.get("kind",-1)),cmd.get("ids",[]))',`if type=="morph":
		var accepted=false;var error="선택한 배양체를 확인하세요"
		for id in ids if not ids.is_empty() else [cmd.get("id",-1)]:
			var pod=entity(int(id))
			if not CITRUS_BROOD.is_pod(pod) or pod.get("brood_state","")!="idle":continue
			var result=CITRUS_BROOD.train(self,owner,pod,int(cmd.get("kind",-1)))
			if result=="":accepted=true
			else:error=result;break
		return "" if accepted else error`);
 s=sub(s,'or kind<0 or kind>=13:\n\t\t\treturn "생산 건물을 선택하세요"','or kind<0 or kind>=ACData.unit_count(int(b.race)):\n\t\t\treturn "생산 건물을 선택하세요"');
 const oldstart=s.indexOf('\n\tif type=="research":\n');const oldend=s.indexOf('\n\tif type=="rally":',oldstart);
 if(oldstart<0||oldend<0)throw Error('old research');s=s.slice(0,oldstart)+s.slice(oldend);
 // Legacy command compatibility must obey the same research gates.
 s=sub(s,'if ability_role=="parasite":\n\t\t\t\treturn _mind_control(u,int(cmd.get("target",-1)))',`if ability_role in ["parasite","mage","priest"]:
				var skill="mind_control" if ability_role=="parasite" else "judgment" if ability_role=="mage" else "barrier"
				return ABILITIES.use(self,u,skill,ACData.point(cmd.get("pos",u.pos)),int(cmd.get("target",u.id if ability_role=="priest" else -1)))`);
 s=sub(s,'if u.anchored:\n\t\treturn false','if u.anchored or float(u.get("rooted_until",0))>time:\n\t\treturn false');
 s=sub(s,'var speed=float(d.speed)*(.45 if time<u.slow_until else 1.0)','var speed=float(d.speed)*(.45 if time<u.slow_until else 1.0)\n\tif float(u.get("stim_until",0))>time:speed*=1.25\n\tif float(u.get("march_until",0))>time:speed*=1.25');
 s=sub(s,'\t_rebuild_collision_index()\n\tperf.building_us','\t_rebuild_collision_index()\n\tABILITIES.update(self,dt)\n\tperf.building_us');
 s=sub(s,'\tCITRUS_BROOD.cleanup_dead(self)','\tABILITIES.update(self,0)\n\tNEW_UNITS.cleanup(self)\n\tCITRUS_BROOD.cleanup_dead(self)');
 s=sub(s,'\tRESEARCH.tick(self,b,dt*rate)','\tRESEARCH.tick(self,b,dt*rate)\n\tABILITIES.tick_building(self,b,dt*rate)');
 s=sub(s,'_find_target(b,7 if aa else 6,"a" if aa else "g")','_find_target(b,9 if aa else 8,"a" if aa else "g")');
 s=sub(s,'\t_regenerate(u,d,dt)\n\tif int(u.kind)==0','\t_regenerate(u,d,dt)\n\tif not u.get("channel",{}).is_empty() or float(u.get("self_repair_until",0))>time:return\n\tif NEW_UNITS.tick(self,u,dt):return\n\tif int(u.kind)==0');
 s=sub(s,'if not u.fleeing and d.role in ["medic","healer_detector","priest"]:','if not u.fleeing and float(u.get("silenced_until",0))<=time and d.role in ["medic","healer_detector","priest"]:');
 s=sub(s,'carrier.cargo.append(u.id)','carrier.cargo.append(u.id)\n\t\t\t\t_effect("board",carrier,center(carrier),.35,{"passenger":u.id})');
 s=sub(s,'\t\t\t\t\t_damage(u,target,float(d.damage)+players[u.owner].attack*2)',`\t\t\t\t\tvar target_air=not target.has("progress") and ACData.unit(int(target.race),int(target.kind)).air
					var base=float(d.get("damage_air",d.damage)) if target_air else float(d.damage)
					if d.role=="chaser":
						if int(u.get("focus_target",-1))!=int(target.id):u.focus_target=target.id;u.focus_started=time
						base*=1+minf(2,maxf(0,time-float(u.get("focus_started",time)))*.35)
					_damage(u,target,base+players[u.owner].attack*2)
					if float(d.get("splash_radius",0))>0:
						_area_damage(u,center(target),float(d.splash_radius),base*float(d.get("splash_factor",.5)),int(target.id),str(d.targets))
					if float(u.get("scatter_until",0))>time:_area_damage(u,center(target),2.2,base*.6,int(target.id),"g")
					if float(u.get("pierce_until",0))>time:NEW_UNITS.pierce(self,u,target,base*.65)`);
 s=sub(s,'u.cooldown=float(d.period)','u.cooldown=float(d.period)*(1.4 if float(u.get("attack_slow_until",0))>time else 1.0)\n\t\t\t\tif float(u.get("stim_until",0))>time:u.cooldown*=.75');
 s=sub(s,'\telif u.order in ["move","attack_move"]:\n','\telif u.order in ["move","attack_move"]:\n\t\tu.focus_target=-1\n');
 s=sub(s,'return styles[int(attacker.get("race",0))][clampi(int(attacker.get("kind",0)),0,12)]','return str(ACData.unit(int(attacker.race),int(attacker.kind)).get("weapon",styles[int(attacker.race)][clampi(int(attacker.kind),0,12)]))');
 s=sub(s,'show_projectile: bool=true) -> void:\n\tif target.hp','show_projectile: bool=true,damage_kind: String="attack") -> void:\n\tif target.hp');
 s=sub(s,'\tvar left=amount\n',`\tvar left=amount
	if damage_kind=="attack":
		if not attacker.has("progress"):
			var ad=ACData.unit(int(attacker.race),int(attacker.kind))
			left+=float(ad.get("bonus_"+str(d.get("armor_class","heavy" if target.has("progress") else "light")),0))
		if float(target.get("smoke_until",0))>time:left*=.65
		if float(target.get("carapace_until",0))>time:left*=.55
	if float(target.get("ward_until",0))>time:
		var ward_absorb=minf(left,float(target.get("ward",0)))
		target.ward=float(target.get("ward",0))-ward_absorb;left-=ward_absorb
	if left<=0:return
`);
 s=sub(s,'_effect("explosion",target,center(target),.6,{"attacker":int(attacker.get("id",-1)),"fatal":true})',`var death_style="juice" if int(target.race)==1 else "blue_flame" if int(target.race)==2 else "explosion" if target.has("progress") or d.get("material","")=="mechanical" else "blood"
		_effect("death",target,center(target),8.0 if death_style in ["juice","blood"] else .85,{"attacker":int(attacker.get("id",-1)),"fatal":true,"death_style":death_style})`);
 s=sub(s,'except_id: int = -1) -> void:\n\tfor t in _query_entities','except_id: int = -1,targets: String="ga") -> void:\n\tfor t in _query_entities');
 s=sub(s,'\t\t\t_damage(u,t,damage,false)\n','\t\t\tif ("g" if t.has("progress") or not ACData.unit(int(t.race),int(t.kind)).air else "a") in targets:_damage(u,t,damage,false)\n');
 s=sub(s,'\t\t\t\trider.pos=ACData.packed(unit_free_position','\t\t\t\trider.pos=ACData.packed(unit_free_position'); // unloading explicit fx below
 s=sub(s,'\t\tu.cargo=[]\n\t\tu.ability_cd=1','\t\tif not u.cargo.is_empty():_effect("unboard",u,center(u),.35)\n\t\tu.cargo=[]\n\t\tu.ability_cd=1');
 s=sub(s,'\t\tif d.role=="healer_detector" and int(t.race)==1',`\t\tif d.role=="priest" and int(t.race)==2 and u.energy>0:
			var amount=minf(float(td.hp)-float(t.hp),minf(10*dt,float(u.energy)*.5))
			t.hp+=amount;u.energy=maxf(0,float(u.energy)-amount*2)
			_healing_activity(u,t,"priest",amount)
			break
		if d.role=="healer_detector" and int(t.race)==1`);
 s=sub(s,'\tfor owner in range(players.size()):\n\t\tvar signature=hash(sources[owner])',`\tfor reveal in reveals:
		var radius=int(reveal.radius);var point=Vector2i(ACData.point(reveal.pos))
		if not vision_spans.has(radius):
			var spans: Array=[]
			for dy in range(-radius,radius+1):spans.append(Vector2i(dy,int(floor(sqrt(float(radius*radius-dy*dy))))))
			vision_spans[radius]=spans
		for owner in range(players.size()):
			if allied(owner,int(reveal.owner)):sources[owner][Vector3i(point.x,point.y,radius)]=true
	for owner in range(players.size()):
		var signature=hash(sources[owner])`);
 s=sub(s,'\t\t\t\tcopy.research=""','\t\t\t\tcopy.research=""\n\t\t\t\tcopy.research_queue=[]\n\t\t\t\tcopy.nuke_job={}');
 s=sub(s,'"home","spawn_slot"]','"home","spawn_slot","technologies","nukes"]');
 return s;
});
