extends "res://tests/view_input_v03_test.gd"
const UPDATER=preload("res://scripts/game_updater.gd")
const OUT="res://build/updater-test-20261024/"
class Controller:
	extends Control
	var page="main"
	var service: Node
	var settings={"last_played_race":0}
	var menu_backdrop: Texture2D
	var audio=null
	func _game_updater() -> Node:return service
	func _single_menu() -> void:pass
	func _online_menu() -> void:pass
	func _settings_menu() -> void:pass
func release(tag: String,date: String="2026-10-24T05:00:00Z") -> Dictionary:
	var name="AsteraCraft-Windows-"+tag+".zip"
	return {"draft":false,"tag_name":tag,"published_at":date,"assets":[{"name":name,"state":"uploaded","size":3,"digest":"sha256:"+"a".repeat(64),"browser_download_url":"https://github.com/INTPEDITOR/AsteraCraft/releases/download/"+tag+"/"+name}]}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var local={"tag":"installed","built_at_unix":1}
	var valid=release("new-version")
	check(UPDATER.choose_release([valid],local).tag=="new-version","verified official release selected")
	check(UPDATER.choose_release([valid],{"tag":"new-version","built_at_unix":1}).is_empty(),"same tag never updates itself")
	check(UPDATER.choose_release([valid],{"tag":"old","built_at_unix":9999999999}).is_empty(),"older release never replaces newer build")
	for failure in ["draft","path","host","digest","size","duplicate-name"]:
		var bad=valid.duplicate(true)
		match failure:
			"draft":bad.draft=true
			"path":bad.tag_name="../escape"
			"host":bad.assets[0].browser_download_url="https://example.com/file.zip"
			"digest":bad.assets[0].digest=""
			"size":bad.assets[0].size=0
			"duplicate-name":bad.assets[0].name="other.exe"
		check(UPDATER.choose_release([bad],local).is_empty(),"reject invalid release "+failure)
	check(UPDATER.choose_release([valid,release("newest","2026-10-25T05:00:00Z")],local).tag=="newest","newest valid publication selected")
	var controller=Controller.new();controller.theme=Theme.new();controller.theme.default_font=ACUIFont.create();root.add_child(controller);controller.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var service=UPDATER.new();root.add_child(service);service.controller=controller;service.metadata=local;service.install_enabled=true;controller.service=service
	service.record={"tag":"new-version","phase":"failed"}
	service._feed_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify([valid]).to_utf8_buffer())
	check(service.state=="failed" and service.request==null,"previous failed tag does not auto-download")
	service.checked=true
	for repeat in range(10):service.check_updates();service._process(.1)
	check(service.request==null and service.state=="failed","repeated process/menu checks cannot form retry loop")
	controller.page="game";service.state="ready";service._launch_installer()
	check(service.state=="ready","match in progress cannot trigger installer or quit")
	var state_path="user://updates/state.json";var existed=FileAccess.file_exists(state_path);var saved=FileAccess.get_file_as_string(state_path) if existed else ""
	DirAccess.make_dir_recursive_absolute("user://updates")
	var bytes=PackedByteArray([1,2,3]);var path="user://updates/test-digest.zip.part";var file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
	service.download_path=path;service.target={"tag":"new-version","bytes":3,"sha256":FileAccess.get_sha256(path)};service.auto_apply=true
	service._download_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),PackedByteArray())
	for tick in range(120):
		await process_frame
		if service.state!="verifying":break
	check(service.state=="ready","verified download waits safely while a match is active")
	service.target.sha256="0".repeat(64);service._download_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),PackedByteArray())
	for tick in range(120):
		await process_frame
		if service.state!="verifying":break
	check(service.state=="failed" and service.record.phase=="failed","bad digest persists a terminal failure")
	for repeat in range(20):service._process(.1)
	check(service.state=="failed" and service.request==null,"digest failure does not restart download")
	if existed:FileAccess.open(state_path,FileAccess.WRITE).store_string(saved)
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path(state_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	controller.page="main";service.target=UPDATER.choose_release([valid],local);service.state="available";service.message="새 업데이트가 있습니다. 업데이트 후 게임을 다시 시작합니다."
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	var menu=ACHubMenu.new();controller.add_child(menu);menu.configure(controller);await frames(3)
	for mode in ["available","downloading","failed","ready"]:
		service.state=mode;service.progress=.55;service.message={"available":"새 업데이트가 있습니다.","downloading":"업데이트 다운로드 중… 55%","failed":"이 버전의 업데이트에 실패했습니다. 자동으로 재시도하지 않습니다.","ready":"업데이트 준비가 끝났습니다."}[mode];service.changed.emit();await frames(2)
		check(Rect2(Vector2.ZERO,menu.size).encloses(menu.update_panel.get_rect()),"update panel safely inside viewport "+mode)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"menu-update-"+mode+".png")
	var result={"checks":checks,"failures":failures,"automatic_attempts_per_process":1,"failed_tag_requires_manual_retry":true,"ordinary_match_can_continue":true}
	FileAccess.open(OUT+"controller-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("UPDATER_CONTROLLER ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
