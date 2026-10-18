class_name ACPublicP2P
extends Node
## HTTPS only exchanges SDP/ICE. All battle packets go directly over WebRTC.
signal failed(message: String)
var peer=WebRTCMultiplayerPeer.new()
var connections: Dictionary={}
var pending_ice: Dictionary={}
var remote_set: Dictionary={}
var endpoint=""
var match_id=""
var ticket=""
var hosting=false
var cursor=0
var poll_clock=0.0
var polling=false
var sending=false
var retry_clock=0.0
var outbox: Array=[]
var created=0.0
var ever_connected=false
var failed_once=false
var stun_urls: Array=["stun:stun.cloudflare.com:3478"]

func setup(url: String, game: Dictionary, authority: bool=false) -> MultiplayerPeer:
	endpoint=url.trim_suffix("/");match_id=str(game.id);hosting=authority
	ticket=str(game.signal_ticket)
	created=Time.get_ticks_msec()/1000.0
	if authority:
		peer.create_server([MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED])
		for member in game.players+game.get("observers",[]):
			if not member.get("bot",false):_connection(int(member.peer_id),true)
	else:peer.create_client(int(game.peer_id),[MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED])
	return peer

func _connection(id: int, offer: bool=false) -> WebRTCPeerConnection:
	if connections.has(id):return connections[id]
	var connection=WebRTCPeerConnection.new()
	var err=connection.initialize({"iceServers":[{"urls":stun_urls}]})
	if err!=OK:_fail("직접 연결을 초기화하지 못했습니다.")
	connection.session_description_created.connect(func(type,sdp):
		connection.set_local_description(type,sdp)
		outbox.append({"to":id,"message":{"type":type,"sdp":sdp}})
	)
	connection.ice_candidate_created.connect(func(media,index,candidate):outbox.append({"to":id,"message":{"type":"ice","media":media,"index":index,"candidate":candidate}}))
	connections[id]=connection
	peer.add_peer(connection,id)
	if offer:connection.create_offer()
	return connection

func _process(dt: float) -> void:
	if ticket.is_empty() or failed_once:return
	var ready=false
	var all_ready=not connections.is_empty()
	for connection in connections.values():
		if connection.get_connection_state()==WebRTCPeerConnection.STATE_CONNECTED:ready=true
		else:all_ready=false
	if ready:ever_connected=true
	if not ever_connected and Time.get_ticks_msec()/1000.0-created>45:
		_fail("호스트와 직접 연결하지 못했습니다. 공유기 또는 방화벽의 연결 제한을 확인하세요. 이 경기는 점수에 반영되지 않습니다.");return
	retry_clock-=dt
	if not sending and not outbox.is_empty() and retry_clock<=0:
		sending=true
		var message=outbox[0].duplicate(true);message.id=match_id
		_request("/signal/send",message,func(data):
			sending=false
			if not data.has("error"):outbox.pop_front()
			else:retry_clock=2.0
		)
	# Connected peers send gameplay directly; no continued signaling polling.
	if all_ready:return
	poll_clock-=dt
	if not polling and poll_clock<=0:
		polling=true;poll_clock=3.0 if ready else .6
		_request("/signal/poll?id="+match_id+"&after="+str(cursor),{},func(data):
			polling=false
			for item in data.get("messages",[]):
				cursor=maxi(cursor,int(item.id));_message(int(item.from),item.message)
		)

func _message(id: int, message: Dictionary) -> void:
	if not hosting and id!=1:return
	if hosting and not connections.has(id):return
	var connection=_connection(id)
	var type=str(message.get("type",""))
	if type in ["offer","answer"]:
		if hosting and type!="answer":return
		if not hosting and type!="offer":return
		if connection.set_remote_description(type,str(message.sdp))!=OK:_fail("직접 연결 정보를 적용하지 못했습니다.");return
		remote_set[id]=true
		for ice in pending_ice.get(id,[]):connection.add_ice_candidate(str(ice.media),int(ice.index),str(ice.candidate))
		pending_ice.erase(id)
	elif type=="ice":
		if remote_set.get(id,false):connection.add_ice_candidate(str(message.media),int(message.index),str(message.candidate))
		else:
			if not pending_ice.has(id):pending_ice[id]=[]
			pending_ice[id].append(message)

func _request(path: String, data: Dictionary, callback: Callable) -> void:
	var http=HTTPRequest.new();http.timeout=10;add_child(http)
	http.request_completed.connect(func(result,code,_headers,body):
		var response=JSON.parse_string(body.get_string_from_utf8())
		if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or not response is Dictionary:response={"error":"연결 서비스 응답 실패"}
		http.queue_free();callback.call(response)
	)
	var post=not data.is_empty()
	var err=http.request(endpoint+path,PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+ticket]),HTTPClient.METHOD_POST if post else HTTPClient.METHOD_GET,JSON.stringify(data) if post else "")
	if err!=OK:http.queue_free();callback.call({"error":"연결 요청 실패"})

func _fail(message: String) -> void:
	if failed_once:return
	failed_once=true;failed.emit(message)

func close() -> void:
	ticket="";peer.close()
	for connection in connections.values():connection.close()
	connections.clear()
