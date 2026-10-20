extends SceneTree
func _initialize():
	for theme in range(3):
		var c=ACCore.new();c.setup({"map":theme,"players":[{"race":0},{"race":1}]})
		c.units.clear();c.buildings.clear();c.map.resource_obstacles.clear();c.map.reset_solids([])
		var leaks=[]
		for y in range(1,127):
			for x in range(1,127):
				var p=Vector2(x,y)
				for delta in [Vector2.RIGHT,Vector2.DOWN]:
					var q=p+delta
					if c.map.height_map[y*128+x]==c.map.height_map[int(q.y)*128+int(q.x)]:continue
					if not c._ground_sweep(c.collision_size(0,0),p,q):continue
					var ramp=false
					for r in c.map.visual_ramps:
						if p.distance_to(r.center)<maxf(r.width,r.length)*.8+2:ramp=true;break
					if not ramp:leaks.append([x,y,delta.x,delta.y])
		print("CLIFF_PROBE ",theme," ",JSON.stringify(leaks))
	quit()
