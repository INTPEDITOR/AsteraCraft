class_name ACEntityCanvas
extends Control
var main
var entity: Dictionary={}
var bounds=Rect2()
var body_bounds=Rect2()
var next_pose=0.0
var drawn_zoom=-1.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	draw.connect(_draw_entity)
func _draw_entity() -> void:
	if entity.is_empty():return
	drawn_zoom=main.zoom
	var previous=main.world_canvas
	var previous_palette=main._palette_entity
	main._palette_entity=entity if entity.has("owner") else {}
	main.world_canvas=self;main._object_canvas_offset=position
	main._world_transform()
	if entity.has("amount"):
		var point=main._ground_point(ACData.point(entity.pos))
		# Deposits near the map edge can have their ground origin outside the
		# viewport while the tall mineral sprite remains visible inside it.
		bounds=main._resource_screen_rect(entity)
		bounds.position-=position+main.world_clip.position
		if entity.type=="as" and entity.amount>0:main._draw_ore(point,entity)
		elif entity.type=="tera" and main._catalyst_presence(entity)>0:main._draw_vent(point,entity)
		elif int(entity.id)==main.selected_resource:main._draw_resource_selection(point,entity)
	elif entity.has("progress"):main._draw_building(entity)
	else:main._draw_unit(entity)
	if main.render_rects.has(int(entity.id)):
		bounds=main.render_rects[int(entity.id)]
		bounds.position-=position+main.world_clip.position
	if main._selection_bodies.has(int(entity.id)):
		body_bounds=main._selection_bodies[int(entity.id)]
		body_bounds.position-=position+main.world_clip.position
	# Explicit local bounds keep tall sprites alive while their ground origin
	# is outside the viewport; include the contact shadow and selection bars.
	if bounds.has_area():
		var cull_bounds=bounds.merge(Rect2(Vector2(-32,-32),Vector2(64,64))).grow(128*main.zoom)
		RenderingServer.canvas_item_set_custom_rect(get_canvas_item(),true,cull_bounds)
	main.world_canvas=previous;main._object_canvas_offset=Vector2.ZERO
	main._palette_entity=previous_palette
