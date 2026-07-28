extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	var runtime := root.get_node_or_null("TaijifuMultiGhostRace") as MultiGhostRaceRuntime
	if not is_instance_valid(runtime):
		failures.append("Autoload TaijifuMultiGhostRace ausente")
		_finish(failures)
		return
	runtime.rivals = [
		{"id":"a","name":"A","challenge":{"score":900},"recording":{"duration_ms":1000}},
		{"id":"b","name":"B","challenge":{"score":700},"recording":{"duration_ms":1000}},
		{"id":"c","name":"C","challenge":{"score":500},"recording":{"duration_ms":1000}}
	]
	var standings := runtime._build_standings(800)
	if standings.size() != 4:
		failures.append("Classificação não contém jogador e três rivais")
	if runtime._player_position(standings) != 2:
		failures.append("Posição do jogador incorreta")
	if String((standings[0] as Dictionary).get("id", "")) != "a":
		failures.append("Líder incorreto")
	var public_rivals := runtime._public_rivals()
	if not bool((public_rivals[0] as Dictionary).get("is_visual_leader", false)):
		failures.append("Fantasma visual líder não identificado")
	if bool((public_rivals[1] as Dictionary).get("is_visual_leader", true)):
		failures.append("Mais de um fantasma visual líder")
	_finish(failures)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("MULTI_GHOST_RACE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)