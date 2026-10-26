class_name ACData
extends RefCounted

static var content: Dictionary = {}
static var clearance_templates: Dictionary={}
static var _unit_research: Dictionary={}
static var _effective_units: Dictionary={}

static func clearance_template(theme: int, size: Vector2i, walk_masks_sha256: String="") -> Array:
	if clearance_templates.is_empty():
		var path="res://data/clearance_v060.json"
		clearance_templates=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"maps":[]}
		if clearance_templates.get("geometry_sha256","")!=FileAccess.get_sha256("res://data/source_terrain_detail.json") or int(clearance_templates.get("walk_policy",0))!=ACMap.SOURCE_WALK_POLICY:clearance_templates={"maps":[]}
	var maps: Array=clearance_templates.get("maps",[])
	var signatures: Array=clearance_templates.get("walk_masks_sha256",[])
	if walk_masks_sha256.is_empty() or theme<0 or theme>=signatures.size() or str(signatures[theme])!=walk_masks_sha256:return []
	return maps[theme].get("%d,%d"%[size.x,size.y],[]) if theme>=0 and theme<maps.size() else []

static func get_data() -> Dictionary:
	if content.is_empty():
		content = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	return content

static func unit(race: int, kind: int) -> Dictionary:
	if race==1 and kind==13:
		return {"id":13,"name":"배양체","hp":60,"shield":0,"armor":0,"as":0,"tera":0,"pop":0,"damage":0,"range":0,"period":1,"speed":0,"air":false,"targets":"","size":.65,"producer":0,"requires":[],"role":"brood","time":1,"technical":true,"max_energy":0,"description":"귤나무에 맺힌 개별 배양체. 선택한 군체 유닛으로 각각 변태합니다."}
	return get_data().units[race][kind]

static func building(race: int, kind: int) -> Dictionary:
	return get_data().buildings[race][kind]

static func max_health(entity: Dictionary,players: Array=[]) -> float:
	# Public snapshots carry the visible cap without exposing enemy research.
	if entity.has("max_hp"):return float(entity.max_hp)
	return float(building(int(entity.race),int(entity.kind)).hp) if entity.has("progress") else float(entity_unit(entity,players).hp)

static func unit_research(race: int,kind: int) -> Dictionary:
	if _unit_research.is_empty():
		for entry in get_data().get("research",[]):
			if entry.has("unit_kind"):_unit_research["%d:%d"%[int(entry.race),int(entry.unit_kind)]]=entry
	return _unit_research.get("%d:%d"%[race,kind],{})

static func unit_for_player(race: int,kind: int,player: Dictionary) -> Dictionary:
	var base=unit(race,kind);var research=unit_research(race,kind)
	if research.is_empty() or int(player.get("technologies",{}).get(research.id,0))<=0:return base
	var key=str(research.id)
	if not _effective_units.has(key):
		var effective=base.duplicate();var stat=str(research.stat)
		effective[stat]=float(base[stat])*float(research.get("multiply",1))+float(research.get("add",0))
		effective._research_id=key
		_effective_units[key]=effective
	return _effective_units[key]

static func entity_unit(entity: Dictionary,players: Array=[]) -> Dictionary:
	if entity.has("_definition"):return entity._definition
	var race=int(entity.race);var kind=int(entity.kind)
	if entity.has("effective_stats"):
		var key="visible:%d:%d:%s"%[race,kind,str(entity.effective_stats)]
		if not _effective_units.has(key):
			var effective=unit(race,kind).duplicate()
			for stat in ["hp","speed","range","period"]:
				if entity.effective_stats.has(stat):effective[stat]=entity.effective_stats[stat]
			_effective_units[key]=effective
		return _effective_units[key]
	var owner=int(entity.get("owner",-1))
	return unit_for_player(race,kind,players[owner]) if owner>=0 and owner<players.size() else unit(race,kind)

static func unit_count(race: int) -> int:
	return get_data().units[race].size()

static func attack_range(definition: Dictionary,anchored: bool=false) -> float:
	var reach=float(definition.get("range",0))
	if anchored and can_deploy(definition) and str(definition.get("role","")) in ["siege","fortress"]:
		reach+=float(definition.get("deployed_range_bonus",3.0))
	return reach

static func can_deploy(definition: Dictionary) -> bool:
	return bool(definition.get("deployable",str(definition.get("role","")) in ["siege","fortress","tree"]))

static func portrait_score(entity: Dictionary) -> int:
	if entity.is_empty() or entity.has("progress"):return -1
	return int(unit(int(entity.race),int(entity.kind)).get("portrait_priority",0))

static func portrait_leader(entities: Array) -> Dictionary:
	var best: Dictionary={}
	for entity in entities:
		if entity.is_empty() or float(entity.get("hp",0))<=0:continue
		var score=portrait_score(entity)
		if best.is_empty() or score>portrait_score(best) or (score==portrait_score(best) and int(entity.id)<int(best.id)):
			best=entity
	return best

static func unit_max_energy(race: int, kind: int) -> float:
	var definition=unit(race,kind)
	return maxf(0,float(definition.get("max_energy",200 if definition.role in ["medic","mage","priest"] else 0)))

static func missing_building_names(race: int, required: Array, completed: Array=[]) -> Array:
	var names: Array=[]
	for kind in required:
		var index=int(kind)
		if index>=0 and index<get_data().buildings[race].size() and not completed.any(func(value):return int(value)==index):
			var name=str(building(race,index).name)
			if name not in names:names.append(name)
	return names

static func research_stats(race: int, kind: int) -> Array:
	if kind!=(5 if race==1 else 6):return []
	return ["attack","armor","shield"] if race==2 else ["attack","armor"]

static func point(v) -> Vector2:
	if v is Vector2:
		return v
	return Vector2(float(v[0]), float(v[1]))

static func packed(v: Vector2) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001)]

static func elo(winner: int, loser: int) -> int:
	return maxi(1, int(round(40.0 * (1.0 - 1.0 / (1.0 + pow(10.0, float(loser - winner) / 400.0))))))

static func sprite_direction(screen_direction: Vector2, directions: int) -> Dictionary:
	var angle = fposmod(atan2(screen_direction.x, -screen_direction.y), TAU)
	var index = posmod(int(floor(angle / TAU * directions + 0.5)), directions)
	var half = directions / 2
	return {"column": index if index <= half else directions - index, "flip": index > half}
