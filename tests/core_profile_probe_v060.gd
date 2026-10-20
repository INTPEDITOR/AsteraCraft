extends ACCore
var timings={}
func record(key: String,started: int):
	if not timings.has(key):timings[key]={"us":0,"calls":0}
	timings[key].us+=Time.get_ticks_usec()-started;timings[key].calls+=1
func _unit_fits(u: Dictionary,p: Vector2,check_units: bool=true) -> bool:
	var t=Time.get_ticks_usec();var v=super._unit_fits(u,p,check_units);record("fits",t);return v
func _move(u: Dictionary,g: Vector2,dt: float,reach: float=.5) -> bool:
	var t=Time.get_ticks_usec();var v=super._move(u,g,dt,reach);record("move",t);return v
func _advance_ground(u: Dictionary,w: Vector2,g: Vector2,dt: float) -> Vector2:
	var t=Time.get_ticks_usec();var v=super._advance_ground(u,w,g,dt);record("advance",t);return v
func _melee_approach(u: Dictionary,target: Dictionary) -> Vector2:
	var t=Time.get_ticks_usec();var v=super._melee_approach(u,target);record("melee_approach",t);return v
func _request_room(u: Dictionary,g: Vector2,dt: float) -> void:
	var t=Time.get_ticks_usec();super._request_room(u,g,dt);record("request_room",t)
func _ground_sweep(dimensions: Vector2,from: Vector2,to: Vector2) -> bool:
	var t=Time.get_ticks_usec();var v=super._ground_sweep(dimensions,from,to);record("sweep",t);return v
func _clearance_path(u: Dictionary,from: Vector2,to: Vector2) -> Array:
	var t=Time.get_ticks_usec();var v=super._clearance_path(u,from,to);record("path",t);return v
func _tick_unit_behavior(u: Dictionary,dt: float) -> void:
	var t=Time.get_ticks_usec();super._tick_unit_behavior(u,dt);record("behavior",t)
func profile_report():return timings
func _find_target(u: Dictionary,radius: float,targets: String) -> Dictionary:
	var t=Time.get_ticks_usec();var v=super._find_target(u,radius,targets);record("find_target",t);return v
func _crowd_arrived(u: Dictionary,g: Vector2,reach: float) -> bool:
	var t=Time.get_ticks_usec();var v=super._crowd_arrived(u,g,reach);record("crowd_arrived",t);return v
func _regenerate(u: Dictionary,d: Dictionary,dt: float) -> void:
	var t=Time.get_ticks_usec();super._regenerate(u,d,dt);record("regenerate",t)
func _damage(u: Dictionary,target: Dictionary,amount: float,show_projectile: bool=true,damage_kind: String="attack") -> void:
	var t=Time.get_ticks_usec();super._damage(u,target,amount,show_projectile,damage_kind);record("damage",t)
