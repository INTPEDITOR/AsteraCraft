extends SceneTree
class Board extends Control:
	var art=ACAssets.new()
	var raw={}
	func _draw() -> void:
		draw_rect(Rect2(0,0,1800,1000),Color("1b242a"))
		var headings=[1,2,3,13,14,15]
		for col in range(6):
			var direction=Vector2.UP.rotated(headings[col]*TAU/16)
			for row in range(3):
				var frame=art.sprites.sample(raw,"walk",direction,0) if row==0 else art.unit(1,10,direction,"walk",0) if row==1 else art.sprites.sample(raw,"walk",Vector2(-direction.x,direction.y),0)
				if row==2:frame=frame.duplicate();frame.flip=not frame.get("flip",false)
				var center=Vector2(col*300+150,row*320+190)
				var scale_value=230.0/float(frame.scale_hint)
				draw_set_transform(center,0,Vector2(-scale_value if frame.flip else scale_value,scale_value));draw_texture(frame.texture,-frame.anchor);draw_set_transform(Vector2.ZERO)
				draw_string(ThemeDB.fallback_font,Vector2(col*300+12,row*320+30),["RAW","APPLIED","REFLECT OPPOSITE"][row]+" dir%d"%headings[col],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
				draw_line(center+Vector2(0,110),center+Vector2(0,110)+direction*45,Color.CYAN,3,true)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/citrus-bat-20261024")
	root.size=Vector2i(1800,1000);root.content_scale_size=root.size
	var board=Board.new();board.art.load_all();board.raw=JSON.parse_string(FileAccess.get_file_as_string("res://data/art_staged16_units.json")).units["1:10"]
	board.raw.scale_hint=board.art.sprites.units["1:10"].scale_hint
	root.add_child(board);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/citrus-bat-20261024/raw-v-applied.png");quit()
