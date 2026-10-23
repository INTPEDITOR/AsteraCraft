class_name ACNuclearCloud
extends "res://scripts/effect_sprite.gd"
var phase_frames: Array=[]

func configure(atlas: Texture2D,count: int,grid: Vector2i=Vector2i.ZERO,anchor: Vector2=Vector2(.5,.86)) -> void:
	if grid==Vector2i.ZERO:grid=Vector2i(4,8 if count==32 else 2)
	super.configure(atlas,count,grid,anchor)
	z_index=10

func update_cloud(ground: Vector2,width: float,elapsed: float,duration: float) -> void:
	var normalized=clampf(elapsed/maxf(.01,duration),0,1)
	var phase=0.0
	if normalized<.125:phase=normalized/.125*.25
	elif normalized<.3125:phase=.25+(normalized-.125)/.1875*.25
	elif normalized<.5625:phase=.5+(normalized-.3125)/.25*.25
	else:phase=.75+(normalized-.5625)/.4375*.25
	var frame=phase*(frame_count-1)
	if phase_frames.size()==5:
		var segment=mini(3,int(phase*4))
		frame=lerpf(float(phase_frames[segment]),float(phase_frames[segment+1]),clampf(phase*4-segment,0,1))
	update_frame(ground,width,frame,1-smoothstep(.68,1,normalized))
