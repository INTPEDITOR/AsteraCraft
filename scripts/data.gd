class_name ACData
extends RefCounted

static var content: Dictionary = {}
static var clearance_templates: Dictionary={}

static func clearance_template(theme: int, size: Vector2i) -> Array:
	if clearance_templates.is_empty():
		var path="res://data/clearance_v060.json"
		clearance_templates=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"maps":[]}
		if clearance_templates.get("geometry_sha256","")!=FileAccess.get_sha256("res://data/source_terrain_detail.json") or int(clearance_templates.get("walk_policy",0))!=2:clearance_templates={"maps":[]}
	var maps: Array=clearance_templates.get("maps",[])
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

static func unit_count(race: int) -> int:
	return get_data().units[race].size()

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
