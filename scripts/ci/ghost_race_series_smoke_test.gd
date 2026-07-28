extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	var series := root.get_node_or_null("TaijifuGhostRaceSeries") as GhostRaceSeriesRuntime
	if not is_instance_valid(series):
		failures.append("Autoload TaijifuGhostRaceSeries ausente")
		_finish(failures)
		return
	series.active = true
	series.best_of = 3
	series.wins_needed = 2
	series.target_id = "ghost-series"
	series.target_name = "Rival"
	series.player_wins = 0
	series.ghost_wins = 0
	series.ties = 0
	series.total_xp = 0
	series.rival_tokens = 0
	series.win_streak = 0
	series.best_win_streak = 0
	series.rivals.clear()
	series.rounds.clear()
	series.register_round({"target_id":"ghost-series","outcome":"venceu","player":{"score":700}})
	series.register_round({"target_id":"ghost-series","outcome":"venceu","player":{"score":750}})
	var state := series.current_state()
	var last: Dictionary = state.get("last_series", {})
	var progression: Dictionary = state.get("progression", {})
	var reward: Dictionary = last.get("reward", {})
	if bool(state.get("active", true)):
		failures.append("Série não terminou após duas vitórias")
	if int(last.get("player_wins", 0)) != 2:
		failures.append("Placar final incorreto")
	if String(last.get("outcome", "")) != "venceu":
		failures.append("Resultado final incorreto")
	if not bool(last.get("sweep", false)):
		failures.append("Vitória sem derrotas não foi reconhecida como varrida")
	if int(reward.get("xp", 0)) < 200:
		failures.append("Recompensa de XP da varrida não aplicada")
	if int(progression.get("rival_tokens", 0)) < 5:
		failures.append("Fichas de rival não aplicadas")
	if int(progression.get("win_streak", 0)) != 1:
		failures.append("Sequência de vitórias incorreta")
	var rival: Dictionary = progression.get("rival", {})
	if int(rival.get("series_won", 0)) != 1:
		failures.append("Registro do rival não contabilizou a série")
	if float(state.get("difficulty_multiplier", 1.0)) <= 1.0:
		failures.append("Dificuldade adaptativa não evoluiu")
	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GHOST_RACE_SERIES_PROGRESSION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)