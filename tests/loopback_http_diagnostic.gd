extends SceneTree

var remaining=2

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var port=int(OS.get_environment("ASTERA_DIAG_PORT"))
	for host in ["127.0.0.1","localhost"]:
		var request=HTTPRequest.new()
		request.timeout=3
		root.add_child(request)
		request.request_completed.connect(func(result,code,_headers,body):
			print("GODOT_HTTP host=%s result=%d status=%d body=%s"%[host,result,code,body.get_string_from_utf8().substr(0,140)])
			request.queue_free()
			remaining-=1
			if remaining==0:quit()
		)
		var error=request.request("http://%s:%d/health"%[host,port])
		print("GODOT_HTTP_START host=%s error=%d"%[host,error])
		if error!=OK:
			request.queue_free()
			remaining-=1
	if remaining==0:quit()
