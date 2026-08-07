class_name RuntimePerformanceObserver
extends Node

@export var observability_path: NodePath
@export var sample_interval_sec := 1.0
@export var stall_threshold_ms := 50.0
@export var low_fps_threshold := 40.0

var _observability: ObservabilityRuntime
var _elapsed := 0.0
var _scene_load_started_usec := 0
var _scene_load_label := ""

func _ready() -> void:
	if observability_path != NodePath():
		_observability = get_node_or_null(observability_path) as ObservabilityRuntime
	if _observability == null:
		_observability = _find_observability_runtime()

func bind(runtime: ObservabilityRuntime) -> void:
	_observability = runtime

func _process(delta: float) -> void:
	if _observability == null:
		return
	var frame_ms := delta * 1000.0
	if frame_ms >= stall_threshold_ms:
		_observability.record_event("performance.frame_stall", {
			"frame_time_ms": frame_ms,
			"stall_threshold_ms": stall_threshold_ms
		}, "warning")
	_elapsed += delta
	if _elapsed < sample_interval_sec:
		return
	_elapsed = 0.0
	_sample_runtime()

func begin_scene_load(label: String) -> void:
	_scene_load_label = label
	_scene_load_started_usec = Time.get_ticks_usec()

func finish_scene_load(attributes: Dictionary = {}) -> void:
	if _observability == null or _scene_load_started_usec <= 0:
		return
	var duration_ms := float(Time.get_ticks_usec() - _scene_load_started_usec) / 1000.0
	var payload := attributes.duplicate(true)
	payload["scene"] = _scene_load_label
	_observability.record_timing("scene_load", duration_ms, payload)
	_scene_load_started_usec = 0
	_scene_load_label = ""

func record_input_latency(action: String, latency_ms: float, attributes: Dictionary = {}) -> void:
	if _observability == null:
		return
	var payload := attributes.duplicate(true)
	payload["action"] = action
	_observability.record_timing("input_latency", latency_ms, payload)

func record_ai_decision(agent_id: String, decision: String, duration_ms: float, attributes: Dictionary = {}) -> void:
	if _observability == null:
		return
	var payload := attributes.duplicate(true)
	payload["agent_id"] = agent_id
	payload["decision"] = decision
	_observability.record_timing("ai_decision", duration_ms, payload)

func _sample_runtime() -> void:
	var fps := Engine.get_frames_per_second()
	var memory_static := Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_message := Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)
	_observability.record_metric("fps", fps, "fps")
	_observability.record_metric("memory_static", memory_static, "bytes")
	_observability.record_metric("memory_message_buffer_max", memory_message, "bytes")
	if fps > 0.0 and fps < low_fps_threshold:
		_observability.record_event("performance.low_fps", {
			"fps": fps,
			"threshold": low_fps_threshold
		}, "warning")

func _find_observability_runtime() -> ObservabilityRuntime:
	var root := get_tree().root
	for child in root.get_children():
		if child is ObservabilityRuntime:
			return child as ObservabilityRuntime
	return null
