class_name MultiGhostRaceRuntime
extends Node

const BRIDGE_VERSION := 1
const SAVE_PATH := "user://taijifu-multi-ghost-race.json"
const MAX_RIVALS := 3

var active := false
var started_ms := 0
var duration_ms := 0
var rivals: Array = []
var live_player: Dictionary = {}
var live_standings: Array = []
var last_result: Dictionary = {}
var history: Array = []
var _window: JavaScriptObject
var _callbacks: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state()
	_register_web_bridge()

func _physics_process(_delta: float) -> void:
	if not active:
		return
	_refresh_live_state()
	if elapsed_ms() >= duration_ms:
		finish_race()
	_sync_web_state()

func start_top_rivals(count: int = 3) -> Dictionary:
	var library := get_node_or_null("/root/TaijifuGhostLibrary") as GhostLibraryRuntime
	var mastery := get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime
	if not is_instance_valid(library) or not is_instance_valid(mastery):
		return _result(false, "Runtime multirrival indisponível.")
	var desired := clampi(count, 2, MAX_RIVALS)
	var candidates := _ranked_library_items(library)
	if candidates.size() < 2:
		return _result(false, "A biblioteca precisa ter ao menos dois fantasmas.")
	rivals.clear()
	for item in candidates.slice(0, mini(desired, candidates.size())):
		if item is Dictionary:
			var entry := item as Dictionary
			rivals.append({
				"id": String(entry.get("id", "")),
				"name": String(entry.get("name", "Fantasma")),
				"challenge": (entry.get("challenge", {}) as Dictionary).duplicate(true),
				"recording": (entry.get("recording", {}) as Dictionary).duplicate(true)
			})
	if rivals.size() < 2:
		return _result(false, "Não foi possível preparar rivais suficientes.")
	duration_ms = 1000
	for rival in rivals:
		duration_ms = maxi(duration_ms, int(((rival as Dictionary).get("recording", {}) as Dictionary).get("duration_ms", 12000)))
	mastery.stop_playback()
	if not mastery.start_recording():
		return _result(false, "Entre em uma arena antes de iniciar a corrida.")
	var original_selected := library.selected_id
	library.selected_id = String((rivals[0] as Dictionary).get("id", ""))
	var playback := library.play_selected()
	library.selected_id = original_selected
	if not bool(playback.get("ok", false)):
		mastery.stop_recording("Corrida multirrival cancelada.")
		return playback
	started_ms = Time.get_ticks_msec()
	active = true
	live_player = {}
	live_standings = _build_standings(0)
	last_result = {}
	_sync_web_state()
	return _result(true, "Corrida contra %d fantasmas iniciada." % rivals.size(), current_state())

func finish_race() -> Dictionary:
	if not active:
		return _result(false, "Nenhuma corrida multirrival ativa.")
	var mastery := get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime
	if not is_instance_valid(mastery):
		active = false
		return _result(false, "Runtime de gravação indisponível.")
	var recording := mastery.stop_recording("Corrida multirrival concluída.")
	mastery.stop_playback()
	var player_summary: Dictionary = recording.get("summary", {})
	var player_score := int(player_summary.get("score", 0))
	live_player = player_summary.duplicate(true)
	live_standings = _build_standings(player_score)
	var position := _player_position(live_standings)
	last_result = {
		"position": position,
		"field_size": rivals.size() + 1,
		"outcome": "venceu" if position == 1 else "podio" if position <= 3 else "perdeu",
		"player": player_summary.duplicate(true),
		"rivals": _public_rivals(),
		"standings": live_standings.duplicate(true),
		"elapsed_ms": elapsed_ms(),
		"finished_unix": int(Time.get_unix_time_from_system())
	}
	active = false
	history.push_front(last_result.duplicate(true))
	if history.size() > 30:
		history.resize(30)
	_save_state()
	_sync_web_state()
	return _result(true, "Corrida concluída em %dº lugar." % position, last_result.duplicate(true))

func cancel_race() -> Dictionary:
	if not active:
		return _result(false, "Nenhuma corrida multirrival ativa.")
	var mastery := get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime
	if is_instance_valid(mastery):
		mastery.stop_recording("Corrida multirrival cancelada.")
		mastery.stop_playback()
	active = false
	last_result = {"outcome": "cancelada"}
	_sync_web_state()
	return _result(true, "Corrida multirrival cancelada.")

func elapsed_ms() -> int:
	return maxi(0, Time.get_ticks_msec() - started_ms) if active else int(last_result.get("elapsed_ms", 0))

func _refresh_live_state() -> void:
	var mastery := get_node_or_null("/root/TaijifuInputGhostMastery") as InputGhostMasteryRuntime
	if not is_instance_valid(mastery) or not mastery._recording_active:
		return
	live_player = mastery._summary_from_attempt(mastery._attempt, elapsed_ms())
	live_standings = _build_standings(int(live_player.get("score", 0)))

func _ranked_library_items(library: GhostLibraryRuntime) -> Array:
	var result: Array = []
	var ranking := get_node_or_null("/root/TaijifuGhostRivalRanking")
	var ordered_ids: Array = []
	if is_instance_valid(ranking):
		for row in ranking.ranking(100):
			if row is Dictionary:
				ordered_ids.append(String((row as Dictionary).get("id", "")))
	for id in ordered_ids:
		var index := library._index_of(String(id))
		if index >= 0:
			result.append((library.items[index] as Dictionary).duplicate(true))
	for item in library.items:
		if not item is Dictionary:
			continue
		var item_id := String((item as Dictionary).get("id", ""))
		var exists := false
		for present in result:
			if String((present as Dictionary).get("id", "")) == item_id:
				exists = true
				break
		if not exists:
			result.append((item as Dictionary).duplicate(true))
	return result

func _build_standings(player_score: int) -> Array:
	var rows: Array = [{"id": "player", "name": "Jogador", "score": player_score, "is_player": true}]
	for rival in rivals:
		var data := rival as Dictionary
		rows.append({
			"id": String(data.get("id", "")),
			"name": String(data.get("name", "Fantasma")),
			"score": int((data.get("challenge", {}) as Dictionary).get("score", 0)),
			"is_player": false
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)):
			return bool(a.get("is_player", false)) and not bool(b.get("is_player", false))
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	for index in rows.size():
		(rows[index] as Dictionary)["position"] = index + 1
	return rows

func _player_position(rows: Array) -> int:
	for row in rows:
		if row is Dictionary and bool((row as Dictionary).get("is_player", false)):
			return int((row as Dictionary).get("position", rows.size()))
	return rows.size()

func _public_rivals() -> Array:
	var output: Array = []
	for rival in rivals:
		var data := rival as Dictionary
		output.append({
			"id": String(data.get("id", "")),
			"name": String(data.get("name", "Fantasma")),
			"challenge": (data.get("challenge", {}) as Dictionary).duplicate(true),
			"is_visual_leader": output.is_empty()
		})
	return output

func current_state() -> Dictionary:
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"active": active,
		"elapsed_ms": elapsed_ms(),
		"duration_ms": duration_ms,
		"remaining_ms": maxi(0, duration_ms - elapsed_ms()) if active else 0,
		"player": live_player.duplicate(true),
		"rivals": _public_rivals(),
		"standings": live_standings.duplicate(true),
		"last_result": last_result.duplicate(true),
		"history": history.duplicate(true),
		"visual_mode": "leader_only"
	}

func command(request: Dictionary) -> Dictionary:
	match StringName(request.get("command", "get_state")):
		&"start_2": return start_top_rivals(2)
		&"start_3": return start_top_rivals(3)
		&"finish": return finish_race()
		&"cancel": return cancel_race()
	return current_state()

func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": BRIDGE_VERSION, "history": history, "last_result": last_result}, "  "))

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	history = data.get("history", [])
	last_result = data.get("last_result", {})

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
	_window.taijifuMultiGhostRaceCommand = command_callback
	_window.taijifuMultiGhostRaceState = state_callback
	_window.taijifuMultiGhostRaceReady = true
	_sync_web_state()

func _web_command(args: Array) -> String:
	var parsed = JSON.parse_string(String(args[0])) if not args.is_empty() else {"command": "get_state"}
	return JSON.stringify(command(parsed as Dictionary)) if parsed is Dictionary else JSON.stringify(_result(false, "Comando inválido."))

func _web_state(_args: Array) -> String:
	return JSON.stringify(current_state())

func _sync_web_state() -> void:
	if OS.has_feature("web") and _window != null:
		_window.taijifuMultiGhostRaceStateJson = JSON.stringify(current_state())