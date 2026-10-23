extends SceneTree
class Flames extends Control:
	var effect=ACBuildingDamageVisual.new()
	func _draw():
		draw_rect(Rect2(0,0,800,360),Color("22272a"))
		for i in range(6):effect._flame(self,Vector2(100+i*120,300),.65,float(i)*1.7,4.0,i>=3)
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(800,360);root.add_child(Flames.new());await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/player_colors_20261024/flame-palette.png");quit()
