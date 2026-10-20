class_name ACEntityCanvas
extends Control
var main
var entity: Dictionary={}
var bounds=Rect2()
var body_bounds=Rect2()
var next_pose=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	draw.connect(_draw_entity)
func _draw_entity() -> void:
	if entity.is_empty():return
	var previous=main.world_canvas
	main.world_canvas=self;main._object_canvas_offset=position
	main._world_transform()
	if entity.has("amount"):
		var point=main._ground_point(ACData.point(entity.pos))
		if entity.type=="as" and entity.amount>0:main._draw_ore(point,entity)
		elif entity.type=="tera" and main._resource_refinery(entity).is_empty():main._draw_vent(point,entity)
		elif int(entity.id)==main.selected_resource:main._draw_resource_selection(point,entity)
	elif entity.has("progress"):main._draw_building(entity)
	else:main._draw_unit(entity)
	if main.render_rects.has(int(entity.id)):
		bounds=main.render_rects[int(entity.id)]
		bounds.position-=position+main.world_clip.position
	if main._selection_bodies.has(int(entity.id)):
		body_bounds=main._selection_bodies[int(entity.id)]
		body_bounds.position-=position+main.world_clip.position
	main.world_canvas=previous;main._object_canvas_offset=Vector2.ZERO
