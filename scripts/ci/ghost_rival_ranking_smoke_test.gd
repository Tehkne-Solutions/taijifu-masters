extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	var ranking := root.get_node_or_null("TaijifuGhostRivalRanking") as GhostRivalRankingRuntime
	if not is_instance_valid(ranking):
		failures.append("Autoload TaijifuGhostRivalRanking ausente")
		_finish(failures)
		return
	ranking.entries.clear()
	ranking.processed_events.clear()
	ranking.record_series({"target_id":"rival-a","target_name":"Rival A","outcome":"venceu","best_of":5,"sweep":true,"reward":{"xp":260,"tokens":6},"finished_unix":1001})
	ranking.record_series({"target_id":"rival-b","target_name":"Rival B","outcome":"perdeu","best_of":3,"sweep":false,"reward":{"xp":35,"tokens":0},"finished_unix":1002})
	var state := ranking.current_state()
	var board: Array = state.get("leaderboard", [])
	if board.size() != 2:
		failures.append("Ranking não registrou dois rivais")
	elif String((board[0] as Dictionary).get("id", "")) != "rival-a":
		failures.append("Ordenação por rating incorreta")
	if int((ranking.public_entry("rival-a")).get("rank", 0)) != 1:
		failures.append("Posição pública do líder incorreta")
	var duplicate := ranking.record_series({"target_id":"rival-a","target_name":"Rival A","outcome":"venceu","best_of":5,"sweep":true,"reward":{"xp":260,"tokens":6},"finished_unix":1001})
	if bool(duplicate.get("ok", true)):
		failures.append("Resultado duplicado foi contabilizado")
	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GHOST_RIVAL_RANKING_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)