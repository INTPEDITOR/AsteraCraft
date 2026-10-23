extends RefCounted
## A defeated computer may ask a human opponent; only that human can decide.
const MIN_TIME=180.0
const CONFIRM_TIME=20.0
const REJECT_COOLDOWN=120.0
static func strength(core,owner: int) -> Vector2:
	var result=Vector2.ZERO
	for u in core.units:
		if int(u.owner)!=owner or u.hp<=0 or u.get("technical",false):continue
		var d=ACData.unit(int(u.race),int(u.kind))
		if float(d.damage)<=0 and str(d.role)!="carrier":continue
		result.x+=(float(d.get("as",0))+float(d.get("tera",0))*1.5+float(d.hp)*.2)*clampf(float(u.hp)/float(d.hp),.1,1)
	for b in core.buildings:
		if int(b.owner)!=owner or b.hp<=0:continue
		var d=ACData.building(int(b.race),int(b.kind))
		result.y+=(float(d.get("as",0))+float(d.get("tera",0))*1.5+80)*clampf(float(b.hp)/float(d.hp),.1,1)*maxf(.2,float(b.progress))
	return result
static func tick(core,owner: int) -> void:
	var player: Dictionary=core.players[owner]
	if not player.bot or player.lost or core.time<MIN_TIME or core.time<float(player.get("_surrender_retry",0)):return
	if core.surrender_requests.any(func(r):return int(r.bot)==owner):return
	var mine=strength(core,owner);var recipient=-1;var strongest=Vector2.ZERO
	for id in range(core.players.size()):
		if core.players[id].bot or core.players[id].lost or core.allied(owner,id):continue
		var enemy=strength(core,id)
		if enemy.x+enemy.y*.4>strongest.x+strongest.y*.4:strongest=enemy;recipient=id
	# Compare teams too: a surviving strong ally is a reason to keep fighting.
	for id in range(core.players.size()):
		if id!=owner and not core.players[id].lost and core.allied(owner,id):mine+=strength(core,id)
	var outmatched=recipient>=0 and strongest.x>=600 and mine.x<strongest.x*.22 and mine.x+mine.y*.4<(strongest.x+strongest.y*.4)*.30
	if not outmatched:player.erase("_surrender_weak_since");return
	if not player.has("_surrender_weak_since"):player._surrender_weak_since=core.time
	if core.time-float(player._surrender_weak_since)<CONFIRM_TIME:return
	core.surrender_requests.append({"bot":owner,"recipient":recipient,"started":core.time})
static func respond(core,owner: int,cmd: Dictionary) -> String:
	if not cmd.get("accept",null) is bool:return "항복 승인 여부를 확인하세요"
	var bot=int(cmd.get("bot",-1))
	for request in core.surrender_requests:
		if int(request.bot)!=bot or int(request.recipient)!=owner:continue
		if bot<0 or bot>=core.players.size() or not core.players[bot].bot or core.allied(owner,bot):return "유효한 컴퓨터 항복 요청이 아닙니다"
		core.surrender_requests.erase(request)
		if cmd.accept:
			core.players[bot].lost=true;core._check_end()
		else:
			core.players[bot]._surrender_retry=core.time+REJECT_COOLDOWN
			core.players[bot].erase("_surrender_weak_since")
		return ""
	return "이미 처리된 항복 요청입니다"
