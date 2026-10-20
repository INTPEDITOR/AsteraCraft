class_name ACWeaponSockets
extends RefCounted

# Reviewed visible muzzle positions in each canonical N / NE / E / SE / S
# firing silhouette. Coordinates are relative to the trimmed frame, not feet.
const SOCKETS={
	"0:9":[[.28,.10],[.76,.18],[.96,.55],[.88,.84],[.31,.95]],
	"0:10":[[.19,.25],[.37,.32],[.83,.26],[.88,.65],[.20,.72]],
	"0:12":[[.5,.04],[.94,.08],[.99,.40],[.97,.53],[.5,.83]],
	"0:15":[[.5,.06],[.85,.20],[.95,.62],[.73,.84],[.5,.94]],
	"0:13":[[.5,.24],[.78,.40],[.92,.57],[.73,.74],[.35,.78]],
	"1:0":[[.5,.20],[.77,.48],[.90,.58],[.77,.69],[.5,.73]],
	"1:2":[[.5,.22],[.77,.39],[.90,.56],[.79,.64],[.5,.71]],
	"1:5":[[.5,.28],[.76,.45],[.91,.57],[.80,.64],[.5,.68]],
	"1:6":[[.49,.10],[.73,.13],[.84,.16],[.77,.24],[.5,.15]],
	"1:7":[[.5,.23],[.82,.39],[.94,.47],[.75,.55],[.5,.67]],
	"1:8":[[.5,.20],[.81,.37],[.94,.43],[.87,.55],[.5,.73]],
	"1:10":[[.5,.23],[.76,.29],[.87,.35],[.74,.39],[.5,.35]],
	"1:12":[[.5,.27],[.77,.46],[.88,.56],[.76,.64],[.5,.58]],
	"2:0":[[.5,.72],[.75,.66],[.83,.66],[.73,.75],[.5,.77]],
	"2:2":[[.5,.30],[.73,.40],[.90,.48],[.80,.59],[.5,.66]],
	"2:3":[[.5,.37],[.72,.39],[.80,.42],[.74,.49],[.5,.52]],
	"2:5":[[.77,.24],[.80,.22],[.84,.27],[.81,.30],[.77,.23]],
	"2:7":[[.5,.27],[.78,.41],[.90,.55],[.80,.62],[.5,.70]],
	"2:8":[[.5,.13],[.78,.31],[.93,.54],[.79,.72],[.5,.85]],
	"2:12":[[.5,.67],[.73,.62],[.84,.65],[.73,.78],[.5,.83]],
	"2:13":[[.5,.28],[.82,.26],[.95,.30],[.85,.45],[.5,.60]]
}
const AIR_NOSE=[[.5,.10],[.78,.25],[.94,.50],[.80,.73],[.5,.88]]

static func local_offset(frame: Dictionary,race: int,kind: int,direction: Vector2,shot_index: int=-1) -> Vector2:
	var key="%d:%d"%[race,kind]
	var index=ACData.sprite_direction(direction,8)
	var positions: Array=SOCKETS.get(key,AIR_NOSE if ACData.unit(race,kind).air else [[.5,.20],[.78,.36],[.90,.50],[.80,.64],[.5,.73]])
	var normalized=ACData.point(positions[int(index.column)])
	if frame.get("source_mirror",false):normalized.x=1-normalized.x
	var bounds: Rect2=frame.get("sprite_bounds",Rect2(Vector2.ZERO,frame.texture.get_size()))
	var point=bounds.position+normalized*bounds.size-frame.anchor
	if key=="0:12" and shot_index>=0:
		var canonical=Vector2.UP.rotated(float(index.column)*PI/4)
		point+=Vector2(-canonical.y,canonical.x*.70)*maxf(bounds.size.x,bounds.size.y)*.065*(posmod(shot_index,3)-1)
	if frame.get("flip",false):point.x=-point.x
	return point.rotated(float(frame.get("rotation",0)))
