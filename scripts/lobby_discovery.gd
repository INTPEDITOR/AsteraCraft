class_name ACLobbyDiscovery
extends Node
## A public HTTPS rendezvous service. No LAN discovery or local lobby fallback.
var endpoint=""
var scope="ONLINE"
var local_process=-1
func ensure_service(callback: Callable) -> void:
	if endpoint=="":endpoint=_configured_endpoint()
	callback.call(endpoint,scope)
func forget_service() -> void:
	endpoint=""
func _configured_endpoint() -> String:
	var override=OS.get_executable_path().get_base_dir().path_join("network.json")
	for path in [override,"res://data/public_network.json"]:
		if not FileAccess.file_exists(path):continue
		var config=JSON.parse_string(FileAccess.get_file_as_string(path))
		if config is Dictionary:
			var url=str(config.get("lobby_url","")).trim_suffix("/")
			if url.begins_with("https://"):return url
	return ""

