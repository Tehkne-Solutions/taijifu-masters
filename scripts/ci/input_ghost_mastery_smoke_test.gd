extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	# Sprint 0 forbids this runtime as a permanent autoload; instantiate the
	# production class directly for its self-contained mastery contract.
	var runtime := InputGhostMasteryRuntime.new()
	runtime.name = "TaijifuInputGhostMastery"
	root.add_child(runtime)
	if not is_instance_valid(runtime):
		failures.append("InputGhostMasteryRuntime não pôde ser instanciado")
		_finish(failures)
		return

	var attempt := {
		"attempts": 8,
		"hits": 6,
		"max_chain": 4,
		"parries": 1,
		"cancels": 1,
		"link_gaps_ms": [420, 390, 450],
		"last_event": "combo teste"
	}
	var summary := runtime.summary_for_test(attempt, 4200)
	if int(summary.get("score", 0)) <= 0:
		failures.append("Pontuação técnica não foi calculada")
	if not is_equal_approx(float(summary.get("accuracy", 0.0)), 0.75):
		failures.append("Precisão da tentativa incorreta")
	if int(summary.get("max_chain", 0)) != 4:
		failures.append("Elo máximo não foi preservado")
	if float(summary.get("average_link_ms", 0.0)) <= 0.0:
		failures.append("Link médio não foi calculado")

	var weaker := summary.duplicate(true)
	weaker["score"] = int(summary.get("score", 0)) - 100
	weaker["accuracy"] = 0.50
	weaker["max_chain"] = 2
	weaker["average_link_ms"] = 610.0
	var comparison := runtime.compare_for_test(summary, weaker)
	if not bool(comparison.get("available", false)):
		failures.append("Comparação atual versus melhor indisponível")
	if float(comparison.get("deltas", {}).get("score", 0.0)) <= 0.0:
		failures.append("Delta positivo de pontuação não foi detectado")
	if not bool(comparison.get("better", false)):
		failures.append("Tentativa superior não foi marcada")

	var frames := [
		{"t": 0, "position": [100.0, 400.0], "facing": 1.0, "phase": 0, "weapon": "staff", "inputs": {"right": 1.0}},
		{"t": 180, "position": [145.0, 400.0], "facing": 1.0, "phase": 2, "weapon": "staff", "inputs": {"attack": 1.0}}
	]
	if not runtime.set_best_recording_for_test(frames, summary):
		failures.append("Melhor gravação sintética foi rejeitada")
	var state := runtime.current_state()
	if not bool(state.get("best", {}).get("available", false)):
		failures.append("Estado não expôs melhor gravação")
	if int(state.get("best", {}).get("frame_count", 0)) != 2:
		failures.append("Contagem de frames do fantasma incorreta")

	if runtime.record_challenge_for_test("tai_advancing_kick", "tai", 5, 2, 2, 620.0) != 1:
		failures.append("Desafio não alcançou Fundamento")
	if runtime.record_challenge_for_test("ji_body_hook", "ji", 12, 7, 3, 520.0) != 2:
		failures.append("Desafio não alcançou Domínio")
	if runtime.record_challenge_for_test("fu_guard_palm", "fu", 25, 18, 4, 480.0) != 3:
		failures.append("Desafio não alcançou Mestria")

	var tai_level := runtime.set_style_metrics_for_test("tai", {
		"xp": 320.0, "uses": 50, "hits": 30, "best_chain": 5,
		"best_accuracy": 0.72, "best_link_ms": 490.0, "cancels": 3
	})
	if tai_level != "master":
		failures.append("Certificação Mestre Tai não foi concedida")
	var ji_level := runtime.set_style_metrics_for_test("ji", {
		"xp": 330.0, "uses": 52, "hits": 31, "best_chain": 5,
		"best_accuracy": 0.70, "best_link_ms": 510.0, "parries": 4
	})
	if ji_level != "master":
		failures.append("Certificação Mestre Ji não foi concedida")
	runtime.record_challenge_for_test("fu_element_burst", "fu", 12, 8, 3, 500.0)
	var fu_level := runtime.set_style_metrics_for_test("fu", {
		"xp": 340.0, "uses": 55, "hits": 34, "best_chain": 5,
		"best_accuracy": 0.74, "best_link_ms": 500.0
	})
	if fu_level != "master":
		failures.append("Certificação Mestre Fu não foi concedida")

	state = runtime.current_state()
	for path_id in ["tai", "ji", "fu"]:
		if String(state.get("certifications", {}).get(path_id, {}).get("label", "")) != "MESTRE":
			failures.append("Estado não expôs certificação Mestre %s" % path_id)
	if not state.has("weapon_mastery"):
		failures.append("Ponte com maestria de arma ausente")

	runtime.free()
	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TAIJIFU CI: gravação, fantasma, desafios e certificações válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)
