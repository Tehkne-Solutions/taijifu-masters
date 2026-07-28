extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	var history := root.get_node_or_null("TaijifuGhostRaceHistory") as GhostRaceHistoryRuntime
	if not is_instance_valid(history):
		failures.append("Autoload TaijifuGhostRaceHistory ausente")
		_finish(failures)
		return
	history.records.clear()
	history.record_result({"target_id":"ghost-a","outcome":"venceu","player":{"score":700,"accuracy":0.75,"max_chain":5},"score_delta":120,"elapsed_ms":4000})
	history.record_result({"target_id":"ghost-a","outcome":"perdeu","player":{"score":520,"accuracy":0.55,"max_chain":3},"score_delta":-60,"elapsed_ms":4000})
	var record := history.public_record("ghost-a")
	if int(record.get("attempts", 0)) != 2:
		failures.append("Quantidade de tentativas incorreta")
	if int(record.get("wins", 0)) != 1 or int(record.get("losses", 0)) != 1:
		failures.append("Vitórias e derrotas não foram contabilizadas")
	if int(record.get("best_score", 0)) != 700:
		failures.append("Melhor pontuação não foi preservada")
	if absf(float(record.get("win_rate", 0.0)) - 0.5) > 0.001:
		failures.append("Taxa de vitória incorreta")
	if (record.get("recent", []) as Array).size() != 2:
		failures.append("Histórico recente não foi armazenado")
	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GHOST_RACE_HISTORY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
