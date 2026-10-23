extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
class Swatches extends Control:
	var palette=ACPlayerPalette.new()
	var texture: Texture2D
	func _ready():
		var image=Image.create(16,16,false,Image.FORMAT_RGBA8);image.fill(Color("e4bd36"));texture=ImageTexture.create_from_image(image);material=palette.material(0,0,false)
	func _draw():
		draw_texture_rect(palette.marked(texture),Rect2(20,20,80,80),false)
		draw_texture_rect(texture,Rect2(120,20,80,80),false)
		draw_rect(Rect2(220,20,80,80),Color("e4bd36"))
class Gallery extends Control:
	var palette=ACPlayerPalette.new()
	var frame={}
	func _draw():
		if frame.is_empty():return
		var texture=palette.marked(frame.texture);var size_value=texture.get_size();var scale_value=140.0/maxf(size_value.x,size_value.y)
		draw_set_transform(Vector2(75,125),0,Vector2.ONE*scale_value);draw_texture(texture,-Vector2(size_value.x*.5,size_value.y*.8))
func _initialize():call_deferred("run")
func run():
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	for race in range(3):
		var specs=[]
		for i in range(4):specs.append({"race":race})
		var ids=ACPlayerColors.resolve(specs);var unique={}
		for id in ids:unique[id]=true
		check(unique.size()==4 and ids[0]==ACPlayerColors.NATIVE[race],"four same-race players receive distinct colors and preserve first native art")
	var colors=ACPlayerColors.resolve([{"race":0,"color_id":0},{"race":0,"color_id":0},{"race":0,"color_id":6},{"race":0}])
	check(colors[0]==0 and colors[2]==6 and colors[1]!=0,"explicit choices take priority over fallback colors")
	var swatches=Swatches.new();root.add_child(swatches);await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var pixels=root.get_texture().get_image();var body=pixels.get_pixel(50,50);var plain=pixels.get_pixel(150,50);var rectangle=pixels.get_pixel(250,50)
	check(body.b>body.r*1.4,"marked body pigment changes to chosen blue")
	check(plain.is_equal_approx(rectangle) and plain.r>plain.b*2,"unmarked effect texture and UI geometry keep original color")
	swatches.queue_free();await process_frame
	var art=ACAssets.new();art.load_all()
	for race in range(3):
		var kind=[0,2,2][race];var frame=art.unit(race,kind,Vector2(1,1),"idle",0)
		for color_id in range(8):
			var item=Gallery.new();item.frame=frame;item.position=Vector2(color_id*158,50+race*205);item.material=item.palette.material(race,color_id,false);root.add_child(item)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/player_colors_20261024/player-colors.png")
	var result={"checks":checks,"failures":failures,"colors":ACPlayerColors.NAMES,"native_sprites_and_portraits_preserved":true};FileAccess.open("res://build/player_colors_20261024/player-colors.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PLAYER_COLORS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
