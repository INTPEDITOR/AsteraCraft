const fs=require('fs');
function edit(file,fn){fs.writeFileSync(file,fn(fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n')),'utf8')}
function sub(s,a,b){if(!s.includes(a))throw Error('Missing '+a.slice(0,100));return s.replace(a,b)}
edit('scripts/main.gd',s=>{
 s=sub(s,'var pointer_order=', 'var pointer_skill: String=""\nvar pointer_order=');
 s=sub(s,'elif order=="ability":_send_command','elif order=="skill":_send_command({"type":"skill","skill":pointer_skill,"ids":selected,"pos":ACData.packed(point),"target":-1 if minimap else _hit_test(mouse)})\n\telif order=="ability":_send_command');
 s=s.replaceAll('for kind in range(13):','for kind in range(ACData.unit_count(race)):');
 return s;
});
edit('scripts/rts_hud.gd',s=>{
 s=sub(s,'main.selected=main.selected.filter(func(id):return not main._entity(int(id)).is_empty()).slice(0,MAX_SELECTION)',`main.selected=main.selected.filter(func(id):return not main._entity(int(id)).is_empty())
	if not main.selected.all(func(id):return _is_brood_entity(main._entity(int(id)))):main.selected=main.selected.slice(0,MAX_SELECTION)`);
 s=sub(s,'\t_update_details()\n',`\tif float(player.get("hq_deadline",-1))>=0 and not player.get("lost",false):
		status_label.text="본진 상실 · %d초 이내 본진 건설을 완료해야 합니다"%maxi(0,ceili(float(player.hq_deadline)-float(state.time)))
	_update_details()
`);
 s=sub(s,'str([player.get("attack",0),player.get("armor",0),player.get("shield",0)])','str([player.get("attack",0),player.get("armor",0),player.get("shield",0),player.get("technologies",{}),player.get("nukes",0)])');
 s=sub(s,'str(_unit.get("cloak_active",false))','str(_unit.get("cloak_active",false))+str(_unit.get("cargo",[]))+str(_unit.get("drones",[]))+str(_unit.get("drone_queue",[]).size())');
 s=sub(s,'str(float(_unit.progress)>=1)+str(_unit.get("queue",[])','str(_unit.get("nuke_job",{}).is_empty())+str(float(_unit.progress)>=1)+str(_unit.get("queue",[])');
 s=sub(s,'for kind in range(13):\n\t\tif int(ACData.unit(int(_unit.race),kind).producer)', 'for kind in range(ACData.unit_count(int(_unit.race))):\n\t\tif int(ACData.unit(int(_unit.race),kind).producer)');
 s=sub(s,'for train in range(13) if faction!=1 else []:', 'for train in range(ACData.unit_count(faction)) if faction!=1 else []:');
 const start=s.indexOf('\n\t\telif role=="mage":');const end=s.indexOf('\n\t\telif role=="transport":',start);
 if(start<0||end<0)throw Error('oldskills');s=s.slice(0,start)+s.slice(end);
 s=sub(s,'\n\telse:\n\t\tif float(_unit.progress)<1:',`\n\t\tvar skill_keys=[KEY_W,KEY_E,KEY_T,KEY_F]
		var skill_names=["W","E","T","F"]
		var skills=ACAbilities.catalog(faction,kind)
		for index in range(skills.size()):
			var skill: Dictionary=skills[index]
			var skill_id=str(skill.id)
			all.append(_command(str(skill.name),skill_keys[index],skill_names[index],ICON_ABILITY,func():_skill(skill_id),_skill_tip(skill),null,{"skill":skill_id}))
		if role=="priest":all.append(_command("자동 체력 회복",0,"",ICON_REPAIR,func():main._notify("에너지 2당 체력 1 자동 회복 · 초당 최대 10"),"부상한 아군 부엉이의 체력을 자동 회복합니다.\n체력 1당 에너지 2 · 최대 초당 체력 10"))
		if role=="carrier":
			all.append(_command("요격 드론 생산",KEY_Q,"Q",ICON_TRAIN,func():main._send_command({"type":"produce_drone","id":id}),"아스 25 · 테라 10 · 8초\n모함당 생산 예약 포함 최대 8기",_unit_texture(0,15),{"as":25,"tera":10,"drone":true}))
			all.append(_command("드론 생산 취소",KEY_X,"X",ICON_CANCEL,func():main._send_command({"type":"cancel_drone","id":id}),"마지막 드론 생산을 취소하고 비용을 반환합니다."))
	else:
		if float(_unit.progress)<1:`);
 s=sub(s,'\t\t\tif all.size()>9:',`\t\t\tif faction==0 and kind==8:
				all.append(_command("핵미사일 생산",0,"",ICON_TRAIN,func():main._send_command({"type":"produce_nuke","id":id}),"아스 300 · 테라 200 · 75초\n유도 연구 필요 · 최대 3발 보유",null,{"as":300,"tera":200,"nuke":true}))
				if not _unit.get("nuke_job",{}).is_empty():all.append(_command("핵미사일 생산 취소",0,"",ICON_CANCEL,func():main._send_command({"type":"cancel_nuke","id":id}),"생산 취소 · 비용 전액 반환"))
			if all.size()>9:`);
 s=sub(s,'\t\tif not cost.is_empty():\n\t\t\tif float(player',`\t\tif cost.has("skill"):
			var skill=ACAbilities.catalog(int(_unit.race),int(_unit.kind)).filter(func(d):return d.id==cost.skill)[0]
			if not ACAbilities.unlocked(player,skill):reasons.append("연구 필요: "+str(skill.name))
			if float(_unit.get("energy",0))<float(skill.energy):reasons.append("에너지 부족")
			var remaining=float(_unit.get("skill_ready",{}).get(str(skill.id),0))-float(main.state.time)
			if skill.id=="mind_control":remaining=maxf(remaining,float(_unit.get("ability_cd",0)))
			if remaining>0:reasons.append("재사용 대기 %d초"%ceili(remaining))
			if float(_unit.get("silenced_until",0))>float(main.state.time):reasons.append("능력 봉인 중")
		elif not cost.is_empty():
			if float(player`);
 s=sub(s,'\t\t\telif not cost.has("w"):',`\t\t\telif cost.has("nuke"):
				if ACResearch.level(player,"nuclear")==0:reasons.append("핵미사일 유도 연구 필요")
				if not _unit.get("nuke_job",{}).is_empty():reasons.append("핵미사일 생산 중")
				if int(player.get("nukes",0))>=3:reasons.append("핵미사일 최대 보유량")
			elif cost.has("drone"):
				if _unit.get("drones",[]).size()+_unit.get("drone_queue",[]).size()>=8:reasons.append("드론 최대 8기")
			elif not cost.has("w"):`);
 s=sub(s,'if not cost.is_empty():help_lines.append','if not cost.is_empty() and not cost.has("skill"):help_lines.append');
 s=sub(s,'"테라 자동 추출  ·  2.5초마다 +12"','"테라 자동 추출  ·  3초마다 +8"');
 s=sub(s,'\t\tvar lines=[hp+shield,"공격 %d', '\t\tvar lines=[hp+shield+" · "+("중장갑" if _definition.get("armor_class","")=="heavy" else "경장갑"),"공격 %d');
 s=sub(s,'\t\tif _uses_energy(_definition):',`\t\tif float(_definition.get("bonus_light",0))>0:lines[1]+=" · 경장갑 +%d"%int(_definition.bonus_light)
		if float(_definition.get("bonus_heavy",0))>0:lines[1]+=" · 중장갑 +%d"%int(_definition.bonus_heavy)
		if _definition.has("damage_air"):lines[1]+=" · 공중 %d"%int(_definition.damage_air)
		if _definition.role=="carrier":lines[1]="요격 드론 %d / 8 · 생산 대기 %d"%[_unit.get("drones",[]).size(),_unit.get("drone_queue",[]).size()]
		if _uses_energy(_definition):`);
 s+=`\nfunc _is_brood_entity(entity: Dictionary) -> bool:
	return not entity.is_empty() and not entity.has("progress") and int(entity.race)==1 and int(entity.kind)==13

func _skill_tip(skill: Dictionary) -> String:
	var rule="기본 능력" if skill.get("base",false) else str(ACData.building(int(skill.race),int(skill.building)).name)+" 연구 필요"
	return "%s · 에너지 %d\n사거리 %s · 재사용 %d초\n%s"%[rule,int(skill.energy),_number(float(skill.range)),int(skill.cooldown),ACAbilities.description(str(skill.id))]

func _skill(key: String) -> void:
	var skill=ACAbilities.catalog(int(_unit.race),int(_unit.kind)).filter(func(d):return d.id==key)[0]
	if skill.target=="self":main._send_command({"type":"skill","skill":key,"ids":main.selected.duplicate(),"pos":_unit.pos})
	else:
		main.pointer_skill=key;_target_order("skill");main._notify(str(skill.name)+": 대상 지정 · 우클릭 취소")
`;
 return s;
});
