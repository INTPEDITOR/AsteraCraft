extends SceneTree

const OUT="E:/Codex/ASTERACRAFT/outputs/faction-trees-20261020-bright-v2"
const PAGE=Vector2i(3200,3440)
const Assets=preload("res://scripts/assets.gd")
var art
var report=[]

class Poster extends Control:
	var race=0
	var art
	var font: Font
	var title_font: Font
	var backdrop: Texture2D
	var positions={}
	var nodes=[]
	var edges=[]
	var branches={}
	var primary={}
	var units_seen=[]
	var accent: Color
	var ink=Color("243141")
	var muted=Color("586777")
	var gold=Color("88672d")
	var planned=Color("70528e")
	var panels=[Color("fffdf7"),Color("fffdf5"),Color("fcfdff")]
	var unit_roles=[
		["채굴 · 건설 · 수리","범용 지상·대공 보병","고속 근접 돌격","정면 방어 전열","바이오닉 치료","장거리 광역 포격","기동 미사일 화력","은폐 · 정밀 사격","정찰 · 은폐 탐지","공중 전용 요격","지상 광역 폭격","병력 수송","대형 지상 중병기"],
		["채굴 · 건물 변태","고속 근접 · 한 번에 2마리","근거리 과즙 사격","중장갑 근접 전열","접근 자폭","덩굴 · 이동 방해","장거리 씨앗 포격","대공 중심 가시 사격","은폐 · 정신 조종","회복 · 은폐 탐지","고속 비행 사격","병력 수송","대형 군체 거점","개별 유닛으로 변태"],
		["채굴 · 건설 개시","보호막 근접 전열","원거리 광선 사격","감속 · 구속 지원","보호막 지원","예고 광역 주문","정찰 · 은폐 탐지","근거리 광역 병기","장거리 관통 포격","공중 전용 요격","영구 은폐 근접","병력 수송","대형 공중 주력함"]
	]
	func _init(which,source):
		race=which;art=source
		var source_font=load("res://assets/fonts/NotoSansKR-VF.ttf")
		font=FontVariation.new();font.base_font=source_font;font.variation_opentype={2003265652:520.0}
		title_font=FontVariation.new();title_font.base_font=source_font;title_font.variation_opentype={2003265652:730.0}
		accent=[Color("906315"),Color("a45215"),Color("32628c")][race]
		backdrop=ImageTexture.create_from_image(Image.load_from_file(OUT+"/backgrounds/"+["rock","citrus","owl"][race]+".png"))
		prepare_nodes()
	func tx(at: Vector2, value: String, px: int=30, color: Color=Color("243141"), width: float=-1):
		draw_string(title_font if px>=31 else font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,px,color)
	func box(rect: Rect2,fill: Color,border: Color,radius: int=18):
		var style=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border
		style.set_border_width_all(2);style.set_corner_radius_all(radius)
		style.shadow_color=Color(.13,.16,.19,.07);style.shadow_size=9;style.shadow_offset=Vector2(0,5)
		draw_style_box(style,rect)
	func line(points: PackedVector2Array,color: Color,width: float=3):
		draw_polyline(points,color,width,true)
	func arrow(points: PackedVector2Array,color: Color,width: float=3):
		line(points,color,width)
		var tip=points[-1];var direction=(tip-points[-2]).normalized();var normal=Vector2(-direction.y,direction.x)
		draw_colored_polygon(PackedVector2Array([tip,tip-direction*14+normal*7,tip-direction*14-normal*7]),color)
	func fit_texture(texture: Texture2D,rect: Rect2,flip: bool=false,rotation: float=0):
		if texture==null:return
		var ratio=minf(rect.size.x/texture.get_width(),rect.size.y/texture.get_height())
		var extent=texture.get_size()*ratio;var dest=Rect2(rect.get_center()-extent*.5,extent)
		if flip:dest.position.x+=dest.size.x;dest.size.x=-dest.size.x
		if absf(rotation)>.001:
			draw_set_transform(rect.get_center(),rotation)
			dest.position-=rect.get_center()
			draw_texture_rect(texture,dest,false)
			draw_set_transform(Vector2.ZERO)
		else:draw_texture_rect(texture,dest,false)
	func unit_icon(kind: int,rect: Rect2):
		var frame=art.unit(race,kind,Vector2(1,1))
		fit_texture(frame.get("texture"),rect,bool(frame.get("flip",false)),float(frame.get("rotation",0)))
	func prepare_nodes():
		var definitions=ACData.get_data().buildings[race]
		var tiers={}
		for definition in definitions:
			var level=depth(int(definition.id),definitions)
			if not tiers.has(level):tiers[level]=[]
			tiers[level].append(int(definition.id))
			if not definition.requires.is_empty():
				var selected=int(definition.requires[0])
				for requirement in definition.requires:
					if depth(int(requirement),definitions)>=depth(selected,definitions):selected=int(requirement)
				primary[int(definition.id)]=selected
				if not branches.has(selected):branches[selected]=[]
				branches[selected].append(int(definition.id))
		for level in tiers:
			var ids: Array=tiers[level];var gap=36.0;var w=470.0
			var start=(3200-(ids.size()*w+(ids.size()-1)*gap))*.5
			for index in range(ids.size()):
				var kind=int(ids[index]);positions[kind]=Rect2(start+index*(w+gap),415+int(level)*224,w,164)
				nodes.append({"id":kind,"name":definitions[kind].name,"requires":definitions[kind].requires,"level":level})
		for definition in definitions:
			for prerequisite in definition.requires:edges.append({"from":int(prerequisite),"to":int(definition.id)})
		# A tidy tree reserves a separate horizontal interval for each branch.
		# Additional AND prerequisites remain explicitly listed on each card.
		var leaves=[]
		for definition in definitions:
			if definition.requires.is_empty() and branches.has(int(definition.id)):collect_leaves(int(definition.id),leaves)
		var centers={}
		var step=506.0
		for index in range(leaves.size()):centers[int(leaves[index])]=1600+(index-(leaves.size()-1)*.5)*step
		for definition in definitions:
			var kind=int(definition.id)
			if definition.requires.is_empty():continue
			var center=branch_center(kind,centers)
			positions[kind].position.x=center-positions[kind].size.x*.5
	func collect_leaves(kind: int,leaves: Array):
		if not branches.has(kind):leaves.append(kind);return
		for child in branches[kind]:collect_leaves(int(child),leaves)
	func branch_center(kind: int,centers: Dictionary) -> float:
		if centers.has(kind):return float(centers[kind])
		var children: Array=branches[kind]
		var first=branch_center(int(children[0]),centers)
		var last=branch_center(int(children[-1]),centers)
		centers[kind]=(first+last)*.5
		return float(centers[kind])
	func depth(kind: int,definitions: Array) -> int:
		var value=0
		for requirement in definitions[kind].requires:value=maxi(value,depth(int(requirement),definitions)+1)
		return value
	func _draw():
		draw_texture_rect(backdrop,Rect2(Vector2.ZERO,Vector2(PAGE)),false)
		draw_rect(Rect2(Vector2.ZERO,Vector2(PAGE)),Color(1,1,1,.18))
		box(Rect2(62,40,2280,214),Color(1,1,1,.90),Color(1,1,1,.70),20)
		box(Rect2(70,266,3060,69),Color(1,1,1,.94),Color(accent,.12),13)
		box(Rect2(70,350,3060,1170),Color(1,1,1,.63),Color(1,1,1,.3),22)
		box(Rect2(70,1668,3060,71),Color(1,1,1,.94),Color(accent,.12),13)
		draw_rect(Rect2(0,0,3200,10),accent)
		tx(Vector2(90,87),"ASTERACRAFT  /  FACTION TECH TREE",26,accent)
		tx(Vector2(88,181),str(ACData.get_data().race_names[race]),76,ink)
		tx(Vector2(94,238),"건물 · 생산 · 해금 관계도",34,muted)
		box(Rect2(2440,78,665,154),panels[race],accent)
		tx(Vector2(2470,126),"현재 v0.5.10 데이터 기준",30,ink)
		tx(Vector2(2470,180),"건물 13종  ·  "+("유닛 13종 + 배양체" if race==1 else "유닛 13종"),29,muted)
		arrow(PackedVector2Array([Vector2(95,300),Vector2(190,300)]),gold)
		tx(Vector2(208,309),"대표 선행 건물 · 공통 분기선",26,gold)
		box(Rect2(780,281,26,26),Color("f5f8fa"),accent,4)
		tx(Vector2(824,309),"생산 / 배양체 변태",26,accent)
		draw_dashed_line(Vector2(1310,300),Vector2(1410,300),planned,3,12)
		tx(Vector2(1430,309),"다음 업데이트 계획 · 미적용",26,planned)
		tx(Vector2(2290,309),"전체 필수 조건은 카드에 표시",26,muted)
		tx(Vector2(90,380),"01  건물 건설 순서",37,ink)
		for parent in branches:
			var children: Array=branches[parent]
			var a: Rect2=positions[parent]
			var begin=Vector2(a.get_center().x,a.end.y)
			var middle=begin.y+31
			var first: Rect2=positions[int(children[0])];var last: Rect2=positions[int(children[-1])]
			var low=minf(begin.x,first.get_center().x);var high=maxf(begin.x,last.get_center().x)
			var stroke=Color(gold,.88)
			draw_line(begin,Vector2(begin.x,middle),stroke,4,true)
			draw_line(Vector2(low,middle),Vector2(high,middle),stroke,4,true)
			for child in children:
				var b: Rect2=positions[int(child)]
				var x=b.get_center().x
				arrow(PackedVector2Array([Vector2(x,middle),Vector2(x,b.position.y-4)]),stroke,4)
			if children.size()>1:draw_circle(Vector2(begin.x,middle),5,stroke)
		for kind in positions:building_card(int(kind),positions[kind])
		box(Rect2(90,1550,3020,100),Color(1,1,1,.96),Color(accent,.22),12)
		var note=["정비공이 건설  ·  테라 정제소는 완성 본진 14칸 이내  ·  기술 건물은 해금 조건이며 실제 생산소와 다릅니다.","일귤이 건물로 변태  ·  군체모수/추가배양낭이 배양체 생성  ·  아래 진화 건물은 생산소가 아니라 해금 조건입니다.","축조자가 건설 개시  ·  본진/규율탑/테라 외 건물은 규율탑 영향권 필요  ·  테라는 본진 14칸 이내입니다."][race]
		tx(Vector2(120,1590),note,27,ink)
		tx(Vector2(120,1628),"선은 대표 선행 관계만 표시합니다. 카드의 복수 필수 조건은 모두 충족해야 하며, 건설 범위·자원·인구는 별도 적용됩니다.",25,muted)
		tx(Vector2(90,1716),"02  "+("배양체 변태 · 진화 건물별 해금 유닛" if race==1 else "생산 건물 · 유닛 · 추가 해금 조건"),37,ink)
		if race==1:citrus_groups()
		else:normal_groups()
		planned_section()
		box(Rect2(70,3333,3060,102),Color(1,1,1,.94),Color(1,1,1,.5),12)
		tx(Vector2(94,3375),"현재 게임 데이터 · 실제 스프라이트 기준    |    종족별 배경 일러스트    |    2026.10.20",25,muted)
		tx(Vector2(94,3415),"실선 영역은 현재 구조입니다. 연구·능력 연결은 하단의 계획 영역에만 표시했습니다.",24,muted)
	func building_card(kind: int,rect: Rect2):
		var d=ACData.building(race,kind)
		box(rect,panels[race],Color(accent,.38))
		fit_texture(art.building(race,kind),Rect2(rect.position+Vector2(14,24),Vector2(115,115)))
		tx(rect.position+Vector2(146,34),"B%02d"%kind,22,accent)
		tx(rect.position+Vector2(146,79),str(d.name),31,ink,rect.size.x-153)
		var requirement="선행 없음" if d.requires.is_empty() else "필수 "+" + ".join(d.requires.map(func(id):return "B%02d"%int(id)))
		tx(rect.position+Vector2(146,117),requirement,24,gold)
		var descriptions=[
			["일꾼 · 자원 반납","테라 추출","인구 한도 +8","보병 생산","기갑 차량 생산","항공 유닛 생산","공격 · 장갑 연구","의무병 해금","정찰병 해금","전차 해금","요새 · 폭격기 해금","지상 방어","대공 · 은폐 탐지"],
			["배양체 생성 · 통합 관리","테라 추출","인구 한도 +8","배양체 생성 · 본진 연동","근접 개체 해금","원거리 개체 · 연구","중장갑 개체 해금","비행 개체 해금","지원 · 침투 해금","대과수 해금","지상 방어","대공 · 은폐 탐지","뿌리 지대 확장"],
			["일꾼 · 자원 반납","테라 추출","인구 · 건설 영향권","보병 생산","지상 병기 생산","비행 유닛 생산","공격 · 장갑 · 보호막 연구","정예 · 마법 해금","은폐 전사 해금","대심판선 해금","비전투 체력 회복","지상 방어","대공 · 은폐 탐지"]
		]
		tx(rect.position+Vector2(146,149),descriptions[race][kind],22,muted)
	func unit_card(kind: int,rect: Rect2,condition: String=""):
		units_seen.append(kind)
		var d=ACData.unit(race,kind)
		box(rect,Color("f8fafb"),Color("d4dde4"),12)
		unit_icon(kind,Rect2(rect.position+Vector2(10,10),Vector2(94,104)))
		tx(rect.position+Vector2(120,40),str(d.name),31,ink,rect.size.x-125)
		tx(rect.position+Vector2(120,76),unit_roles[race][kind],23,muted,rect.size.x-125)
		if condition=="":condition="추가 조건 없음" if d.requires.is_empty() else "필수 "+" + ".join(d.requires.map(func(id):return str(ACData.building(race,int(id)).name)))
		tx(rect.position+Vector2(120,109),condition,22,gold,rect.size.x-125)
	func group_header(rect: Rect2,kind: int,subtitle: String):
		box(rect,Color(1,1,1,.97),Color(accent,.32))
		fit_texture(art.building(race,kind),Rect2(rect.position+Vector2(22,12),Vector2(96,78)))
		tx(rect.position+Vector2(137,48),"B%02d  %s"%[kind,ACData.building(race,kind).name],33,accent)
		tx(rect.position+Vector2(137,85),subtitle,24,muted)
		draw_line(rect.position+Vector2(24,105),rect.position+Vector2(rect.size.x-24,105),Color(accent,.25),2)
	func normal_groups():
		var producers=[0,3,4,5]
		for i in range(4):
			var producer=int(producers[i]);var rect=Rect2(90+(i%2)*1535,1760+int(i/2)*538,1485,512)
			group_header(rect,producer,"이 건물에서 실제 생산 · 각 유닛 아래에 추가 해금 조건 표시")
			var list=range(13).filter(func(kind):return int(ACData.unit(race,kind).producer)==producer)
			for j in range(list.size()):
				var item=Rect2(rect.position+Vector2(22+(j%2)*724,125+int(j/2)*125),Vector2(708,120))
				unit_card(int(list[j]),item)
	func citrus_groups():
		var groups=[{"b":0,"us":[13,0],"sub":"생산 원천 · 군체모수/연결 추가배양낭"},{"b":4,"us":[1,4],"sub":"기초 근접 · 돌파 개체 해금"},{"b":5,"us":[2,7,6],"sub":"원거리 개체 해금 · 공격/장갑 연구"},{"b":6,"us":[3,5],"sub":"중장갑 · 구속 개체 해금"},{"b":7,"us":[10,11],"sub":"비행 개체 해금"},{"b":8,"us":[8,9],"sub":"침투 · 회복/탐지 개체 해금"},{"b":9,"us":[12],"sub":"최상위 개체 해금"}]
		for i in range(groups.size()):
			var group=groups[i];var rect=Rect2(90+(i%4)*765,1760+int(i/4)*538,725,512)
			group_header(rect,int(group.b),str(group.sub))
			for j in range(group.us.size()):
				var kind=int(group.us[j]);var condition=""
				if kind==13:condition="실제 변태 주체 · 1개체씩 독립 변태"
				elif kind==0:condition="배양체에서 변태 · 추가 조건 없음"
				unit_card(kind,Rect2(rect.position+Vector2(16,125+j*125),Vector2(693,120)),condition)
		var note=Rect2(90+3*765,1760+538,725,512)
		box(note,Color("fff8e8"),Color(accent,.38))
		tx(note.position+Vector2(28,57),"귤 생산 구조 읽는 법",32,accent)
		var lines=["군체모수 + 12칸 이내 추가배양낭","↓ 배양체 생성 / 본진 연동","배양체 → 해금된 유닛으로 변태","씨앗박격체는 과즙분비샘 +","후피진화소가 모두 필요합니다.","뿌리중계체는 뿌리를 확장하며","배양체를 생성하지 않습니다."]
		for j in range(lines.size()):tx(note.position+Vector2(28,122+j*47),lines[j],28,ink)
	func planned_section():
		var area=Rect2(90,2870,3020,430)
		box(area,Color("f7f3fb"),Color(planned,.38))
		draw_dashed_line(Vector2(112,2870),Vector2(3088,2870),planned,3,14)
		tx(Vector2(123,2925),"03  다음 업데이트 · 연구 연결 초안",35,planned)
		tx(Vector2(123,2968),"현재 미적용 / 최종 연구 건물·비용·수치는 밸런스 검토 후 확정",25,muted)
		var details=[
			[["야전의료소","의무병: 전투자극주사 · 차폐연막","기본 자동 치료 유지"],["전술정보국","고가 핵미사일 생산 · 정찰병 유도","핵 탄약과 연구 해금 필요"],["탄도시험장 · 중병기설계국","전차 과충전 포격 · 요새 비상 정비","기본 태세 + 연구 추가 기술"]],
			[["군체모수 · 추가배양낭","연결 배양체 전체 선택","본진 공유 대기열 제한 제거"],["군체신경핵 · 지원 연구","정신 조종 · 회복/교란 기술 해금","마나/과육을 모아 능력 사용"],["후피진화소 · 원시과수핵","대형 개체의 추가 능력 연구","외피 강화 · 뿌리 쇄도 등"]],
			[["복원성당 · 지원 연구","결계사제 자동 체력 치료","보호 문장 · 정화는 추가 연구"],["천문관측소 · 황혼기록원","고위 마법 · 통제 기술 해금","기본 1개 능력 + 연구 능력"],["석익조형소 · 대심판성소","대형 병기 추가 능력 연구","충격파 · 관통탄 · 천공의 판결"]]
		][race]
		for i in range(3):
			var origin=Vector2(122+i*990,3002)
			box(Rect2(origin,Vector2(960,165)),Color("ffffff"),Color(planned,.25),12)
			tx(origin+Vector2(24,42),details[i][0],30,planned)
			tx(origin+Vector2(24,87),details[i][1],28,ink)
			tx(origin+Vector2(24,130),details[i][2],25,muted)
		tx(Vector2(125,3233),"공통 계획  모든 연구 건물 대기열·개별 취소  /  고위력 능력 연구 해금  /  소량의 마나·에너지로 생성 후 충전",27,ink)

func _initialize():call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute(OUT)
	art=Assets.new();art.load_all()
	for race in range(3):
		var viewport=SubViewport.new();viewport.size=PAGE;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var poster=Poster.new(race,art);poster.size=Vector2(PAGE);viewport.add_child(poster)
		for frame in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var name=["01-rock-hyrax","02-citrus","03-owl"][race]
		var file=OUT+"/"+name+"-tech-tree.png"
		var error=viewport.get_texture().get_image().save_png(file)
		var expected=14 if race==1 else 13
		var distinct={}
		for id in poster.units_seen:distinct[int(id)]=true
		assert(error==OK and poster.nodes.size()==13 and distinct.size()==expected)
		report.append({"race":race,"name":ACData.get_data().race_names[race],"image":file,"size":[PAGE.x,PAGE.y],"buildings":poster.nodes,"prerequisite_edges":poster.edges,"drawn_primary_parents":poster.primary,"units":distinct.keys()})
		print("FACTION_TREE ",file," buildings=13 units=",distinct.size()," edges=",poster.edges.size())
		poster.queue_free();viewport.queue_free();await process_frame
	var data=FileAccess.open(OUT+"/chart-data.json",FileAccess.WRITE);data.store_string(JSON.stringify({"version":"0.5.10","date":"2026-10-20","races":report},"  "))
	print("FACTION_TREES_COMPLETE")
	quit()
