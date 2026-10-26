extends Node
## One request per launch; downloads and installs require a menu action.
signal changed
const FEED="https://api.github.com/repos/INTPEDITOR/AsteraCraft/releases?per_page=30"
const META="res://data/update_channel.json"
const ROOT="user://updates/"
const CHECK_TIMEOUT_MSEC=25000
var controller: Node
var metadata: Dictionary={}
var target: Dictionary={}
var record: Dictionary={}
var state="idle"
var message="업데이트 확인"
var progress=0.0
var install_enabled=false
var request: HTTPRequest
var verifier: Thread
var download_path=""
var last_check=-100000
var checked=false
var auto_apply=false
var _auto_check_pending=false
var _check_deadline_msec=-1
var _request_serial=0

static func confirm_booted() -> void:
	if OS.has_feature("editor") or not FileAccess.file_exists(ROOT+"state.json"):return
	var pending=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"state.json"))
	var current=JSON.parse_string(FileAccess.get_file_as_string(META))
	if pending is Dictionary and current is Dictionary and pending.get("phase","")=="installing" and pending.get("tag","")==current.get("tag",""):
		pending.phase="confirmed"
		FileAccess.open(ROOT+"state.json",FileAccess.WRITE).store_string(JSON.stringify(pending))

func configure(owner: Node) -> void:
	controller=owner
	metadata=JSON.parse_string(FileAccess.get_file_as_string(META))
	install_enabled=OS.get_name()=="Windows" and not OS.has_feature("editor")
	if FileAccess.file_exists(ROOT+"state.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"state.json"))
		if saved is Dictionary:record=saved
	if record.get("phase","") in ["downloading","installing","installed"] and record.get("tag","")!=metadata.get("tag",""):
		record.phase="failed";_save_record()
	# The title prepares Main while disabled and reparents it on entry. A live
	# HTTPRequest would be silently cancelled by that subtree's EXIT_TREE.
	_auto_check_pending=install_enabled and "--smoke-game" not in OS.get_cmdline_user_args()
	set_process(true)

static func choose_release(releases: Array,local: Dictionary) -> Dictionary:
	var best: Dictionary={};var newest=float(local.get("built_at_unix",0))
	var tag_pattern=RegEx.new();tag_pattern.compile("^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$")
	var digest_pattern=RegEx.new();digest_pattern.compile("^sha256:[a-fA-F0-9]{64}$")
	for release in releases:
		if not release is Dictionary or release.get("draft",true):continue
		var tag=str(release.get("tag_name",""))
		if tag==str(local.get("tag","")) or tag_pattern.search(tag)==null:continue
		var date=str(release.get("published_at",""))
		if date.length()!=20 or not date.ends_with("Z"):continue
		var published=float(Time.get_unix_time_from_datetime_string(date.trim_suffix("Z")))
		if published<=newest:continue
		var assets=release.get("assets",[])
		if not assets is Array:continue
		for asset in assets:
			if not asset is Dictionary:continue
			var name="AsteraCraft-Windows-"+tag+".zip"
			var url=str(asset.get("browser_download_url",""));var digest=str(asset.get("digest",""))
			if str(asset.get("name",""))!=name or str(asset.get("state",""))!="uploaded":continue
			if url!="https://github.com/INTPEDITOR/AsteraCraft/releases/download/"+tag+"/"+name:continue
			if digest_pattern.search(digest)==null or int(asset.get("size",0))<=0 or int(asset.size)>4294967296:continue
			best={"tag":tag,"url":url,"sha256":digest.trim_prefix("sha256:").to_lower(),"bytes":int(asset.size)};newest=published
	return best

func check_updates(manual: bool=false) -> void:
	if not install_enabled or state in ["checking","downloading","verifying","installing"]:return
	if is_instance_valid(controller) and not controller.can_process():return
	if not manual and checked:return
	if Time.get_ticks_msec()-last_check<10000:return
	_auto_check_pending=false
	checked=true;last_check=Time.get_ticks_msec();state="checking";message="새 버전 확인 중…";changed.emit()
	_check_deadline_msec=last_check+CHECK_TIMEOUT_MSEC
	_request_serial+=1
	request=HTTPRequest.new();request.timeout=20;request.max_redirects=5;add_child(request)
	request.request_completed.connect(_feed_response.bind(_request_serial))
	print("UPDATE_CHECK started local=",metadata.get("tag",""))
	if request.request(_feed_url(),PackedStringArray(["Accept: application/vnd.github+json","User-Agent: AsteraCraft-Updater"]))!=OK:_fail("업데이트를 확인하지 못했습니다. 현재 버전으로 플레이할 수 있습니다.")

func _feed_url() -> String:
	return FEED

func _feed_response(result: int,code: int,headers: PackedStringArray,body: PackedByteArray,serial: int) -> void:
	if serial!=_request_serial or state!="checking":return
	_feed_complete(result,code,headers,body)

func _feed_complete(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	_release_request()
	print("UPDATE_CHECK completed result=",result," http=",code)
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:_fail("업데이트를 확인하지 못했습니다. 현재 버전으로 플레이할 수 있습니다.");return
	var releases=JSON.parse_string(body.get_string_from_utf8())
	if not releases is Array:_fail("업데이트 정보를 읽지 못했습니다.");return
	target=choose_release(releases,metadata)
	if target.is_empty():state="current";message="최신 버전입니다.";changed.emit();return
	if record.get("tag","")==target.tag and record.get("phase","")=="failed":
		state="failed";message="이 버전의 업데이트에 실패했습니다. 자동으로 재시도하지 않습니다."
	else:state="available";message="새 버전이 있습니다: "+str(target.tag)
	changed.emit()

func activate() -> void:
	if state in ["available","failed"] and not target.is_empty():begin_download()
	elif state=="ready":_launch_installer()
	elif state not in ["checking","downloading","verifying","installing"]:check_updates(true)

func begin_download() -> void:
	if not install_enabled or target.is_empty() or state in ["downloading","verifying","installing"]:return
	DirAccess.make_dir_recursive_absolute(ROOT)
	download_path=ROOT+str(target.tag)+".zip.part"
	record={"tag":target.tag,"phase":"downloading"}
	if not _save_record():_fail("업데이트 상태를 저장하지 못했습니다.");return
	state="downloading";progress=0;message="업데이트 다운로드 중…";auto_apply=true;changed.emit()
	request=HTTPRequest.new();request.timeout=1800;request.max_redirects=5;request.download_file=download_path;add_child(request)
	request.request_completed.connect(_download_complete)
	if request.request(str(target.url),PackedStringArray(["User-Agent: AsteraCraft-Updater"]))!=OK:_fail("다운로드를 시작하지 못했습니다.")

func _process(_delta: float) -> void:
	if _auto_check_pending and is_instance_valid(controller) and controller.can_process():
		_auto_check_pending=false
		check_updates()
	# Also bound wall-clock waiting when the HTTP timeout callback is lost or
	# delayed by a scene transition. Failure never schedules an automatic retry.
	if state=="checking" and _check_deadline_msec>=0 and Time.get_ticks_msec()>=_check_deadline_msec:
		print("UPDATE_CHECK timed_out")
		_fail("업데이트 확인 시간이 초과되었습니다. 현재 버전으로 플레이하거나 다시 확인할 수 있습니다.")
	if state=="downloading" and request!=null:
		progress=clampf(float(request.get_downloaded_bytes())/maxf(1,float(target.get("bytes",1))),0,1)
		changed.emit()
	if state=="verifying" and verifier!=null and not verifier.is_alive():
		var digest=verifier.wait_to_finish();verifier=null
		if str(digest)!=str(target.sha256):_fail("다운로드한 파일을 확인하지 못했습니다. 기존 게임은 유지됩니다.");return
		state="ready";progress=1;message="업데이트 준비가 끝났습니다.";changed.emit()
		if auto_apply and controller!=null and controller.get("page")=="main":_launch_installer()

func _download_complete(result: int,code: int,_headers: PackedStringArray,_body: PackedByteArray) -> void:
	_release_request()
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:_fail("다운로드에 실패했습니다. 자동으로 재시도하지 않습니다.");return
	var file=FileAccess.open(download_path,FileAccess.READ)
	if file==null or file.get_length()!=int(target.bytes):_fail("다운로드한 파일 크기가 올바르지 않습니다.");return
	file.close();state="verifying";message="다운로드한 파일 확인 중…";changed.emit()
	var path=download_path
	verifier=Thread.new()
	if verifier.start(func():return FileAccess.get_sha256(path))!=OK:verifier=null;_fail("파일 확인을 시작하지 못했습니다.")

func _launch_installer() -> void:
	if not install_enabled or state!="ready" or controller==null or controller.get("page")!="main":return
	var helper=ROOT+"apply-update.ps1"
	var script=FileAccess.get_file_as_string("res://data/windows_updater.txt")
	if script.is_empty():_fail("업데이트 도구가 없습니다. 현재 버전으로 계속할 수 있습니다.");return
	var helper_file=FileAccess.open(helper,FileAccess.WRITE)
	if helper_file==null:_fail("업데이트 도구를 저장하지 못했습니다.");return
	helper_file.store_string(script);helper_file.close()
	record={"tag":target.tag,"phase":"installing"}
	if not _save_record():_fail("업데이트 상태를 저장하지 못했습니다.");return
	var executable=OS.get_executable_path()
	var powershell=OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	var arguments=PackedStringArray(["-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File",ProjectSettings.globalize_path(helper),"-GameDirectory",executable.get_base_dir(),"-Archive",ProjectSettings.globalize_path(download_path),"-ArchiveSha256",str(target.sha256),"-WaitPid",str(OS.get_process_id()),"-Tag",str(target.tag),"-StateFile",ProjectSettings.globalize_path(ROOT+"state.json")])
	if OS.create_process(powershell,arguments,false)<0:_fail("업데이트 도구를 실행하지 못했습니다.");return
	state="installing";message="업데이트를 적용하고 다시 시작합니다.";changed.emit();get_tree().quit()

func _fail(text: String) -> void:
	_release_request();state="error" if target.is_empty() else "failed";message=text
	if not target.is_empty():record={"tag":target.tag,"phase":"failed"};_save_record()
	changed.emit()

func _release_request() -> void:
	_check_deadline_msec=-1
	_request_serial+=1
	if request!=null:request.cancel_request();request.queue_free();request=null

func _save_record() -> bool:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var file=FileAccess.open(ROOT+"state.json",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(record));file.close();return true

func _exit_tree() -> void:
	if state in ["checking","downloading"]:
		print("UPDATE_CHECK interrupted by scene exit")
		_fail("업데이트 연결이 중단되었습니다. 메인 화면에서 다시 확인해 주세요.")
	if verifier!=null:verifier.wait_to_finish();verifier=null
