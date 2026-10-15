extends SceneTree

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/licenses")
	var f=FileAccess.open("res://build/licenses/Godot-License.txt",FileAccess.WRITE)
	f.store_string(Engine.get_license_text())
	f=FileAccess.open("res://build/licenses/Godot-ThirdParty-Notices.txt",FileAccess.WRITE)
	f.store_string("Godot Engine bundled third-party copyright information\n\n")
	for item in Engine.get_copyright_info():
		f.store_string(str(item.name)+"\n")
		for part in item.parts:
			f.store_string("License: "+str(part.license)+"\n")
			for owner in part.copyright:f.store_string(str(owner)+"\n")
			f.store_string("\n")
	for license_name in Engine.get_license_info():
		f.store_string("\n"+str(license_name)+"\n"+str(Engine.get_license_info()[license_name])+"\n")
	quit()
