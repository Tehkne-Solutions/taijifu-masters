class_name ObservabilityRuntime
extends Node

const SCHEMA := "tehkne/taijifu-observability/v1"
const VERSION := 1
const SPOOL_DIR := "user://observability"
const SPOOL_FILE := "user://observability/pending.ndjson"
const DEFAULT_BATCH_SIZE := 32
const DEFAULT_FLUSH_INTERVAL_SEC := 5.0
const MAX_QUEUE := 2048
const MAX_ATTEMPTS := 6

signal event_recorded(event: Dictionary)
signal batch_sent(count: int)
signal batch_failed(count: int, reason: String)
signal health_changed(snapshot: Dictionary)

var endpoint_url := ""
var enabled := true
var remote_enabled := false
var batch_size := DEFAULT_BATCH_SIZE
var flush_interval_sec := DEFAULT_FLUSH_INTERVAL_SEC

var _session_id := ""
var _queue: Array[Dictionary] = []
var _flush_elapsed := 0.0
var _request_in_flight := false
var _http: HTTPRequest
var _attempt := 0
var _last_error := ""
var _sent_events := 0
var _failed_batches := 0
var _dropped_events := 0
var _build_context: Dictionary = {}

func _ready() -> void:
	_session_id = "%d-%d" % [int(Time.get_unix_time_from_system()), randi_range(1000, 9999)]
	_http = HTTPRequest.new()
	_http.name = "ObservabilityHTTPRequest"
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_build_context = _default_build_context()
	_load_spool()
	record_event("runtime.started", {"queued_from_spool": _queue.size()}, "info")

func _process(delta: float) -> void:
	if not enabled:
		return
	_flush_elapsed += delta
	if _flush_elapsed >= flush_interval_sec:
		_flush_elapsed = 0.0
		flush()

func configure_remote(url: String, active := true) -> void:
	endpoint_url = url.strip_edges()
	remote_enabled = active and endpoint_url != ""
	emit_signal("health_changed", health_snapshot())

func set_build_context(context: Dictionary) -> void:
	_build_context.merge(context, true)

func record_event(name: String, attributes: Dictionary = {}, severity := "info") -> void:
	if not enabled:
		return
	var event := {
		"schema": SCHEMA,
		"version": VERSION,
		"event_id": _event_id(),
		"session_id": _session_id,
		"name": name,
		"severity": severity,
		"unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"monotonic_ms": Time.get_ticks_msec(),
		"attributes": _sanitize(attributes),
		"build": _build_context.duplicate(true)
	}
	_enqueue(event)
	emit_signal("event_recorded", event.duplicate(true))

func record_error(name: String, message: String, attributes: Dictionary = {}) -> void:
	var payload := attributes.duplicate(true)
	payload["message"] = message
	record_event(name, payload, "error")

func record_metric(name: String, value: float, unit := "count", attributes: Dictionary = {}) -> void:
	var payload := attributes.duplicate(true)
	payload["metric_value"] = value
	payload["metric_unit"] = unit
	record_event("metric.%s" % name, payload, "metric")

func record_timing(name: String, duration_ms: float, attributes: Dictionary = {}) -> void:
	var payload := attributes.duplicate(true)
	payload["duration_ms"] = duration_ms
	record_event("timing.%s" % name, payload, "metric")

func record_match_snapshot(snapshot: Dictionary) -> void:
	record_event("match.snapshot", {"snapshot": snapshot}, "info")

func flush(force_local := false) -> void:
	if _queue.is_empty() or _request_in_flight:
		return
	if force_local or not remote_enabled or endpoint_url == "":
		_persist_spool()
		return
	var count := mini(batch_size, _queue.size())
	var batch: Array = []
	for index in range(count):
		batch.append(_queue[index])
	var body := JSON.stringify({
		"schema": "tehkne/taijifu-observability-batch/v1",
		"sent_unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"events": batch
	})
	_request_in_flight = true
	var error := _http.request(
		endpoint_url,
		["Content-Type: application/json", "X-Tehkne-Observability: 1"],
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		_request_in_flight = false
		_on_send_failure("request_error_%d" % error)

func health_snapshot() -> Dictionary:
	return {
		"schema": SCHEMA,
		"session_id": _session_id,
		"enabled": enabled,
		"remote_enabled": remote_enabled,
		"endpoint_configured": endpoint_url != "",
		"queue_depth": _queue.size(),
		"request_in_flight": _request_in_flight,
		"attempt": _attempt,
		"sent_events": _sent_events,
		"failed_batches": _failed_batches,
		"dropped_events": _dropped_events,
		"last_error": _last_error
	}

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_request_in_flight = false
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var count := mini(batch_size, _queue.size())
		for _index in range(count):
			_queue.pop_front()
		_sent_events += count
		_attempt = 0
		_last_error = ""
		_persist_spool()
		emit_signal("batch_sent", count)
		emit_signal("health_changed", health_snapshot())
		if not _queue.is_empty():
			flush()
		return
	_on_send_failure("http_%d_result_%d" % [response_code, result])

func _on_send_failure(reason: String) -> void:
	_failed_batches += 1
	_attempt += 1
	_last_error = reason
	_persist_spool()
	emit_signal("batch_failed", mini(batch_size, _queue.size()), reason)
	emit_signal("health_changed", health_snapshot())
	if _attempt >= MAX_ATTEMPTS:
		remote_enabled = false

func _enqueue(event: Dictionary) -> void:
	if _queue.size() >= MAX_QUEUE:
		_queue.pop_front()
		_dropped_events += 1
	_queue.append(event)
	if _queue.size() >= batch_size:
		flush()

func _persist_spool() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPOOL_DIR))
	var file := FileAccess.open(SPOOL_FILE, FileAccess.WRITE)
	if file == null:
		return
	for event in _queue:
		file.store_line(JSON.stringify(event))
	file.close()

func _load_spool() -> void:
	if not FileAccess.file_exists(SPOOL_FILE):
		return
	var file := FileAccess.open(SPOOL_FILE, FileAccess.READ)
	if file == null:
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed := JSON.parse_string(line)
		if parsed is Dictionary:
			_queue.append(parsed)
	file.close()

func _default_build_context() -> Dictionary:
	return {
		"engine": Engine.get_version_info(),
		"platform": OS.get_name(),
		"locale": OS.get_locale(),
		"debug_build": OS.is_debug_build(),
		"project_version": ProjectSettings.get_setting("application/config/version", "unknown")
	}

func _event_id() -> String:
	return "%s-%d-%d" % [_session_id, Time.get_ticks_usec(), randi_range(100, 999)]

func _sanitize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value.keys():
			var normalized_key := String(key)
			if normalized_key.to_lower() in ["email", "password", "token", "authorization", "secret"]:
				continue
			result[normalized_key] = _sanitize(value[key])
		return result
	if value is Array:
		var result_array: Array = []
		for item in value:
			result_array.append(_sanitize(item))
		return result_array
	return value
