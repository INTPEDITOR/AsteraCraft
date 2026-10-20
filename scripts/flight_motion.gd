class_name ACFlightMotion
extends RefCounted

const ACCEL_SECONDS=.35
const BRAKE_SECONDS=.45

static func speed(c,u: Dictionary) -> float:
	var value=float(u._definition.speed)
	if float(u.get("slow_until",0))>c.time:value*=.45
	if float(u.get("stim_until",0))>c.time:value*=1.25
	if float(u.get("march_until",0))>c.time:value*=1.25
	return value

static func advance(c,u: Dictionary,wanted: Vector2,dt: float) -> void:
	u._air_handled=true
	if u.get("container",-1)>=0:u.air_velocity=[0.0,0.0];return
	var velocity=ACData.point(u.get("air_velocity",[0,0]));var maximum=maxf(.01,speed(c,u))
	var duration=BRAKE_SECONDS if wanted.length_squared()<velocity.length_squared() else ACCEL_SECONDS
	velocity=velocity.move_toward(wanted,maximum/duration*dt)
	if velocity.length_squared()<.0001:velocity=Vector2.ZERO
	var old=ACData.point(u.pos);var next=(old+velocity*dt).clamp(Vector2.ONE,Vector2.ONE*126)
	if is_equal_approx(next.x,old.x):velocity.x=0
	if is_equal_approx(next.y,old.y):velocity.y=0
	u.air_velocity=ACData.packed(velocity)
	c._set_unit_position(u,next)
	var displacement=next-old
	if displacement.length_squared()>.000001:u.facing=ACData.packed(displacement.normalized());u.moving=true

static func move(c,u: Dictionary,goal: Vector2,dt: float,reach: float) -> bool:
	var delta=goal-ACData.point(u.pos);var maximum=speed(c,u)
	if float(u.get("rooted_until",0))>c.time:u.air_velocity=[0.0,0.0];u._air_handled=true;return false
	var remaining=maxf(0,delta.length()-reach)
	var braking_speed=sqrt(2*maximum/BRAKE_SECONDS*remaining)
	advance(c,u,delta.normalized()*minf(maximum,braking_speed),dt)
	return remaining<=.05 and ACData.point(u.air_velocity).length()<.1

static func coast(c,u: Dictionary,dt: float) -> void:
	if u.get("container",-1)>=0:u.air_velocity=[0.0,0.0];return
	if ACData.point(u.get("air_velocity",[0,0])).length_squared()>.0001:advance(c,u,Vector2.ZERO,dt)
