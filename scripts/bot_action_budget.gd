extends RefCounted
const RATES=preload("res://scripts/bot_difficulty.gd").APM
var owners: Dictionary={}

func begin(c,owner: int) -> void:
	var p: Dictionary=c.players[owner];var level=clampi(int(p.difficulty),0,5)
	var engaged=str(p.get("_ai_attack_phase",""))=="defend" or c.units.any(func(u):return int(u.owner)==owner and u.hp>0 and (c.time-float(u.fired)<2 or c.time-float(u.damaged)<2))
	var rate=450 if level==5 and engaged else RATES[level]
	if not owners.has(owner):owners[owner]={"credit":1.0,"last":0.0,"actions":[],"head":0,"total":0,"rate":rate}
	var entry: Dictionary=owners[owner]
	entry.credit=minf(6 if level==5 else 3, float(entry.credit)+maxf(0,c.time-float(entry.last))*rate/60.0)
	entry.last=c.time;entry.rate=rate
	var actions: Array=entry.actions
	while int(entry.head)<actions.size() and float(actions[int(entry.head)])<=c.time-60:entry.head=int(entry.head)+1
	if int(entry.head)>256 and int(entry.head)*2>actions.size():entry.actions=actions.slice(int(entry.head));entry.head=0
	p._ai_apm_budget=rate;p._ai_apm=roundi((entry.actions.size()-int(entry.head))*60/maxf(1,minf(60,c.time)))

func available(owner: int) -> bool:
	return owners.has(owner) and float(owners[owner].credit)>=1.0

func record(c,owner: int,kind: String) -> void:
	var entry: Dictionary=owners[owner];entry.credit=float(entry.credit)-1;entry.total=int(entry.total)+1;entry.actions.append(c.time)
	var p: Dictionary=c.players[owner];p._ai_actions_total=entry.total
	var counts: Dictionary=p.get("_ai_action_types",{});counts[kind]=int(counts.get(kind,0))+1;p._ai_action_types=counts
