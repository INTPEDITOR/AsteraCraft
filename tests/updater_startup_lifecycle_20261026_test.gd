extends SceneTree
## Real HTTPRequest lifecycle on the retained, initially disabled title menu.
## The loopback server never downloads a build or touches a user installation.
const OUT="res://build/updater-startup-lifecycle-20261026/"

class Controller:
	extends Node
	var page="main"

class LocalUpdater:
	extends "res://scripts/game_updater.gd"
	var test_feed=""
	func _feed_url() -> String:return test_feed

var checks=0
var failures: Array=[]
var server=TCPServer.new()
var peers: Array=[]
var requests_received=0
var respond=true
var feed=""
var old_failure_reproduced=false

func _initialize() -> void:call_deferred("run")

func check(ok: bool,caption: String) -> void:
	checks+=1
	if not ok:failures.append(caption);printerr("FAIL: "+caption)

func pump_server() -> void:
	while server.is_connection_available():
		peers.append({"peer":server.take_connection(),"bytes":PackedByteArray(),"received":false,"sent":false})
	for item in peers:
		var peer: StreamPeerTCP=item.peer
		peer.poll()
		if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:continue
		var available=peer.get_available_bytes()
		if available>0:
			var part=peer.get_data(available)
			if part[0]==OK:item.bytes.append_array(part[1])
		if not item.received and item.bytes.get_string_from_utf8().contains("\r\n\r\n"):
			item.received=true;requests_received+=1
		if item.received and not item.sent and respond:
			item.sent=true
			peer.put_data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n[]".to_utf8_buffer())

func frames(count: int=2) -> void:
	for _index in range(count):
		pump_server()
		await process_frame
		pump_server()

func until(condition: Callable,limit_msec: int=4000) -> bool:
	var start=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<limit_msec:await frames(1)
	if not condition.call():print("LOCAL_HTTP_DIAGNOSTIC ",peers.map(func(item):return {"status":item.peer.get_status(),"bytes":item.bytes.size(),"received":item.received,"sent":item.sent}))
	return bool(condition.call())

func service_for(controller: Controller) -> LocalUpdater:
	var service=LocalUpdater.new();service.test_feed=feed
	controller.add_child(service);service.configure(controller)
	# Source tests run in an editor-capable engine. Enable the same gate used by
	# the Windows export without overriding configure, processing, or networking.
	service.install_enabled=true;service._auto_check_pending=true
	service.metadata={"tag":"lifecycle-test","built_at_unix":1};service.record={}
	return service

func run() -> void:
	Engine.max_fps=240
	DirAccess.make_dir_recursive_absolute(OUT)
	var state_path="user://updates/state.json"
	var state_existed=FileAccess.file_exists(state_path)
	var saved_state=FileAccess.get_file_as_string(state_path) if state_existed else ""
	var listening=false
	for port in range(38741,38761):
		if server.listen(port,"127.0.0.1")==OK:
			feed="http://127.0.0.1:%d/releases"%port;listening=true;break
	check(listening,"isolated loopback release server opens")
	if not listening:finish(state_path,state_existed,saved_state);return
	# Optional archived script extracted byte-for-byte from released commit
	# da96c66. It has no class_name and stays under the ignored work directory.
	var legacy_path="res://work/updater_before_hotfix_20261026.gd"
	if FileAccess.file_exists(legacy_path):
		var old_title=Node.new();root.add_child(old_title)
		var old_menu=Controller.new();old_menu.process_mode=Node.PROCESS_MODE_DISABLED;old_title.add_child(old_menu)
		var old_service=load(legacy_path).new();old_menu.add_child(old_service);old_service.configure(old_menu)
		old_service.install_enabled=true;old_service.check_updates(true)
		check(old_service.state=="checking" and old_service.request!=null,"released source starts HTTP while prepared menu is disabled")
		old_menu.reparent(root);old_menu.process_mode=Node.PROCESS_MODE_INHERIT
		await frames(12)
		var old_request=old_service.request
		var timer_stopped=true
		for child in old_request.get_children(true):
			if child is Timer:timer_stopped=timer_stopped and child.is_stopped()
		old_failure_reproduced=old_service.state=="checking" and old_request.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED and not old_request.is_processing_internal() and timer_stopped
		check(old_failure_reproduced,"released source remains checking after reparent cancels both HTTP polling and timeout")
		old_service.last_check=-100000;old_service.check_updates(true)
		check(old_service.state=="checking" and old_service.request==old_request,"released checking state also rejects manual recovery")
		old_menu.queue_free();old_title.queue_free();await frames(2)
	var title=Node.new();root.add_child(title)
	var retained=Controller.new();retained.process_mode=Node.PROCESS_MODE_DISABLED;title.add_child(retained)
	var service=service_for(retained)
	await frames(12)
	check(service.state=="idle" and service.request==null and requests_received==0,"preparing disabled main menu does not start an update request")
	service.check_updates(true)
	check(service.state=="idle" and service.request==null,"manual check also refuses an inactive menu")
	retained.reparent(root)
	await frames(3)
	check(service.request==null and requests_received==0,"reparenting retained menu carries no live HTTP request")
	retained.process_mode=Node.PROCESS_MODE_INHERIT
	check(await until(func():return service.state=="current"),"activation completes real HTTP release check")
	check(requests_received==1 and service.request==null,"activation issues exactly one request and frees it after success")
	await frames(20)
	check(requests_received==1 and service.state=="current","ordinary menu frames do not repeat successful checks")
	retained.queue_free();title.queue_free();await frames(2)

	respond=false
	var parent_a=Node.new();root.add_child(parent_a)
	var parent_b=Node.new();root.add_child(parent_b)
	var moving=Controller.new();parent_a.add_child(moving)
	var moving_service=service_for(moving)
	check(await until(func():return requests_received==2),"second real request is held in flight by the local server")
	check(moving_service.state=="checking" and moving_service.request!=null,"held request is genuinely checking before scene transfer")
	moving.reparent(parent_b)
	await frames(3)
	check(moving_service.state=="error" and moving_service.request==null,"in-flight scene transfer reports terminal error instead of endless checking")
	await frames(20)
	check(requests_received==2 and moving_service.state=="error","canceled scene transfer never loops automatically")
	moving.queue_free();parent_a.queue_free();parent_b.queue_free();await frames(2)

	var timing=Controller.new();root.add_child(timing)
	var timing_service=service_for(timing)
	check(await until(func():return requests_received==3),"timeout scenario starts a real stalled HTTP request")
	var stale_serial=int(timing_service._request_serial)
	timing_service._check_deadline_msec=Time.get_ticks_msec()-1
	await frames(3)
	check(timing_service.state=="error" and timing_service.request==null,"monotonic watchdog exits checking when completion never arrives")
	await frames(12)
	check(requests_received==3,"watchdog failure does not automatically retry")
	timing_service.last_check=-100000;timing_service.check_updates(true)
	check(await until(func():return requests_received==4),"explicit manual retry starts exactly one new HTTP request")
	var current_request=timing_service.request
	timing_service._feed_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),"[]".to_utf8_buffer(),stale_serial)
	check(timing_service.state=="checking" and timing_service.request==current_request,"stale completion cannot finish or cancel the newer request")
	respond=true
	check(await until(func():return timing_service.state=="current"),"manual retry recovers using a real HTTP success response")
	check(timing_service.request==null and requests_received==4,"recovered check releases its request without duplicate attempts")
	timing.queue_free();await frames(3)
	finish(state_path,state_existed,saved_state)

func finish(state_path: String,state_existed: bool,saved_state: String) -> void:
	for item in peers:item.peer.disconnect_from_host()
	server.stop()
	if state_existed:FileAccess.open(state_path,FileAccess.WRITE).store_string(saved_state)
	elif FileAccess.file_exists(state_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(state_path))
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"requests_received":requests_received,"released_source_failure_reproduced":old_failure_reproduced,"scope":"Real loopback HTTP, retained disabled menu activation, reparent cancellation, watchdog, stale completion, manual recovery; no downloads or installations"}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("UPDATER_STARTUP_LIFECYCLE ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
