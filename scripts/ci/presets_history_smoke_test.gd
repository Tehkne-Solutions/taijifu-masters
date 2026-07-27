extends SceneTree

const REQUIRED := [
	"res://scripts/presets/loadout_preset_ledger.gd",
	"res://scripts/history/match_history_ledger.gd",
	"res://scripts/runtime/loadout_preset_runtime.gd",
	"res://scripts/runtime/series_statistics_runtime.gd",
	"res://scripts/runtime/match_history_runtime.gd",
	"res://scripts/arena/triple_path_environment_art.gd"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for path in REQUIRED:
		if not ResourceLoader.exists(path):
			failures.append("Recurso ausente: %s" % path)
	_validate_preset_ledger(failures)
	_validate_history_ledger(failures)
	await _validate_statistics(failures)
	await _validate_scene(failures)
	if failures.is_empty():
		print("TAIJIFU CI: presets nomeáveis, exportação, histórico, estatísticas e Ruínas visuais válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

func _validate_preset_ledger(failures: Array[String]) -> void:
	var ledger := LoadoutPresetLedger.new()
	ledger.data = {"version": 1, "profiles": {}}
	var unlocked: Array = [&"han_three_currents"]
	var loadout := BattleLoadoutCatalog.loadout_from_preset(&"adaptive_staff")
	loadout["variant_id"] = &"han_three_currents"
	var created := ledger.save_preset(
		"ci_p1",
		"Fluxo Celeste",
		loadout,
		{"arena_id": &"triple_ruins", "series_id": &"best_of_5"},
		unlocked
	)
	if String(created.get("name", "")) != "Fluxo Celeste":
		failures.append("Preset não preservou nome")
	var preset_id := String(created.get("preset_id", ""))
	if not ledger.rename_preset("ci_p1", preset_id, "Fluxo Renomeado"):
		failures.append("Preset não pôde ser renomeado")
	var exported_path := ledger.export_preset("ci_p1", preset_id)
	if exported_path == "" or not FileAccess.file_exists(exported_path):
		failures.append("Preset não foi exportado")
	else:
		var file := FileAccess.open(exported_path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		if not (parsed is Dictionary):
			failures.append("Exportação não gerou JSON válido")
		else:
			var imported := ledger.import_dictionary("ci_p2", parsed as Dictionary, unlocked)
			if not bool(imported.get("ok", false)) or ledger.preset_count("ci_p2") != 1:
				failures.append("Preset exportado não foi importado")

func _validate_history_ledger(failures: Array[String]) -> void:
	var ledger := MatchHistoryLedger.new()
	ledger.data = {"version": 1, "matches": []}
	var record := _sample_record()
	ledger.append_series(record)
	var aggregate := ledger.aggregate()
	if ledger.match_count() != 1:
		failures.append("Histórico não registrou série")
	if int(aggregate.get("rounds", 0)) != 3 or int(aggregate.get("ko_rounds", 0)) != 2:
		failures.append("Agregação de rounds ou KO está incorreta")
	if int(aggregate.get("character_wins", {}).get("kael", 0)) != 1:
		failures.append("Vitórias por personagem não foram agregadas")

func _validate_statistics(failures: Array[String]) -> void:
	var statistics := SeriesStatisticsRuntime.new()
	root.add_child(statistics)
	statistics.history.data = {"version": 1, "matches": []}
	var fighter_scene := load("res://scenes/fighter/fighter.tscn") as PackedScene
	var p1 := fighter_scene.instantiate() as FighterController
	var p2 := fighter_scene.instantiate() as FighterController
	p1.player_index = 1
	p2.player_index = 2
	root.add_child(p1)
	root.add_child(p2)
	await process_frame
	statistics.begin_series(
		CompetitiveMatchCatalog.default_config(),
		BattleLoadoutCatalog.default_loadout(1),
		BattleLoadoutCatalog.default_loadout(2)
	)
	statistics.begin_round(p1, p2, 1)
	statistics.add_test_stat(1, &"damage_dealt", 32.0)
	statistics.add_test_stat(1, &"parries", 2.0)
	statistics.complete_round(1, "KO", p1, p2)
	var stored := statistics.complete_series(2, 0, 1)
	var totals: Array = stored.get("totals", [])
	if totals.size() < 2 or not (totals[0] is Dictionary):
		failures.append("Estatísticas não produziram totais")
	elif float((totals[0] as Dictionary).get("damage_dealt", 0.0)) != 32.0:
		failures.append("Dano da série não foi acumulado")
	p1.queue_free()
	p2.queue_free()
	statistics.queue_free()
	await process_frame

func _validate_scene(failures: Array[String]) -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	for node_path in [
		"TriplePathEnvironmentArt", "LoadoutPresetRuntime",
		"SeriesStatisticsRuntime", "MatchHistoryRuntime"
	]:
		if not is_instance_valid(instance.get_node_or_null(node_path)):
			failures.append("%s não foi integrado à cena" % node_path)
	var art := instance.get_node_or_null("TriplePathEnvironmentArt") as TriplePathEnvironmentArt
	if is_instance_valid(art):
		art.configure(CompetitiveMatchCatalog.default_config(), CompetitiveMatchCatalog.resolved_arena_rules(CompetitiveMatchCatalog.default_config()))
		var signature := art.environment_signature()
		if int(signature.get("waterfalls", 0)) != 3 or bool(signature.get("competitive_collision_changes", true)):
			failures.append("Identidade visual das Ruínas possui assinatura inválida")
	var presets := instance.get_node_or_null("LoadoutPresetRuntime") as LoadoutPresetRuntime
	if is_instance_valid(presets):
		var saved := presets.save_current_for_test(1, "CI Loadout")
		if saved.is_empty() or presets.presets_for_player(1).is_empty():
			failures.append("Runtime não salvou preset da preparação")
	var history_ui := instance.get_node_or_null("MatchHistoryRuntime") as MatchHistoryRuntime
	if is_instance_valid(history_ui):
		var report := history_ui.build_result_report(_sample_record())
		if not report.contains("VENCE A SÉRIE") or not report.contains("Dano causado"):
			failures.append("Relatório final não contém estatísticas esperadas")
	instance.queue_free()
	await process_frame

func _sample_record() -> Dictionary:
	var p1 := BattleLoadoutCatalog.default_loadout(1)
	var p2 := BattleLoadoutCatalog.default_loadout(2)
	return {
		"match_id": "ci_match",
		"started_unix": 1,
		"completed_unix": 2,
		"winner_index": 1,
		"score_p1": 2,
		"score_p2": 1,
		"config": CompetitiveMatchCatalog.default_config(),
		"players": [
			{"character_id": "kael", "character_name": "Kael", "loadout": p1},
			{"character_id": "nara", "character_name": "Nara", "loadout": p2}
		],
		"rounds": [
			{"round_number": 1, "winner_index": 1, "reason": "KO", "duration_seconds": 31.0, "stats": [{"damage_dealt": 48.0, "parries": 1}, {}]},
			{"round_number": 2, "winner_index": 2, "reason": "TEMPO", "duration_seconds": 60.0, "stats": [{}, {"damage_dealt": 34.0}]},
			{"round_number": 3, "winner_index": 1, "reason": "KO", "duration_seconds": 28.0, "stats": [{"damage_dealt": 52.0, "parries": 2}, {}]}
		],
		"totals": [
			{"damage_dealt": 100.0, "posture_damage": 70.0, "hits": 8.0, "parries": 3.0},
			{"damage_dealt": 34.0, "posture_damage": 20.0, "hits": 3.0, "parries": 0.0}
		]
	}
