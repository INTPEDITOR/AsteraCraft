extends SceneTree
func _initialize():call_deferred("run")
func run():
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_maps.json"))
	var plan=JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_spacing_20261025.json"))
	var rows=[];var failures=[];var checks=0;var moved=0;var expansions=0
	for id in range(3):
		var map=ACMap.new();map.make(id)
		for node in source.maps[id].resources:
			if node.type!="tera":continue
			var live=map.resources.filter(func(n):return int(n.id)==int(node.id))[0]
			var declared=plan.maps[id].tera_overrides.filter(func(n):return int(n.id)==int(node.id))
			var delta=ACData.point(live.pos)-ACData.point(node.pos)
			checks+=1
			if delta!=Vector2.ZERO:
				moved+=1
				if declared.size()!=1 or int(declared[0].slot)<0 or ACData.point(declared[0].pos)!=ACData.point(live.pos):failures.append("undeclared tera move")
			var base=map.bases.filter(func(b):return node.id in b.resources)[0]
			if int(base.get("slot",-1))<0:
				expansions+=1;checks+=1
				if delta!=Vector2.ZERO:failures.append("expansion tera moved")
			rows.append({"map":id,"id":node.id,"source":node.pos,"runtime":live.pos,"delta":ACData.packed(delta),"declared_start_adjustment":not declared.is_empty()})
	checks+=2
	if moved!=0 or rows.size()!=36:failures.append("all original Tera positions must remain unchanged")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"tera":rows.size(),"moved_starts":moved,"expansions_checked":expansions,"rows":rows}
	DirAccess.make_dir_recursive_absolute("res://build/tera-source-comparison-20261025")
	FileAccess.open("res://build/tera-source-comparison-20261025/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("TERA_SOURCE_COMPARISON ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
