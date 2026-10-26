extends RefCounted
## Ground workers ease into motion like aircraft, while every displacement
## still uses the ground router, body collision and exact own-building seam.
const ACCEL_SECONDS=.35
const BRAKE_SECONDS=.45

static func stop(u: Dictionary) -> void:
	u._worker_driven=true;u._worker_speed=0.0;u._worker_velocity=[0.0,0.0]

static func speed(u: Dictionary,maximum: float,remaining: float,dt: float) -> float:
	u._worker_driven=true
	var current=float(u.get("_worker_speed",0))
	var wanted=minf(maximum,sqrt(2*maximum/BRAKE_SECONDS*maxf(0,remaining)))
	var duration=ACCEL_SECONDS if wanted>current else BRAKE_SECONDS
	var value=move_toward(current,wanted,maximum/duration*dt)
	u._worker_speed=value
	return value

static func record(u: Dictionary,displacement: Vector2,dt: float) -> void:
	var velocity=displacement/maxf(.001,dt)
	u._worker_velocity=ACData.packed(velocity)
	u._worker_speed=minf(float(u.get("_worker_speed",0)),velocity.length())

static func settling(u: Dictionary) -> bool:
	return float(u.get("_worker_speed",0))>.05

static func coast(c,u: Dictionary,dt: float) -> void:
	if u.get("_worker_driven",false):return
	if u.container>=0 or u.anchored or float(u.get("rooted_until",0))>c.time or u.has("_construction_site") or str(u.get("action_intent","")) in ["harvest","construct","repair"]:stop(u);return
	var velocity=ACData.point(u.get("_worker_velocity",[0,0]));var current=velocity.length()
	if current<.01:stop(u);return
	var maximum=maxf(.01,float(c.unit_data(u).speed));var value=maxf(0,current-maximum/BRAKE_SECONDS*dt)
	var displacement=velocity.normalized()*value*dt;var origin=ACData.point(u.pos);var next=origin+displacement
	if not c._ground_sweep(c._body_size(u),origin,next,c._worker_passage_owner(u)) or not c._unit_fits(u,next):stop(u);return
	c._set_unit_position(u,next);u._worker_speed=value;u._worker_velocity=ACData.packed(velocity.normalized()*value)
	if displacement.length_squared()>.000001:u.facing=ACData.packed(displacement.normalized());u.moving=true
