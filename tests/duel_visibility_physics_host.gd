extends Node
## Runs test observations in a real physics callback, never a deferred idle call.

signal job_completed
var _physics_job := Callable()
var _physics_result: Variant


func run_in_physics(job: Callable) -> Variant:
	assert(not _physics_job.is_valid())
	_physics_job = job
	set_physics_process(true)
	await job_completed
	return _physics_result


func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	if _physics_job.is_valid():
		var job := _physics_job
		_physics_job = Callable()
		_physics_result = job.call()
		job_completed.emit()
