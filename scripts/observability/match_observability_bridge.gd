class_name MatchObservabilityBridge
extends Node

@export var observability_path: NodePath

var _observability: ObservabilityRuntime

func _ready() -> void:
	if observability_path != NodePath():
		_observability = get_node_or_null(observability_path) as ObservabilityRuntime
	if _observability == null:
		_observability = _find_observability_runtime()

func bind(runtime: ObservabilityRuntime) -> void:
	_observability = runtime

func record_session_started(snapshot: Dictionary) -> void:
	if _observability == null:
		return
	_observability.record_event("match.session.started", {
		"match_session_id": String(snapshot.get("session_id", "")),
		"metadata": snapshot.get("metadata", {}),
		"round_count": int((snapshot.get("rounds", []) as Array).size())
	})

func record_round_finished(round_snapshot: Dictionary) -> void:
	if _observability == null:
		return
	_observability.record_event("match.round.finished", {
		"round_index": int(round_snapshot.get("round_index", 0)),
		"duration_msec": int(round_snapshot.get("duration_msec", 0)),
		"winner_profile_id": String(round_snapshot.get("winner_profile_id", "")),
		"metadata": round_snapshot.get("metadata", {})
	})
	_observability.record_match_snapshot(round_snapshot)

func record_gameplay_event(event_name: String, attributes: Dictionary = {}) -> void:
	if _observability == null:
		return
	_observability.record_event("gameplay.%s" % event_name, attributes)

func record_asset_loaded(asset_id: String, asset_path: String, attributes: Dictionary = {}) -> void:
	var payload := attributes.duplicate(true)
	payload["asset_id"] = asset_id
	payload["asset_path"] = asset_path
	_record_asset_event("asset.loaded", payload, "info")

func record_asset_fallback(asset_id: String, expected_path: String, fallback_id: String) -> void:
	_record_asset_event("asset.fallback_used", {
		"asset_id": asset_id,
		"expected_path": expected_path,
		"fallback_id": fallback_id
	}, "warning")

func record_asset_failure(asset_id: String, asset_path: String, reason: String, attributes: Dictionary = {}) -> void:
	var payload := attributes.duplicate(true)
	payload["asset_id"] = asset_id
	payload["asset_path"] = asset_path
	payload["reason"] = reason
	_record_asset_event("asset.load_failed", payload, "error")

func record_asset_hash_mismatch(asset_id: String, expected_hash: String, actual_hash: String) -> void:
	_record_asset_event("asset.hash_mismatch", {
		"asset_id": asset_id,
		"expected_hash": expected_hash,
		"actual_hash": actual_hash
	}, "error")

func record_module_validation(module_id: String, status: String, attributes: Dictionary = {}) -> void:
	var payload := attributes.duplicate(true)
	payload["module_id"] = module_id
	payload["status"] = status
	_record_asset_event("asset.module_validation", payload, "info" if status == "pass" else "warning")

func record_assembler_failure(preset_id: String, slot_id: String, reason: String) -> void:
	_record_asset_event("asset.assembler_failure", {
		"preset_id": preset_id,
		"slot_id": slot_id,
		"reason": reason
	}, "error")

func record_runtime_error(error_name: String, message: String, attributes: Dictionary = {}) -> void:
	if _observability == null:
		return
	_observability.record_error("runtime.%s" % error_name, message, attributes)

func _record_asset_event(name: String, attributes: Dictionary, severity: String) -> void:
	if _observability == null:
		return
	_observability.record_event(name, attributes, severity)

func _find_observability_runtime() -> ObservabilityRuntime:
	var root := get_tree().root
	for child in root.get_children():
		if child is ObservabilityRuntime:
			return child as ObservabilityRuntime
	return null
