extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/passives-20261024/"
class Gallery:
	extends Control
	var entries: Array=[]
	var font: Font
	var textures: Array=[]
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("10171b"))
		draw_string(font,Vector2(42,49),"전용 연구 아이콘 · 10종",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("e3c887"))
		for index in range(entries.size()):
			var item=entries[index];var x=40+(index%5)*254;var y=88+(index/5)*267
			draw_rect(Rect2(x,y,238,245),Color("1b252b"))
			var texture=textures[index]
			draw_texture_rect(texture,Rect2(x+42,y+6,154,154),false)
			var name=ACData.unit(int(item.race),int(item.unit_kind)).name
			draw_string(font,Vector2(x+12,y+186),name,HORIZONTAL_ALIGNMENT_LEFT,216,18,Color.WHITE)
			draw_string(font,Vector2(x+12,y+218),item.name,HORIZONTAL_ALIGNMENT_LEFT,216,15,Color("b8d0d8"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1350,650);root.content_scale_size=root.size
	var entries=ACData.get_data().research.filter(func(item):return item.has("unit_kind"))
	var gallery=Gallery.new();gallery.entries=entries;gallery.font=ACUIFont.create()
	for item in entries:gallery.textures.append(load("res://assets/ui/passive_upgrades_20261024/"+item.id+".png"))
	root.add_child(gallery);gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"research-icons-ten.png");gallery.queue_free();await frames(2)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	for race in range(3):
		main._start_local({"map":1,"seed":601,"players":[{"race":race},{"race":(race+1)%3}]});main.paused=true;main.set_process(false);main.spectator=true;main.camera=Vector2(64,64)
		var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.players[0].as=10000;c.players[0].tera=10000
		for item in entries:
			if int(item.race)!=race:continue
			for kind in item.requires:c.add_building(0,int(kind),Vector2(20+int(kind)*4,20),true)
			var building=c.add_building(0,int(item.building),Vector2(62,62),true);main.selected=[building.id];main.state=c.snapshot(-1);main._sync_world_canvas();main.battle_hud.update_hud(true);main.queue_redraw();await frames(3)
			var specs=main.battle_hud.action_specs.filter(func(spec):return not spec.is_empty() and spec.get("cost",{}).get("research_stat","")==item.id)
			check(specs.size()==1 and specs[0].texture!=null and item.id in specs[0].texture.resource_path,"actual command uses unique isolated new icon "+item.id)
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"command-"+item.id+".png")
	FileAccess.open(OUT+"icons-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"icons":10,"separate_files_prevent_atlas_neighbor_bleed":true},"\t"))
	print("PASSIVE_ICONS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
