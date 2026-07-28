class_name GhostRaceSeriesRuntime
extends Node

const BRIDGE_VERSION := 1
const SAVE_PATH := "user://taijifu-ghost-race-series.json"

var active := false
var best_of := 3
var wins_needed := 2
var target_id := ""
var target_name := "Fantasma"
var player_wins := 0
var ghost_wins := 0
var ties := 0
var rounds: Array = []
var last_series: Dictionary = {}
var _window: JavaScriptObject
var _callbacks: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state()
	_register_web_bridge()

func start_series(format: int = 3) -> Dictionary:
	if format != 3 and format != 5:
		return _result(false, "Formato inválido. Use melhor de 3 ou melhor de 5.")
	var library := get_node_or_null("/root/TaijifuGhostLibrary")
	if not is_instance_valid(library) or String(library.selected_id).is_empty():
		return _result(false, "Selecione um fantasma antes de iniciar a série.")
	var index := library._index_of(library.selected_id)
	if index < 0:
		return _result(false, "Fantasma selecionado não encontrado.")
	var item: Dictionary = library.items[index]
	best_of = format
	wins_needed = int(format / 2) + 1
	target_id = String(item.get("id", ""))
	target_name = String(item.get("name", "Fantasma"))
	player_wins = 0
	ghost_wins = 0
	ties = 0
	rounds.clear()
	last_series = {}
	active = true
	_save_state()
	_sync_web_state()
	return start_next_round()

func start_next_round() -> Dictionary:
	if not active:
		return _result(false, "Nenhuma série ativa.")
	var race := get_node_or_null("/root/TaijifuGhostRace")
	if not is_instance_valid(race):
		return _result(false, "Runtime de corrida indisponível.")
	var result: Dictionary = race.start_selected()
	if bool(result.get("ok", false)):
		_sync_web_state()
	return result

func register_round(result: Dictionary) -> Dictionary:
	if not active or String(result.get("target_id", "")) != target_id:
		return _result(false, "Resultado fora da série ativa.")
	var outcome := String(result.get("outcome", "empatou"))
	match outcome:
		"venceu": player_wins += 1
		"perdeu": ghost_wins += 1
		_: ties += 1
	rounds.append(result.duplicate(true))
	if player_wins >= wins_needed or ghost_wins >= wins_needed:
		_finish_series()
	_save_state()
	_sync_web_state()
	return _result(true, "Rodada registrada.", current_state())

func _finish_series() -> void:
	var outcome := "venceu" if player_wins > ghost_wins else "perdeu"
	last_series = {
		"target_id": target_id,
		"target_name": target_name,
		"best_of": best_of,
		"player_wins": player_wins,
		"ghost_wins": ghost_wins,
		"ties": ties,
		"outcome": outcome,
		"rounds": rounds.duplicate(true),
		"finished_unix": int(Time.get_unix_time_from_system())
	}
	active = false

func rematch() -> Dictionary:
	var format := int(last_series.get("best_of", best_of))
	return start_series(format)

func cancel_series() -> Dictionary:
	if not active:
		return _result(false, "Nenhuma série ativa.")
	active = false
	_save_state()
	_sync_web_state()
	return _result(true, "Série cancelada.")

func current_state() -> Dictionary:
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"active": active,
		"best_of": best_of,
		"wins_needed": wins_needed,
		"target_id": target_id,
		"target_name": target_name,
		"player_wins": player_wins,
		"ghost_wins": ghost_wins,
		"ties": ties,
		"round_number": rounds.size() + 1 if active else rounds.size(),
		"rounds": rounds.duplicate(true),
		"last_series": last_series.duplicate(true)
	}

func command(request: Dictionary) -> Dictionary:
	match StringName(request.get("command", "get_state")):
		&"start_best_of_3": return start_series(3)
		&"start_best_of_5": return start_series(5)
		&"next_round": return start_next_round()
		&"rematch": return rematch()
		&"cancel": return cancel_series()
	return current_state()

func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_state()))

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	active = bool(data.get("active", false))
	best_of = int(data.get("best_of", 3))
	wins_needed = int(data.get("wins_needed", 2))
	target_id = String(data.get("target_id", ""))
	target_name = String(data.get("target_name", "Fantasma"))
	player_wins = int(data.get("player_wins", 0))
	ghost_wins = int(data.get("ghost_wins", 0))
	ties = int(data.get("ties", 0))
	rounds = data.get("rounds", [])
	last_series = data.get("last_series", {})

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
	_window.taijifuGhostRaceSeriesCommand = command_callback
	_window.taijifuGhostRaceSeriesState = state_callback
	_window.taijifuGhostRaceSeriesReady = true
	_sync_web_state()

func _web_command(args: Array) -> String:
	var parsed = JSON.parse_string(String(args[0])) if not args.is_empty() else {"command": "get_state"}
	return JSON.stringify(command(parsed as Dictionary)) if parsed is Dictionary else JSON.stringify(_result(false, "Comando inválido."))

func _web_state(_args: Array) -> String:
	return JSON.stringify(current_state())

func _sync_web_state() -> void:
	if OS.has_feature("web") and _window != null:
		_window.taijifuGhostRaceSeriesStateJson = JSON.stringify(current_state())
