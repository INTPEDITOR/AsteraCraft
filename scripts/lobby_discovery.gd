class_name ACLobbyDiscovery
extends Node

## Public service configuration is supplied by the distributor in network.json.
## Without that configuration, discovery is limited to the local network.
const PROBE_PORT=17801
const SERVICE_PORT=17800
var endpoint=""
var scope="LAN"
var local_process=-1
var resolving=false
var pending: Array[Callable]=[]
var generation=0

func ensure_service(callback: Callable) -> void:
	if endpoint!="":callback.call(endpoint,scope);return
	pending.append(callback)
	if resolving:return
	resolving=true
	var attempt=generation
	var configured=_configured_endpoint()
	if configured!="":
		endpoint=configured
		scope="ONLINE"
		_finish()
		return
	scope="LAN"
	var candidates: Array=await _probe_lobbies(900)
	if attempt!=generation:return
	if not candidates.is_empty():
		endpoint="http://%s:%d"%[candidates[0].address,int(candidates[0].get("port",SERVICE_PORT))]
	else:
		var node=_node_runtime()
		var script=_root_dir().path_join("server/server.js")
		if node!="" and FileAccess.file_exists(script):
			var data=ProjectSettings.globalize_path("user://lobby")
			DirAccess.make_dir_recursive_absolute(data)
			OS.set_environment("ASTERA_DATA_DIR",data)
			local_process=OS.create_process(node,PackedStringArray([script]),false)
			await get_tree().create_timer(1.2).timeout
			if attempt!=generation:return
			if local_process>0:
				# Concurrent first launches must elect the same oldest lobby.
				candidates=await _probe_lobbies(450)
				if not candidates.is_empty():endpoint="http://%s:%d"%[candidates[0].address,int(candidates[0].get("port",SERVICE_PORT))]
				else:endpoint="http://127.0.0.1:%d"%SERVICE_PORT
	_finish()

func _probe_lobbies(duration_ms: int) -> Array:
	var udp=PacketPeerUDP.new()
	var candidates: Array=[]
	if udp.bind(0)!=OK:return candidates
	udp.set_broadcast_enabled(true)
	for address in ["255.255.255.255","127.0.0.1"]:
		udp.set_dest_address(address,PROBE_PORT)
		udp.put_packet("ASTERA_DISCOVER_V8".to_utf8_buffer())
	var deadline=Time.get_ticks_msec()+duration_ms
	while Time.get_ticks_msec()<deadline:
		while udp.get_available_packet_count()>0:
			var response=JSON.parse_string(udp.get_packet().get_string_from_utf8())
			if response is Dictionary and response.get("app")=="AsteraCraft" and int(response.get("protocol",0))==8:
				response.address=udp.get_packet_ip()
				candidates.append(response)
		await get_tree().process_frame
	udp.close()
	candidates.sort_custom(func(a,b):
		if int(a.get("rooms",0))!=int(b.get("rooms",0)):return int(a.get("rooms",0))>int(b.get("rooms",0))
		if int(a.get("started",0))!=int(b.get("started",0)):return int(a.get("started",0))<int(b.get("started",0))
		return str(a.address)<str(b.address)
	)
	return candidates

func forget_service() -> void:
	generation+=1
	resolving=false
	pending.clear()
	endpoint=""
	scope="LAN"

func _finish() -> void:
	resolving=false
	var callbacks=pending.duplicate()
	pending.clear()
	for callback in callbacks:callback.call(endpoint,scope)

func _root_dir() -> String:
	return OS.get_executable_path().get_base_dir() if FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("AsteraCraft.pck")) else ProjectSettings.globalize_path("res://")

func _configured_endpoint() -> String:
	var path=_root_dir().path_join("network.json")
	if not FileAccess.file_exists(path):return ""
	var config=JSON.parse_string(FileAccess.get_file_as_string(path))
	if config is Dictionary:
		var url=str(config.get("lobby_url","")).trim_suffix("/")
		if url.begins_with("https://") or url.begins_with("http://"):return url
	return ""

func _node_runtime() -> String:
	for candidate in [_root_dir().path_join("runtime/node.exe"),_root_dir().path_join("node.exe"),"C:/Program Files/nodejs/node.exe"]:
		if FileAccess.file_exists(candidate):return candidate
	return ""
