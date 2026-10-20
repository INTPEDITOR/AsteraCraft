extends SceneTree
class IconCanvas extends Control:
	var painter
	var kind=0
	var race=0
	func _draw():
		painter.world_canvas=self;painter._world_transform()
		var direction=Vector2(1,1);var definition=ACData.unit(race,kind);var point=Vector2(128,128 if definition.air else 220);var extent=170.0
		if race==0 and kind==8:
			painter._draw_drone({"race":0,"kind":8,"id":1,"facing":[1,1]},point,extent,Color.WHITE,0)
			return
		var vehicle=painter.assets.vehicle(race,kind,direction,direction)
		if vehicle.is_empty():painter._draw_unit_frame(painter.assets.unit(race,kind,direction,"idle",0),point,extent)
		else:
			painter._draw_unit_frame(vehicle.chassis,point,extent)
			var factor=extent/float(vehicle.chassis.scale_hint);var mount=point+vehicle.mount*factor
			painter._draw_unit_frame(vehicle.turret,mount,extent*vehicle.turret_scale)
			if not vehicle.embedded_pilot:
				painter._draw_unit_frame(painter.assets.pilot(direction),mount+vehicle.pilot_mount*factor*vehicle.turret_scale,20)
func _initialize():call_deferred("run")
func run():
	var art=ACAssets.new();art.load_all()
	var painter=load("res://scripts/main.gd").new();painter.assets=art;painter.zoom=1;painter.world_clip=Control.new()
	var viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var canvas=IconCanvas.new();canvas.painter=painter;canvas.size=Vector2(256,256);viewport.add_child(canvas)
	for race in [0,2]:
		var image=Image.load_from_file("res://assets/icons_units_%d_v060.png"%race);image.convert(Image.FORMAT_RGBA8)
		for kind in ([5,6,8,9,10,11,12,13,14,15] if race==0 else [13]):
			canvas.kind=kind;canvas.race=race;canvas.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			var icon=viewport.get_texture().get_image();var used=icon.get_used_rect()
			if not used.has_area():push_error("Empty actual unit icon");quit(1);return
			icon=icon.get_region(used);var factor=112.0/maxf(icon.get_width(),icon.get_height());icon.resize(maxi(1,roundi(icon.get_width()*factor)),maxi(1,roundi(icon.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
			var cell=Image.create(128,128,false,Image.FORMAT_RGBA8);cell.fill(Color.TRANSPARENT);cell.blit_rect(icon,Rect2i(Vector2i.ZERO,icon.get_size()),(Vector2i(128,128)-icon.get_size())/2)
			image.blit_rect(cell,Rect2i(0,0,128,128),Vector2i(kind%4,kind/4)*128)
		image.save_png("res://assets/icons_units_%d_v060.png"%race)
	painter.world_clip.free();painter.free();viewport.queue_free();await process_frame
	print("BAKED_LIVE_UNIT_ICONS_V061 11 exact runtime silhouettes with transparent cell backgrounds");quit()
