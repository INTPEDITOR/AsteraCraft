class_name ACSimulationWorker
extends RefCounted
## The worker exclusively owns core while a job is running. Only detached
## snapshots and small command packets cross the mutex-protected mailbox.
var _thread=Thread.new()
var _mutex=Mutex.new()
var _wake=Semaphore.new()
var _stop=false
var _busy=false
var _job={}
var _result={}
var _commands=[]
var _placement={}
var _core: ACCore

func start(core: ACCore) -> void:
	_core=core;_thread.start(_run)

func stop() -> void:
	if not _thread.is_started():return
	_mutex.lock();_stop=true;_mutex.unlock();_wake.post()
	_thread.wait_to_finish()

func command(owner: int,cmd: Dictionary) -> void:
	_mutex.lock();_commands.append({"owner":owner,"cmd":cmd.duplicate(true)});_mutex.unlock()

func placement(owner: int,kind: int,pos: Vector2,key: String) -> void:
	_mutex.lock();_placement={"owner":owner,"kind":kind,"pos":pos,"key":key};_mutex.unlock()

func submit(steps: int,viewer: int) -> bool:
	_mutex.lock()
	if _busy or _stop or not _result.is_empty():_mutex.unlock();return false
	_busy=true;_job={"steps":steps,"viewer":viewer,"commands":_commands,"placement":_placement};_commands=[];_placement={}
	_mutex.unlock();_wake.post();return true

func poll() -> Dictionary:
	_mutex.lock();var value=_result;_result={};_mutex.unlock();return value

func _run() -> void:
	while true:
		_wake.wait();_mutex.lock()
		if _stop:_mutex.unlock();return
		var job=_job;_job={};_mutex.unlock()
		var errors=[];var notices=[];var begin=Time.get_ticks_usec()
		for request in job.commands:
			var error=_core.command(int(request.owner),request.cmd)
			if error!="":errors.append(error)
		for i in range(int(job.steps)):_core.step(.05);_core.resolve_spells()
		for event in _core.events:
			if not event.get("shown",false) and int(event.get("owner",-1))==int(job.viewer) and event.has("text"):
				event.shown=true;notices.append(str(event.text))
		var value={"state":_core.snapshot(int(job.viewer)),"errors":errors,"notices":notices,"simulation_us":Time.get_ticks_usec()-begin}
		if not job.placement.is_empty():
			var plan: Dictionary=job.placement
			value.placement={"key":plan.key,"valid":_core.placement(int(plan.owner),int(plan.kind),plan.pos)==""}
		_mutex.lock();_result=value;_busy=false;_mutex.unlock()
