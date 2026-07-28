class_name GhostRaceSeriesRuntime
extends Node

const BRIDGE_VERSION := 2
const SAVE_PATH := "user://taijifu-ghost-race-series.json"
const BASE_WIN_XP := 120
const BASE_LOSS_XP := 35
const SWEEP_BONUS_XP := 80
const BEST_OF_5_BONUS_XP := 60
const BASE_WIN_TOKENS := 3

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
var total_xp := 0
var rival_tokens := 0
var win_streak := 0
var best_win_streak := 0
var rivals: Dictionary = {}
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
	var index: int = int(library._index_of(library.selected_id))
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
	_ensure_rival(target_id, target_name)
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
	var sweep := outcome == "venceu" and ghost_wins == 0
	var reward := _calculate_reward(outcome, sweep)
	_apply_reward(outcome, reward)
	last_series = {
		"target_id": target_id,
		"target_name": target_name,
		"best_of": best_of,
		"player_wins": player_wins,
		"ghost_wins": ghost_wins,
		"ties": ties,
		"outcome": outcome,
		"sweep": sweep,
		"reward": reward.duplicate(true),
		"rival": rival_record(target_id),
		"rounds": rounds.duplicate(true),
		"finished_unix": int(Time.get_unix_time_from_system())
	}
	active = false

func _calculate_reward(outcome: String, sweep: bool) -> Dictionary:
	var xp := BASE_WIN_XP if outcome == "venceu" else BASE_LOSS_XP
	var tokens := BASE_WIN_TOKENS if outcome == "venceu" else 0
	if best_of == 5:
		xp += BEST_OF_5_BONUS_XP
		tokens += 1 if outcome == "venceu" else 0
	if sweep:
		xp += SWEEP_BONUS_XP
		tokens += 2
	var streak_bonus := mini(100, win_streak * 10) if outcome == "venceu" else 0
	xp += streak_bonus
	return {
		"xp": xp,
		"tokens": tokens,
		"streak_bonus_xp": streak_bonus,
		"sweep_bonus_xp": SWEEP_BONUS_XP if sweep else 0,
		"format_bonus_xp": BEST_OF_5_BONUS_XP if best_of == 5 else 0
	}

func _apply_reward(outcome: String, reward: Dictionary) -> void:
	_ensure_rival(target_id, target_name)
	var rival: Dictionary = rivals[target_id]
	rival["series_played"] = int(rival.get("series_played", 0)) + 1
	if outcome == "venceu":
		win_streak += 1
		best_win_streak = maxi(best_win_streak, win_streak)
		rival["series_won"] = int(rival.get("series_won", 0)) + 1
	else:
		win_streak = 0
		rival["series_lost"] = int(rival.get("series_lost", 0)) + 1
	var earned_xp := int(reward.get("xp", 0))
	var earned_tokens := int(reward.get("tokens", 0))
	total_xp += earned_xp
	rival_tokens += earned_tokens
	rival["xp"] = int(rival.get("xp", 0)) + earned_xp
	rival["tokens_earned"] = int(rival.get("tokens_earned", 0)) + earned_tokens
	rival["level"] = _level_from_xp(int(rival.get("xp", 0)))
	rival["best_player_wins"] = maxi(int(rival.get("best_player_wins", 0)), player_wins)
	rival["last_outcome"] = outcome
	rival["updated_unix"] = int(Time.get_unix_time_from_system())
	rivals[target_id] = rival

func difficulty_multiplier() -> float:
	var rival := rival_record(target_id)
	var level := int(rival.get("level", 1))
	var round_step: float = float(maxi(0, rounds.size())) * 0.03
	return minf(1.75, 1.0 + float(level - 1) * 0.05 + round_step)

func adjusted_target_score(base_score: int) -> int:
	return int(round(float(base_score) * difficulty_multiplier()))

func rival_record(id: String) -> Dictionary:
	if id.is_empty() or not rivals.has(id):
		return {}
	return (rivals[id] as Dictionary).duplicate(true)

func _ensure_rival(id: String, name: String) -> void:
	if id.is_empty():
		return
	if rivals.has(id):
		var existing: Dictionary = rivals[id]
		existing["name"] = name
		rivals[id] = existing
		return
	rivals[id] = {
		"id": id,
		"name": name,
		"level": 1,
		"xp": 0,
		"series_played": 0,
		"series_won": 0,
		"series_lost": 0,
		"tokens_earned": 0,
		"best_player_wins": 0,
		"last_outcome": "",
		"updated_unix": 0
	}

func _level_from_xp(value: int) -> int:
	return maxi(1, int(floor(sqrt(float(maxi(0, value)) / 100.0))) + 1)

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
		"difficulty_multiplier": difficulty_multiplier(),
		"progression": {
			"total_xp": total_xp,
			"rival_tokens": rival_tokens,
			"win_streak": win_streak,
			"best_win_streak": best_win_streak,
			"rival": rival_record(target_id)
		},
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
	var progression: Dictionary = data.get("progression", {})
	total_xp = int(progression.get("total_xp", 0))
	rival_tokens = int(progression.get("rival_tokens", 0))
	win_streak = int(progression.get("win_streak", 0))
	best_win_streak = int(progression.get("best_win_streak", 0))
	var persisted_rival: Dictionary = progression.get("rival", {})
	if not persisted_rival.is_empty():
		rivals[String(persisted_rival.get("id", target_id))] = persisted_rival

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
