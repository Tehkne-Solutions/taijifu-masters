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
	series.rounds.clear()
	series.register_round({"target_id":"ghost-series","outcome":"venceu","player":{"score":700}})
	series.register_round({"target_id":"ghost-series","outcome":"venceu","player":{"score":750}})
	var state := series.current_state()
	if bool(state.get("active", true)):
		failures.append("Série não terminou após duas vitórias")
	if int((state.get("last_series", {}) as Dictionary).get("player_wins", 0)) != 2:
		failures.append("Placar final incorreto")
	if String((state.get("last_series", {}) as Dictionary).get("outcome", "")) != "venceu":
		failures.append("Resultado final incorreto")
	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GHOST_RACE_SERIES_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)