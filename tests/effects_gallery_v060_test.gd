extends "res://tests/view_input_v03_test.gd"
var gallery: Image
func capture(c,point,index,path):
	main.spectator=true;main.camera=point;main.zoom=1;main.state=c.snapshot(-1);main.selected=[]
	main._accept_visual_snapshot(main.state.units,float(c.time),true);main._update_hud();main._sync_world_canvas()
	for i in range(12):main.world_canvas.queue_redraw();await frames()
	await RenderingServer.frame_post_draw
	var screen=root.get_texture().get_image();var center=main._ground_point(point);var rect=Rect2i(center-Vector2(220,260),Vector2(440,340)).intersection(Rect2i(Vector2i.ZERO,screen.get_size()))
	var crop=screen.get_region(rect);crop.resize(440,340,Image.INTERPOLATE_LANCZOS)
	gallery.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(index%4*440,index/4*340));gallery.save_png(path)
func run():
	root.size=Vector2i(1440,900);main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);await frames(4)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);main.set_process(false)
	main._start_local({"map":0,"players":[{"race":0},{"race":1}]});main.paused=true;main.set_process(false)
	var c=main.core;var point=c.map.nearest_free(Vector2(64,64));var scout=c.add_unit(0,7,point+Vector2(-4,2));scout.energy=200;c.players[0].technologies={"nuclear":1};c.players[0].nukes=1
	for fog in c.visibility:fog.fill(1)
	for fog in c.explored:fog.fill(1)
	check(ACAbilities.use(c,scout,"nuclear",point)=="","real nuclear strike starts")
	gallery=Image.create(1760,680,false,Image.FORMAT_RGBA8);gallery.fill(Color("151515"))
	var times=[0.5,3.5,10.0,16.5,18.3,21.0,27.0,33.0]
	for i in range(times.size()):
		if c.time<18 and times[i]>18:c.time=18;ACAbilities.update(c,0)
		c.time=times[i];ACAbilities.update(c,0);c.effects=c.effects.filter(func(fx):return float(fx.until)>c.time)
		await capture(c,point,i,"res://build/qa-v060/nuclear-storyboard.png")
		if c.time>=18:check(main.nuclear_clouds.size()==1,"cloud remains visible during the sixteen-second fade %s"%c.time)
	c.time=34;c.effects=c.effects.filter(func(fx):return float(fx.until)>c.time);main.state=c.snapshot(-1);main._sync_world_canvas();check(main.nuclear_clouds.is_empty(),"cloud disappears only after final fade")
	check(main.assets.v060_effects.nuclear_cloud.size()==32 and main.assets.v060_effects.warhead.size()==16,"full cloud and warhead frame counts")
	# Render actual source geometry with roots retracting after HQ destruction.
	main._start_local({"map":0,"spawn_slots":[0,2],"players":[{"race":1},{"race":0}]});main.paused=true;main.set_process(false);c=main.core
	var hq=c.entity(c.players[0].home);point=c.center(hq);c.roots.update(c);c.time=20;c.roots.update(c);hq.hp=0
	gallery=Image.create(1760,340,false,Image.FORMAT_RGBA8);gallery.fill(Color("151515"))
	for i in range(4):
		c.time=20+[0,4,8,14][i]
		await capture(c,point,i,"res://build/qa-v060/root-withering-storyboard.png")
	check(c.roots.current.is_empty(),"rendered roots finish retracting")
	print("EFFECTS_GALLERY_V060 ",JSON.stringify({"checks":checks,"failures":failures}));main.queue_free();await frames();quit(0 if failures.is_empty() else 1)
