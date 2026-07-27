extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	for path in [
		"res://scripts/match/competitive_match_catalog.gd",
		"res://scripts/runtime/competitive_match_runtime.gd",
		"res://scripts/runtime/competitive_arena_runtime.gd",
		"res://scripts/runtime/vs_analysis_runtime.gd",
		"res://scripts/competitive_main.gd"
	]:
		if not ResourceLoader.exists(path):
			failures.append("Recurso competitivo ausente: %s" % path)
	failures.append_array(CompetitiveMatchCatalog.validate())

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(main_scene):
		failures.append("Cena principal competitiva não carregou")
	else:
		var instance := main_scene.instantiate()
		root.add_child(instance)
		await process_frame
		await process_frame
		var match_runtime := instance.get_node_or_null("CompetitiveMatchRuntime") as CompetitiveMatchRuntime
		var arena_runtime := instance.get_node_or_null("CompetitiveArenaRuntime") as CompetitiveArenaRuntime
		var vs_runtime := instance.get_node_or_null("VsAnalysisRuntime") as VsAnalysisRuntime
		if not is_instance_valid(match_runtime) or not is_instance_valid(arena_runtime) or not is_instance_valid(vs_runtime):
			failures.append("Runtimes competitivos não foram integrados à cena")
		else:
			_validate_match_runtime(match_runtime, failures)
			_validate_arena_runtime(arena_runtime, failures)
			_validate_vs_runtime(vs_runtime, failures)
		instance.queue_free()
		await process_frame

	if failures.is_empty():
		print("TAIJIFU CI: arenas, regras, séries, placar, tempo e análise VS válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU COMPETITIVE CI: %s" % failure)
	quit(1)

func _validate_match_runtime(runtime: CompetitiveMatchRuntime, failures: Array[String]) -> void:
	var p1 := BattleLoadoutCatalog.loadout_from_preset(&"adaptive_staff")
	var p2 := BattleLoadoutCatalog.loadout_from_preset(&"rock_guardian")
	runtime.set_config_for_test({"arena_id": &"triple_ruins", "series_id": &"best_of_3", "time_id": &"ninety", "modifier_id": &"classic"})
	runtime.begin_series(p1, p2)
	var first := runtime.record_round(1, "KO")
	if bool(first.get("match_over", true)):
		failures.append("Melhor de 3 encerrou após uma vitória")
	var second := runtime.record_round(1, "KO")
	if not bool(second.get("match_over", false)) or int(second.get("score_p1", 0)) != 2:
		failures.append("Melhor de 3 não encerrou em duas vitórias")
	runtime.set_config_for_test({"arena_id": &"ember_crucible", "series_id": &"best_of_5", "time_id": &"sixty", "modifier_id": &"unstable_flux"})
	if CompetitiveMatchCatalog.target_wins(runtime.current_config()) != 3:
		failures.append("Melhor de 5 não exige três vitórias")
	if CompetitiveMatchCatalog.round_seconds(runtime.current_config()) != 60.0:
		failures.append("Tempo de 60 segundos não foi resolvido")
	runtime.reset_series()

func _validate_arena_runtime(runtime: CompetitiveArenaRuntime, failures: Array[String]) -> void:
	var rules := CompetitiveMatchCatalog.resolved_arena_rules({"arena_id": &"silent_sanctuary", "series_id": &"best_of_3", "time_id": &"unlimited", "modifier_id": &"pure_duel"})
	runtime.configure(rules)
	runtime.prepare_round()
	if bool(runtime.current_rules().get("closure_enabled", true)):
		failures.append("Duelo Puro manteve fechamento ativo")
	if bool(runtime.current_rules().get("manifestations_enabled", true)):
		failures.append("Duelo Puro manteve manifestações ativas")
	runtime.start_round()
	if not runtime.is_round_active():
		failures.append("Runtime de arena não iniciou o round")
	runtime.stop_round()

func _validate_vs_runtime(runtime: VsAnalysisRuntime, failures: Array[String]) -> void:
	var p1 := BattleLoadoutCatalog.loadout_from_preset(&"rin_challenger")
	var p2 := BattleLoadoutCatalog.loadout_from_preset(&"lyra_elementalist")
	var report := runtime.build_report(p1, p2, CompetitiveMatchCatalog.default_config())
	if String(report.get("headline", "")).find("RIN") < 0 or String(report.get("headline", "")).find("LYRA") < 0:
		failures.append("Tela VS não identificou os personagens")
	for key in ["p1_strengths", "p1_risks", "p2_strengths", "p2_risks"]:
		var values: Variant = report.get(key, [])
		if not (values is Array) or (values as Array).is_empty():
			failures.append("Análise VS não gerou %s" % key)
