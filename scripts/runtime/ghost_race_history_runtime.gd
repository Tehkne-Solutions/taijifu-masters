class_name GhostRaceHistoryRuntime
extends Node

const BRIDGE_VERSION := 1
const SAVE_PATH := "user://taijifu-ghost-race-history.json"
const MAX_ATTEMPTS_PER_GHOST := 40

var records: Dictionary = {}
var _window: JavaScriptObject
var _callbacks: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_history()
	_register_web_bridge()

func record_result(result: Dictionary) -> Dictionary:
	var target_id := String(result.get("target_id", ""))
	if target_id.is_empty():
		return _result(false, "Resultado sem fantasma associado.")
	var entry: Dictionary = records.get(target_id, _default_entry(target_id))
	var outcome := String(result.get("outcome", "empatou"))
	entry["attempts"] = int(entry.get("attempts", 0)) + 1
	match outcome:
		"venceu": entry["wins"] = int(entry.get("wins", 0)) + 1
		"perdeu": entry["losses"] = int(entry.get("losses", 0)) + 1
		_: entry["ties"] = int(entry.get("ties", 0)) + 1
	var player: Dictionary = result.get("player", {})
	var score := int(player.get("score", 0))
	entry["best_score"] = maxi(int(entry.get("best_score", 0)), score)
	entry["best_accuracy"] = maxf(float(entry.get("best_accuracy", 0.0)), float(player.get("accuracy", 0.0)))
	entry["best_chain"] = maxi(int(entry.get("best_chain", 0)), int(player.get("max_chain", 0)))
	entry["last_played_unix"] = int(Time.get_unix_time_from_system())
	var attempts: Array = entry.get("recent", [])
	attempts.push_front({
		"outcome": outcome,
		"score": score,
		"accuracy": float(player.get("accuracy", 0.0)),
		"max_chain": int(player.get("max_chain", 0)),
		"score_delta": int(result.get("score_delta", 0)),
		"elapsed_ms": int(result.get("elapsed_ms", 0)),
		"played_unix": int(Time.get_unix_time_from_system())
	})
	if attempts.size() > MAX_ATTEMPTS_PER_GHOST:
		attempts.resize(MAX_ATTEMPTS_PER_GHOST)
	entry["recent"] = attempts
	records[target_id] = entry
	_save_history()
	_sync_web_state()
	return _result(true, "Histórico atualizado.", {"record": public_record(target_id)})

func public_record(target_id: String) -> Dictionary:
	var entry: Dictionary = records.get(target_id, _default_entry(target_id))
	var attempts := int(entry.get("attempts", 0))
	entry["win_rate"] = float(entry.get("wins", 0)) / float(maxi(1, attempts))
	return entry.duplicate(true)

func current_state() -> Dictionary:
	var list: Array = []
	for target_id in records.keys():
		list.append(public_record(String(target_id)))
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("last_played_unix", 0)) > int(b.get("last_played_unix", 0)))
	return {"version": BRIDGE_VERSION, "ready": true, "count": list.size(), "records": list}

func command(request: Dictionary) -> Dictionary:
	match StringName(request.get("command", "get_state")):
		&"get_record": return public_record(String(request.get("target_id", "")))
		&"clear":
			records.clear()
			_save_history()
			_sync_web_state()
			return _result(true, "Histórico limpo.")
	return current_state()

func _default_entry(target_id: String) -> Dictionary:
	return {"target_id": target_id, "attempts": 0, "wins": 0, "losses": 0, "ties": 0, "best_score": 0, "best_accuracy": 0.0, "best_chain": 0, "last_played_unix": 0, "recent": []}

func _save_history() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"records": records}))

func _load_history() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		records = (parsed as Dictionary).get("records", {})

func _result(ok: bool, message: String, data: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "message": message, "data": data}

func _register_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_window = JavaScriptBridge.get_interface("window")
	if _window == null:
		return
	var command_callback := JavaScriptBridge.create_callback(_web_command)
	var state_callback := JavaScriptBridge.create_callback(_web_state)
	_callbacks = [command_callback, state_callback]
	_window.taijifuGhostRaceHistoryCommand = command_callback
	_window.taijifuGhostRaceHistoryState = state_callback
	_window.taijifuGhostRaceHistoryReady = true
	_sync_web_state()

func _web_command(args: Array) -> String:
	var parsed = JSON.parse_string(String(args[0])) if not args.is_empty() else {"command": "get_state"}
	return JSON.stringify(command(parsed as Dictionary)) if parsed is Dictionary else JSON.stringify(_result(false, "Comando inválido."))

func _web_state(_args: Array) -> String:
	return JSON.stringify(current_state())

func _sync_web_state() -> void:
	if OS.has_feature("web") and _window != null:
		_window.taijifuGhostRaceHistoryStateJson = JSON.stringify(current_state())
