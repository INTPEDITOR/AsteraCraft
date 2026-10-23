class_name ACPlayerColors
extends RefCounted
const NAMES=["파랑","빨강","초록","보라","노랑","주황","청록","분홍"]
const HEX=["428bdf","db5255","56b66b","a078d5","e9c64a","ec8c39","42c5c7","e87eae"]
const NATIVE=[4,5,1]
static func color(index: int) -> Color:return Color(HEX[posmod(index,HEX.size())])
static func resolve(specs: Array) -> Array:
	var result=[];var used={}
	for spec in specs:
		var candidate=int(spec.get("color_id",-1))
		if candidate<0 or candidate>=HEX.size() or used.has(candidate):candidate=-1
		result.append(candidate)
		if candidate>=0:used[candidate]=true
	for index in range(specs.size()):
		if result[index]>=0:continue
		var candidate=int(NATIVE[clampi(int(specs[index].get("race",0)),0,2)])
		if used.has(candidate):
			for available in range(HEX.size()):
				if not used.has(available):candidate=available;break
		result[index]=candidate;used[candidate]=true
	return result
