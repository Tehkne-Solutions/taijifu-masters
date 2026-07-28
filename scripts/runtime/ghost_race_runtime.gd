class_name GhostRaceRuntime
extends Node

const BRIDGE_VERSION := 1

var active := false
var started_ms := 0
var target_duration_ms := 0
var target: Dictionary = {}
var live_summary: Dictionary = {}
var last_result: Dictionary = {}
var _window: JavaScriptObject
var _callbacks: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_web_bridge()

func _physics_process(_delta: float) -> void:
	if not active:
		return
	_refresh_live_summary()
	if elapsed_ms() >= target_duration_ms:
		finish_race()
	_sync_web_state()

func start_selected() -> Dictionary:
	var library := get_node_or_null("/root/TaijifuGhostLibrary") as GhostLibraryRuntime
	var mastery := get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime
	if not is_instance_valid(library) or not is_instance_valid(mastery):
		return _result(false, "Runtime da corrida indisponível.")
	var index := library._index_of(library.selected_id)
	if index < 0:
		return _result(false, "Selecione um fantasma da biblioteca.")
	var item: Dictionary = library.items[index]
	target = {
		"id": String(item.get("id", "")),
		"name": String(item.get("name", "Fantasma")),
		"challenge": (item.get("challenge", {}) as Dictionary).duplicate(true),
		"recording": (item.get("recording", {}) as Dictionary).duplicate(true)
	}
	target_duration_ms = maxi(1000, int((target.get("recording", {}) as Dictionary).get("duration_ms", 12000)))
	mastery.stop_playback()
	if not mastery.start_recording():
		return _result(false, "Entre em uma arena antes de iniciar a corrida.")
	var playback := library.play_selected()
	if not bool(playback.get("ok", false)):
		mastery.stop_recording("Corrida cancelada.")
		return playback
	started_ms = Time.get_ticks_msec()
	active = true
	live_summary = {}
	last_result = {}
	_sync_web_state()
	return _result(true, "Corrida assíncrona iniciada.", {"target": _public_target()})

func finish_race() -> Dictionary:
	if not active:
		return _result(false, "Nenhuma corrida ativa.")
	var mastery := get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime
	if not is_instance_valid(mastery):
		active = false
		return _result(false, "Runtime de gravação indisponível.")
	var recording := mastery.stop_recording("Corrida contra fantasma concluída.")
	mastery.stop_playback()
	var player_summary: Dictionary = recording.get("summary", {})
	var target_summary: Dictionary = (target.get("challenge", {}) as Dictionary).duplicate(true)
	var player_score := int(player_summary.get("score", 0))
	var target_score := int(target_summary.get("score", 0))
	var outcome := "empatou"
	if player_score > target_score:
		outcome = "venceu"
	elif player_score < target_score:
		outcome = "perdeu"
	last_result = {
		"outcome": outcome,
		"player": player_summary.duplicate(true),
		"target": target_summary,
		"score_delta": player_score - target_score,
		"elapsed_ms": elapsed_ms(),
		"target_id": String(target.get("id", ""))
	}
	active = false
	live_summary = player_summary.duplicate(true)
	_sync_web_state()
	return _result(true, "Resultado: %s." % outcome, last_result.duplicate(true))

func cancel_race() -> Dictionary:
	if not active:
		return _result(false, "Nenhuma corrida ativa.")
	var mastery := get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime
	if is_instance_valid(mastery):
		mastery.stop_recording("Corrida cancelada.")
		mastery.stop_playback()
	active = false
	last_result = {"outcome": "cancelada"}
	_sync_web_state()
	return _result(true, "Corrida cancelada.")

func elapsed_ms() -> int:
	return maxi(0, Time.get_ticks_msec() - started_ms) if active else int(last_result.get("elapsed_ms", 0))

func _refresh_live_summary() -> void:
	var mastery := get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime
	if not is_instance_valid(mastery) or not mastery._recording_active:
		return
	live_summary = mastery._summary_from_attempt(mastery._attempt, elapsed_ms())

func current_state() -> Dictionary:
	var challenge: Dictionary = target.get("challenge", {})
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"active": active,
		"elapsed_ms": elapsed_ms(),
		"target_duration_ms": target_duration_ms,
		"remaining_ms": maxi(0, target_duration_ms - elapsed_ms()) if active else 0,
		"player": live_summary.duplicate(true),
		"target": _public_target(),
		"score_delta": int(live_summary.get("score", 0)) - int(challenge.get("score", 0)),
		"last_result": last_result.duplicate(true)
	}

func command(request: Dictionary) -> Dictionary:
	match StringName(request.get("command", "get_state")):
		&"start_selected": return start_selected()
		&"finish": return finish_race()
		&"cancel": return cancel_race()
	return current_state()

func _public_target() -> Dictionary:
	return {
		"id": String(target.get("id", "")),
		"name": String(target.get("name", "Fantasma")),
		"challenge": (target.get("challenge", {}) as Dictionary).duplicate(true)
	}

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
	_window.taijifuGhostRaceCommand = command_callback
	_window.taijifuGhostRaceState = state_callback
	_window.taijifuGhostRaceReady = true
	_sync_web_state()

func _web_command(args: Array) -> String:
	if args.is_empty():
		return JSON.stringify(current_state())
	var parsed = JSON.parse_string(String(args[0]))
	if not parsed is Dictionary:
		return JSON.stringify(_result(false, "Comando inválido."))
	return JSON.stringify(command(parsed as Dictionary))

func _web_state(_args: Array) -> String:
	return JSON.stringify(current_state())

func _sync_web_state() -> void:
	if not OS.has_feature("web") or _window == null:
		return
	_window.taijifuGhostRaceStateJson = JSON.stringify(current_state())
	_window.taijifuGhostRaceReady = true
