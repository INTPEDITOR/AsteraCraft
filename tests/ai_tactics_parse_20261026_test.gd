extends SceneTree
const B=preload("res://scripts/bot_ai.gd")
const T=preload("res://scripts/bot_tactics.gd")
func _initialize():
	print("AI_TACTICS_PARSE plans=",T.catalog().size());quit(0 if T.catalog().size()==75 else 1)
