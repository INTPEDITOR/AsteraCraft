class_name ACUIFont
extends RefCounted

static func create() -> Font:
	var face := FontVariation.new()
	face.base_font = load("res://assets/fonts/Orbitron-VF.ttf")
	face.variation_opentype = {"weight":600.0}
	var korean: Font = load("res://assets/fonts/Galmuri14.ttf")
	var symbols := FontVariation.new()
	symbols.base_font = load("res://assets/fonts/NotoSansKR-VF.ttf")
	symbols.variation_opentype = {"weight":560.0}
	face.fallbacks = [korean,symbols]
	face.spacing_top = 0
	face.spacing_bottom = 0
	return face
