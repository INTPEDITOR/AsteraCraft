extends "res://tests/view_input_v03_test.gd"
var phase="after"
var mode="fog"
var output="res://build/fog-north-20261025/"
var records=[]
func photo(file):
	await frames(4);await RenderingServer.frame_post_draw
	var pixels=root.get_texture().get_image();pixels.save_png(output+file+".png");return pixels
func run():
	var args=OS.get_cmdline_user_args()
	if args.size()>0:phase=args[0]
	if args.size()>1:mode=args[1]
	output+=phase+"-"+mode+"/";DirAccess.make_dir_recursive_absolute(output)
	main=load("res://build/fog-north-20261025/legacy-main.gd" if phase=="before" else "res://scripts/main.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(5)
	main.set_process(false);main.set_process_input(false);main.set_process_unhandled_input(false)
	for connection in root.mouse_exited.get_connections():
		if connection.callable.get_object()==main:root.mouse_exited.disconnect(connection.callable)
	root.size=Vector2i(1920,1080);ACSettings.keep_game_aspect();await frames(3)
	var probes=JSON.parse_string(FileAccess.get_file_as_string("res://build/cliff-fix-20261025/height-probe-before.json"))
	for map_id in range(3):
		for race in range(1 if mode=="fog" else 3):
			main._start_local({"map":map_id,"players":[{"race":race},{"race":(race+1)%3}]});main._stop_simulation_worker();main.set_process(false);main.paused=true;main.settings.edge_scroll=false
			var c=main.core;c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
			for mask in c.explored:mask.fill(0)
			c.vision_signatures.clear()
			if mode=="fog":
				var p=ACData.point(probes[map_id].examples[0].pos)
				var unit=c.add_unit(0,0,p);c._update_vision();main.spectator=false;main.selected=[unit.id];main.camera=p;main.zoom=1.3
				main.state=c.snapshot(0);main._accept_visual_snapshot(main.state.units,c.time,true);main.battle_hud.update_hud(true);main._sync_world_canvas();main.queue_redraw()
				var shown=await photo("map%d-fog"%map_id)
				main._fog_canvas.hide()
				var clear=await photo("map%d-reference"%map_id)
				var tested=0;var dark=[];var min_ratio=1.0
				for y in range(maxi(1,int(p.y)-7),mini(127,int(p.y)+8)):
					for x in range(maxi(1,int(p.x)-7),mini(127,int(p.x)+8)):
						var q=Vector2(x,y);var index=y*128+x
						if q.distance_squared_to(p)<4 or not c._ground_fits_size(Vector2(.52,.44),q):continue
						var interior=true
						for dy in range(-1,2):
							for dx in range(-1,2):
								if c.visibility[0][index+dy*128+dx]==0:interior=false
						if not interior:continue
						var screen=main._ground_point(q)
						if not Rect2(20,45,1880,690).has_point(screen) or main.screen_to_world(screen).distance_to(q)>.02:continue
						var pixel=Vector2i((screen*Vector2(shown.get_size())/main.size).round());var a=shown.get_pixelv(pixel);var b=clear.get_pixelv(pixel)
						var value=b.r+b.g+b.b
						if value<.12:continue
						var ratio=(a.r+a.g+a.b)/value;min_ratio=minf(min_ratio,ratio);tested+=1
						if ratio<.94:dark.append({"world":ACData.packed(q),"screen":ACData.packed(screen),"ratio":ratio})
				check(tested>=20,"enough visible ground samples map "+str(map_id))
				check(dark.is_empty(),"visible ground has no erroneous fog map %d dark=%d/%d"%[map_id,dark.size(),tested])
				records.append({"map":map_id,"source":ACData.packed(p),"samples":tested,"incorrect_dark":dark,"minimum_ratio":min_ratio})
			else:
				var air_kind=0
				for kind in range(ACData.unit_count(race)):
					if ACData.unit(race,kind).air:air_kind=kind;break
				for x in [52,64,76]:
					c.add_unit(0,air_kind,Vector2(x,1))
					var found=false
					for yi in range(4,25):
						var p=Vector2(x+3,yi*.25)
						if c._ground_fits_size(ACCore.collision_size(race,0),p):c.add_unit(0,0,p);found=true;break
				main.spectator=true;main.selected=c.units.map(func(u):return u.id);main.zoom=1.5
				main.state=c.snapshot();main._accept_visual_snapshot(main.state.units,c.time,true)
				main.camera=Vector2(64,-10000);main._clamp_camera();main.battle_hud.update_hud(true);main._sync_world_canvas();main.queue_redraw();await frames(4)
				main.camera.y=-10000;main._clamp_camera();main._sync_world_canvas();main.queue_redraw();await frames(4)
				await photo("map%d-race%d-north"%[map_id,race])
				var bodies=[]
				for u in c.units:
					var node=main._entity_canvases.get(int(u.id))
					if node==null:check(false,"northern entity exists");continue
					var body=Rect2(node.bounds.position+node.position+main.world_clip.position,node.bounds.size)
					check(body.has_area() and body.position.y-14>=1,"northern full sprite and bars visible map%d race%d kind%d top%.1f"%[map_id,race,u.kind,body.position.y])
					bodies.append({"kind":u.kind,"pos":u.pos,"screen_top":body.position.y})
				records.append({"map":map_id,"race":race,"camera":ACData.packed(main.camera),"bodies":bodies})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records,"mode":mode,"phase":phase}
	FileAccess.open(output+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FOG_NORTH_VISUAL ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures.size(),"mode":mode,"phase":phase}));main._release_pointer();quit(0 if phase=="before" or failures.is_empty() else 1)
