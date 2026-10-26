extends RefCounted
## Local physical gameplay inputs, not commands emitted by the simulation.
## A single group order is one action regardless of its unit count.
var clock=0.0
var actions: Array[float]=[]
var first=0
var total=0

func reset() -> void:
	clock=0.0;actions.clear();first=0;total=0

func advance(seconds: float,active: bool) -> void:
	if not active:return
	clock+=maxf(0,seconds)
	while first<actions.size() and actions[first]<=clock-60.0:first+=1
	if first>256 and first*2>actions.size():actions=actions.slice(first);first=0

func record() -> void:
	actions.append(clock);total+=1

func value() -> int:
	return roundi((actions.size()-first)*60.0/maxf(1.0,minf(60.0,clock)))
