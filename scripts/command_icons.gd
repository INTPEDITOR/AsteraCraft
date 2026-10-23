class_name ACCommandIcons
extends RefCounted

var _frames: Dictionary={}
var _skills: Array=[]

func _init() -> void:
	if FileAccess.file_exists("res://data/command_icons_v060.json"):
		_skills=JSON.parse_string(FileAccess.get_file_as_string("res://data/command_icons_v060.json")).skills

func texture(race: int, kind: String, index: int) -> Texture2D:
	var key="%s:%d:%d"%[kind,race,index]
	if _frames.has(key):return _frames[key]
	var authored="res://assets/v062/race%d/icons/%s_%02d.png"%[race,kind,index]
	if kind in ["units","buildings"] and ResourceLoader.exists(authored):
		_frames[key]=load(authored)
		return _frames[key]
	var file="res://assets/icons_%s_%d_v060.png"%[kind,race]
	var columns=8 if kind=="commands" else 4
	if index<0 or index>=columns*4 or not ResourceLoader.exists(file):return null
	var source: Texture2D=load(file)
	var cell=source.get_size()/Vector2(columns,4)
	var frame=AtlasTexture.new();frame.atlas=source;frame.filter_clip=true
	frame.region=Rect2(Vector2(index%columns,index/columns)*cell,cell)
	_frames[key]=frame
	return frame

func skill(race: int, id: String) -> Texture2D:
	if race==1 and id in ["sap_heal","sap_reclaim","sap_bloom"]:
		var key="support:"+id
		if _frames.has(key):return _frames[key]
		var file="res://assets/sap_support_v060.png"
		if not ResourceLoader.exists(file):return null
		var source: Texture2D=load(file);var cell=source.get_size()/Vector2(8,4)
		var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
		texture.region=Rect2(Vector2(["sap_heal","sap_reclaim","sap_bloom"].find(id),0)*cell,cell)
		_frames[key]=texture;return texture
	if race<0 or race>=_skills.size():return null
	var index=_skills[race].find(id)
	return texture(race,"commands",16+index) if index>=0 else null

func research(race: int, id: String) -> Texture2D:
	var index={"attack":26,"armor":27,"shield":28}.get(id,-1)
	return texture(race,"commands",int(index)) if index>=0 else skill(race,id)
