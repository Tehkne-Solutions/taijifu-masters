extends SceneTree

## Ghost Rival Ranking is intentionally not an autoload in the Sprint 0 First
## Playable budget. This smoke validates the runtime directly without silently
## reintroducing a retired global singleton.
## Tehkné Solutions

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	if root.get_node_or_null("TaijifuGhostRivalRanking") != null:
		failures.append("Autoload TaijifuGhostRivalRanking não deveria estar ativo no Sprint 0")
		_finish(failures, null)
		return

	var ranking := GhostRivalRankingRuntime.new()
	if not is_instance_valid(ranking):
		failures.append("GhostRivalRankingRuntime não pôde ser instanciado")
		_finish(failures, ranking)
		return

	# Keep the smoke deterministic and independent from any previous user:// state.
	ranking.entries.clear()
	ranking.processed_events.clear()
	ranking.last_updated_unix = 0

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

	_finish(failures, ranking)

func _finish(failures: Array[String], ranking: GhostRivalRankingRuntime) -> void:
	if is_instance_valid(ranking):
		ranking.free()
	# The runtime writes its isolated smoke state to user:// through production
	# persistence code; remove it so repeated CI runs remain deterministic.
	if FileAccess.file_exists(GhostRivalRankingRuntime.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GhostRivalRankingRuntime.SAVE_PATH))
	if failures.is_empty():
		print("GHOST_RIVAL_RANKING_SMOKE_OK mode=direct_runtime autoload=false")
		print("SIGNATURE=Tehkné Solutions")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
