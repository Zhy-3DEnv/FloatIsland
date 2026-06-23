extends Node

signal time_changed(seconds_left: float, stability_percent: float)
signal countdown_started
signal victory
signal defeat

const M1_DURATION := 600.0
const FALL_TIME_PENALTY := 5.0

var time_remaining: float = M1_DURATION
var running := false
var finished := false


func _ready() -> void:
	time_remaining = M1_DURATION
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not running or finished:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	_emit_time()
	if time_remaining <= 0.0:
		_trigger_defeat()


func get_stability_percent() -> float:
	return (time_remaining / M1_DURATION) * 100.0


func start_countdown() -> void:
	if running or finished:
		return
	running = true
	countdown_started.emit()
	_emit_time()


func apply_fall_penalty() -> void:
	if finished:
		return
	time_remaining = maxf(0.0, time_remaining - FALL_TIME_PENALTY)
	_emit_time()
	if time_remaining <= 0.0:
		_trigger_defeat()


func stop_with_victory() -> void:
	if finished:
		return
	finished = true
	running = false
	victory.emit()
	_emit_time()


func reset_for_retry() -> void:
	time_remaining = M1_DURATION
	running = false
	finished = false
	_emit_time()


func _trigger_defeat() -> void:
	finished = true
	running = false
	defeat.emit()
	_emit_time()


func _emit_time() -> void:
	time_changed.emit(time_remaining, get_stability_percent())
