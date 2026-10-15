extends "res://scripts/main.gd"

var api_requests: Array=[]
var saved_replays=0
var api_responses: Dictionary={
	"/rooms":{"rooms":[]},
	"/leaderboard":{"users":[{"id":"qa-user","nickname":"은하의 지휘관","rating":1245,"wins":12,"losses":6,"win_rate":66.7}]}
}

func _api(route: String,body: Dictionary,callback: Callable) -> void:
	api_requests.append({"route":route,"body":body.duplicate(true)})
	callback.call(api_responses.get(route,{"error":"QA fixture has no response"}).duplicate(true))

func _save_replay() -> void:
	saved_replays+=1
