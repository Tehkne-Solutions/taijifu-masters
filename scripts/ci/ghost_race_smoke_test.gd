extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	var race := root.get_node_or_null("TaijifuGhostRace") as GhostRaceRuntime
	if not is_instance_valid(race):
		failures.append("Autoload TaijifuGhostRace ausente")
		_finish(failures)
		return

	race.target = {
		"id": "ghost-test",
		"name": "Desafio teste",
		"challenge": {"score": 500, "accuracy": 0.50, "max_chain": 2},
		"recording": {"duration_ms": 4000}
	}
	race.target_duration_ms = 4000
	race.started_ms = Time.get_ticks_msec() - 1000
	race.active = true
	race.live_summary = {"score": 620, "accuracy": 0.70, "max_chain": 4}
	var state := race.current_state()
	if not bool(state.get("active", false)):
		failures.append("Estado da corrida não ficou ativo")
	if int(state.get("remaining_ms", 0)) <= 0:
		failures.append("Cronômetro restante inválido")
	if int(state.get("score_delta", 0)) != 120:
		failures.append("Diferença de pontuação incorreta")
	var target: Dictionary = state.get("target", {})
	if String(target.get("id", "")) != "ghost-test":
		failures.append("Alvo selecionado não foi preservado")

	race.active = false
	race.last_result = {"outcome": "venceu", "score_delta": 120, "elapsed_ms": 4000}
	state = race.current_state()
	if String((state.get("last_result", {}) as Dictionary).get("outcome", "")) != "venceu":
		failures.append("Resultado final não foi exposto")

	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GHOST_RACE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
