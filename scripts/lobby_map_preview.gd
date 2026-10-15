class_name ACLobbyMapPreview
extends Control

# The lobby thumbnail is rendered from the same masks/resources as the battle.
var map_id=-1
var battlefield: ACMap
var thumbnail: ImageTexture

static func map_names() -> Array:
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json"))
	var names: Array=[]
	for item in catalog.maps:names.append(str(item.name))
	return names

func set_map(value: int) -> void:
	value=clampi(value,0,2)
	if map_id==value:return
	map_id=value
	battlefield=ACMap.new()
	battlefield.make(map_id)
	var image=Image.create(ACMap.SIZE,ACMap.SIZE,false,Image.FORMAT_RGBA8)
	var palettes=[
		[Color("625740"),Color("30302b"),Color("15455a"),Color("8b7850")],
		[Color("6c5544"),Color("30252d"),Color("3f6753"),Color("9b7853")],
		[Color("77756d"),Color("33343d"),Color("385066"),Color("b1a99a")]
	]
	for y in range(ACMap.SIZE):
		for x in range(ACMap.SIZE):
			var i=y*ACMap.SIZE+x
			var color=palettes[map_id][int(battlefield.terrain[i])]
			if battlefield.terrain[i]==0 and battlefield.surface_map[i] in [3,4]:color=palettes[map_id][3]
			image.set_pixel(x,y,color)
	thumbnail=ImageTexture.create_from_image(image)
	queue_redraw()

func _draw() -> void:
	if thumbnail==null:return
	var rect=Rect2(Vector2.ZERO,size)
	draw_texture_rect(thumbnail,rect,false)
	var scale=size/float(ACMap.SIZE)
	for resource in battlefield.resources:
		var point=ACData.point(resource.pos)*scale
		var extent=Vector2(3.2,2.2) if resource.type=="as" else Vector2(5.5,3.2)
		draw_rect(Rect2(point-extent*.5,extent),Color("e8bc3d") if resource.type=="as" else Color("55b4e7"))
	for index in range(battlefield.starts.size()):
		var point=ACData.point(battlefield.starts[index])*scale
		draw_rect(Rect2(point-Vector2(5,5),Vector2(10,10)),Color("f3e2af"),false,1.5)
	draw_rect(rect,Color("a98e50"),false,2.0)
