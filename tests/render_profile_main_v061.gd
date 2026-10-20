extends "res://tests/menu_v04_harness.gd"
var draw_timings={}
func record_draw(key,begin):
	if not draw_timings.has(key):draw_timings[key]={"us":0,"calls":0,"max_us":0}
	var duration=Time.get_ticks_usec()-begin
	draw_timings[key].us+=duration;draw_timings[key].calls+=1;draw_timings[key].max_us=maxi(draw_timings[key].max_us,duration)
func _draw_world():
	var t=Time.get_ticks_usec();super._draw_world();record_draw("world",t)
func _draw_root_ground(v: Rect2):
	var t=Time.get_ticks_usec();super._draw_root_ground(v);record_draw("roots",t)
func _draw_unit(e: Dictionary):
	var t=Time.get_ticks_usec();super._draw_unit(e);record_draw("units",t)
func _render_minimap(canvas: CanvasItem):
	var t=Time.get_ticks_usec();super._render_minimap(canvas);record_draw("minimap",t)
func _draw_effect(e: Dictionary):
	var t=Time.get_ticks_usec();super._draw_effect(e);record_draw("effects",t)
