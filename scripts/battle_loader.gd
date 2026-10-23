class_name ACBattleLoader
extends RefCounted

# Only the loading thread owns these maps until finish() transfers them.
var thread=Thread.new()
var mutex=Mutex.new()
var progress=0.0
var caption="전장 준비 중"
var result: Dictionary={}

func start(config: Dictionary,renderer: ACTerrainRenderer,local: bool) -> Error:
	return thread.start(_prepare.bind(config.duplicate(true),renderer,local))

func report(value: float,text: String) -> void:
	mutex.lock();progress=maxf(progress,value);caption=text;mutex.unlock()

func status() -> Dictionary:
	mutex.lock();var output={"progress":progress,"caption":caption};mutex.unlock()
	return output

func _prepare(config: Dictionary,renderer: ACTerrainRenderer,local: bool) -> void:
	var simulation: ACCore
	if local:
		simulation=ACCore.new();simulation.setup(config,report)
	else:report(.08,"전장 지형 준비 중")
	var map=ACMap.new();map.make(int(config.get("map",0)),str(config.get("map_layout","source_chk_cv5_vf4")))
	report(.68,"전장 화면 준비 중")
	renderer.prepare(map,func(value,text):report(.68+value*.31,text))
	result={"core":simulation,"map":map}
	report(1.0,"전장 준비 완료")

func finished() -> bool:
	return thread.is_started() and not thread.is_alive()

func finish() -> Dictionary:
	if thread.is_started():thread.wait_to_finish()
	return result
