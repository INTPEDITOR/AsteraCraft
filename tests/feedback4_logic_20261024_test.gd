extends "res://tests/abilities_v060_test.gd"
const OUT="res://build/feedback4-20261024/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	check(ACData.get_data().race_names==["노바너","이귤","아라아울"],"confirmed Korean-only race names")
	for item in ACData.get_data().research:
		if not item.has("unit_kind"):continue
		var producers=[0,3] if int(item.race)==1 else ACData.get_data().units[int(item.race)].map(func(unit):return int(unit.producer))
		check(not int(item.building) in producers,"unit passive is separated from every actual unit production building "+item.id)
	var c=arena(0,0);c.time=10
	var labs={}
	for kind in [0,3,4,5,7,9,10]:labs[kind]=c.add_building(0,kind,Vector2(10+kind*5,15),true)
	var locations={"frontline_vitality":7,"missile_autoloader":9,"flamer_range":9,"transport_thrusters":10}
	for key in locations:
		var location=int(locations[key]);var definition=ACResearch.definition(0,location,key)
		check(not definition.is_empty(),"research available at requested building "+key)
		check(ACResearch.definition(0,3 if key=="frontline_vitality" else 5 if key=="transport_thrusters" else 4,key).is_empty(),"research removed from former producer "+key)
		check(ACResearch.enqueue(c,0,labs[location],key)=="","new lab accepts research "+key)
	var jobs=[[3,1],[4,6],[4,13],[5,11]]
	for job in jobs:
		var factory=labs[job[0]];var before=c.units.size()
		check(c.command(0,{"type":"train","id":factory.id,"kind":job[1]})=="","production accepts order while remote lab is researching "+str(job[1]))
		factory.queue[0].left=.01;c._tick_building(factory,.1)
		check(c.units.size()==before+1 and factory.queue.is_empty(),"production finishes while lab research continues "+str(job[1]))
	check(str(labs[7].research)=="frontline_vitality" and ACResearch.level(c.players[0],"frontline_vitality")==0,"rifle production does not consume or complete lab research")
	var shield=c.add_unit(0,3,Vector2(40,40));var before_fx=c.effects.size()
	check(c.command(0,{"type":"ability","ids":[shield.id],"pos":shield.pos})!="","removed shield deployment rejects legacy command")
	check(not shield.anchored and shield.ability_cd==0 and c.effects.size()==before_fx,"removed command cannot immobilize shield infantry")
	var mixer=ACAudio.new();root.add_child(mixer);await process_frame
	var sounded=[]
	for skill in ACData.get_data().abilities:
		c=arena(int(skill.race),int(skill.race));c.time=10;c.map.height_map.fill(0)
		var u=c.add_unit(0,int(skill.kinds[0]),Vector2(40,40));u.energy=200
		var enemy=c.add_unit(1,1,Vector2(42,40));var target=c.add_unit(0,1,Vector2(41,40)) if str(skill.id)=="sap_reclaim" else u if skill.target=="ally" else enemy
		c.players[0].technologies[skill.id]=1
		if skill.id=="sap_reclaim":u.energy=100
		if skill.id=="root_surge":u.anchored=true
		if skill.id=="nuclear":c.players[0].nukes=1
		reveal(c)
		check(cast(c,u,skill.id,target)=="","sound audit performs successful actual cast "+skill.id)
		mixer.clear();mixer._camera=Vector2(40,40)
		var played=int(mixer.debug_stats.played);mixer.consume_effects(c.effects,c.time)
		check(int(mixer.debug_stats.played)>played,"actual ability event starts an audible sound "+skill.id)
		check(mixer._stream("skill_"+skill.id)!=null,"dedicated skill sound exists "+skill.id)
		if skill.id=="mind_control":check(mixer.last_cue=="skill_mind_control","mind control uses its dedicated sound instead of medical healing")
		sounded.append(skill.id)
	c=arena(0);c.time=10
	for kind in [5,7,12]:
		var u=c.add_unit(0,kind,Vector2(40,40));u.energy=200;c.effects.clear()
		check(c.command(0,{"type":"ability","ids":[u.id],"pos":u.pos})=="","built-in toggle accepts command "+str(kind))
		mixer.clear();mixer._camera=Vector2(40,40);var played=int(mixer.debug_stats.played);mixer.consume_effects(c.effects,c.time)
		check(int(mixer.debug_stats.played)>played,"deployment or cloak toggle produces sound "+str(kind))
	mixer.queue_free()
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"actual_skill_casts_with_sound":sounded,"research_buildings":locations,"production_during_research":jobs.size()}
	FileAccess.open(OUT+"logic-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FEEDBACK4_LOGIC ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
