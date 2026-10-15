const fs=require('fs');let p='scripts/main.gd',s=fs.readFileSync(p,'utf8');s=s.replace('func _draw_world() -> void:',`var root_tile_cache: Dictionary={}
var root_tile_signature := ""

func _draw_root_ground(view: Rect2) -> void:
	var sources: Array=[]
	for building in state.get("buildings",[]):
		if int(building.race)==1 and int(building.kind) in [0,12] and building.hp>0 and building.progress>=1:sources.append(building)
	var signature=str(sources.map(func(b):return [b.id,b.pos,b.owner]))+str(draw_map.theme)
	if signature!=root_tile_signature:
		root_tile_signature=signature;root_tile_cache.clear()
		for source in sources:
			var origin=_center(source)
			for y in range(maxi(0,int(origin.y)-13),mini(128,int(origin.y)+14)):
				for x in range(maxi(0,int(origin.x)-13),mini(128,int(origin.x)+14)):
					if draw_map.terrain[y*128+x]!=0 or origin.distance_squared_to(Vector2(x,y))>169:continue
					root_tile_cache[Vector2i(x,y)]=int(source.owner)
	for tile in root_tile_cache:
		if _fog_value(tile.y*128+tile.x)==0:continue
		var pos=Vector2(tile)
		var point=_ground_point(pos)
		if not view.grow(40*zoom).has_point(point):continue
		var shade=.75 if _fog_value(tile.y*128+tile.x)==1 else 1.0
		var polygon=PackedVector2Array()
		for offset in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:polygon.append(_ground_point(pos+offset))
		world_canvas.draw_colored_polygon(polygon,Color(.24*shade,.12*shade,.16*shade,.58))
		var bend=Vector2(.12*sin(tile.x*17+tile.y*7),.16*cos(tile.y*11))
		var vein=PackedVector2Array([_ground_point(pos+Vector2(-.5,0)),_ground_point(pos+bend),_ground_point(pos+Vector2(.5,0))])
		world_canvas.draw_polyline(vein,Color(.47*shade,.24*shade,.12*shade,.65),maxf(1,1.7*zoom),true)
		world_canvas.draw_line(_ground_point(pos+bend),_ground_point(pos+Vector2(0,.5)),Color(.34*shade,.21*shade,.14*shade,.7),maxf(1,zoom),true)
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if root_tile_cache.has(tile+direction):continue
			var edge=Vector2(direction)*.5
			var tangent=Vector2(-direction.y,direction.x)*.5
			world_canvas.draw_line(_ground_point(pos+edge-tangent),_ground_point(pos+edge+tangent),Color(.65,.34,.17,.8),maxf(1,1.5*zoom),true)

func _draw_world() -> void:`);s=s.replace('\tfor res in state.get("resources",[]):\n','\t_draw_root_ground(view)\n\tfor res in state.get("resources",[]):\n');fs.writeFileSync(p,s);
p='scripts/rts_hud.gd';s=fs.readFileSync(p,'utf8');s=s.replace('else:lines.append("배양체  %d"%int(_unit.get("larva",0)))','else:lines.append("연결 배양체  %d"%int(_unit.get("larva",0)))\n\t\t\tif int(_unit.kind)==3:lines.append("군체모수 연동 · 12칸" if _unit.get("brood_active",false) else "비활성 · 군체모수 연결 없음")');s=s.replace('var reasons: Array[String]=[]','var reasons: Array[String]=[]\n\t\tif race==1 and int(_unit.get("kind",-1))==3 and _unit.has("progress") and not _unit.get("brood_active",false):reasons.append("군체모수 연결 필요")');fs.writeFileSync(p,s);
p='data/game.json';const d=JSON.parse(fs.readFileSync(p));d.buildings[1][0].description='연결된 추가배양낭의 배양체 생산·집결·취소 통합 관리 · 13칸 뿌리 지대';d.buildings[1][3].description='군체모수 중심 12칸 이내 연동 · 연결 소실 시 생성·변태 중단';d.buildings[1][12].description='13칸 뿌리 지대 확장 · 기존 뿌리 위에 건설';fs.writeFileSync(p,JSON.stringify(d,null,2)+'\n');
