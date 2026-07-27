extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	_validate_season_ledger(failures)
	_validate_history_seasons(failures)
	_validate_group_stage(failures)
	await _validate_scene_runtimes(failures)
	if failures.is_empty():
		print("TAIJIFU CI: temporadas, comparação de perfis e fase de grupos válidas.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

func _validate_season_ledger(failures: Array[String]) -> void:
	var ledger := CompetitiveSeasonLedger.new()
	ledger.data = CompetitiveSeasonLedger.default_state()
	var alpha := ledger.create_season("  Temporada   Alpha  ")
	if String(alpha.get("name", "")) != "Temporada Alpha":
		failures.append("Nome da temporada não foi sanitizado")
	var alpha_id := String(alpha.get("season_id", ""))
	var beta := ledger.create_season("Temporada Beta")
	if beta.is_empty() or String(ledger.active_context().get("season_name", "")) != "Temporada Beta":
		failures.append("Nova temporada não foi ativada")
	if String(beta.get("season_id", "")) == alpha_id:
		failures.append("Temporadas consecutivas receberam IDs duplicados")
	if not ledger.activate(alpha_id):
		failures.append("Temporada anterior não pôde ser reativada")
	elif String(ledger.active_context().get("season_id", "")) != alpha_id:
		failures.append("Contexto ativo da temporada está incorreto")
	var alpha_state := ledger.season_by_id(alpha_id)
	if String(alpha_state.get("status", "")) != "active":
		failures.append("Status da temporada reativada está incorreto")
	var closed := ledger.close_active()
	if closed.is_empty() or String(ledger.active_context().get("season_id", "")) != CompetitiveSeasonLedger.OFFSEASON_ID:
		failures.append("Encerramento da temporada não entrou em fora de temporada")
	if String(ledger.season_by_id(alpha_id).get("status", "")) != "closed":
		failures.append("Temporada encerrada voltou ao estado ativo")
	if not ledger.activate(alpha_id):
		failures.append("Temporada encerrada não pôde ser reativada")

func _validate_history_seasons(failures: Array[String]) -> void:
	var history := MatchHistoryLedger.new()
	history.data = {"version": MatchHistoryLedger.VERSION, "matches": []}
	history.append_series(_record("season_a_1", "season_alpha", "Temporada Alpha", "profile_alpha", "Alpha", "profile_beta", "Beta", 1))
	history.append_series(_record("season_a_2", "season_alpha", "Temporada Alpha", "profile_beta", "Beta", "profile_alpha", "Alpha", 2))
	history.append_series(_record("season_b_1", "season_beta", "Temporada Beta", "profile_alpha", "Alpha", "profile_gamma", "Gamma", 1))
	if history.filtered({"season_id": "season_alpha"}, 0).size() != 2:
		failures.append("Filtro da Temporada Alpha está incorreto")
	if history.filtered({"season_id": "season_beta"}, 0).size() != 1:
		failures.append("Filtro da Temporada Beta está incorreto")
	if history.filtered({"season_id": "season_alpha", "text_query": "beta"}, 0).size() != 2:
		failures.append("Busca textual não combinou com temporada")
	var aggregate := history.aggregate({"season_id": "season_alpha"})
	if int(aggregate.get("series", 0)) != 2 or int(aggregate.get("rounds", 0)) != 4:
		failures.append("Agregação sazonal está incorreta")
	var legacy := history.append_series(_legacy_record())
	if String(legacy.get("season_id", "")) != "season_legacy":
		failures.append("Registro legado não recebeu temporada de migração")

func _validate_group_stage(failures: Array[String]) -> void:
	var ledger := GroupStageLedger.new()
	ledger.data = GroupStageLedger.default_state()
	var participants := _participants()
	if not ledger.set_participants(participants) or not ledger.start():
		failures.append("Fase de grupos não iniciou com oito participantes")
		return
	if ledger.all_matches().size() != 12:
		failures.append("Fase de grupos não criou doze confrontos")
	for index in range(12):
		var current := ledger.current_match()
		if current.is_empty():
			failures.append("Confronto %d da fase de grupos está vazio" % (index + 1))
			return
		var result := ledger.record_result(1, 2, 0)
		if not bool(result.get("ok", false)):
			failures.append("Resultado %d da fase de grupos foi rejeitado" % (index + 1))
			return
	if not ledger.is_finished():
		failures.append("Fase de grupos não foi concluída após doze séries")
	var group_a := ledger.standings("A")
	var group_b := ledger.standings("B")
	if group_a.size() != 4 or group_b.size() != 4:
		failures.append("Classificação dos grupos não possui quatro competidores")
	if group_a.is_empty() or int(group_a[0].get("points", 0)) < int(group_a[3].get("points", 0)):
		failures.append("Ordenação do Grupo A está incorreta")
	var qualifiers := ledger.qualifiers()
	if qualifiers.size() != 4:
		failures.append("Fase de grupos não classificou quatro competidores")
	var semifinalists := ledger.semifinal_participants()
	if semifinalists.size() != 4:
		failures.append("Semifinais cruzadas não foram formadas")
	else:
		var labels: Array[String] = []
		for participant in semifinalists:
			labels.append(String(participant.get("qualification", "")))
		if labels != ["A1", "B1", "A2", "B2"]:
			failures.append("Ordem dos classificados não preservou A1×B2 e B1×A2")
		var knockout := TournamentLedger.new()
		if not knockout.set_participants(semifinalists) or not knockout.start():
			failures.append("Classificados não iniciaram o mata-mata")
		else:
			var pair := knockout.current_pair()
			if pair.size() != 2 or String(pair[0].get("qualification", "")) != "A1" or String(pair[1].get("qualification", "")) != "B2":
				failures.append("Primeira semifinal não foi formada como A1×B2")
			if pair.size() == 2 and (String(pair[0].get("profile_id", "")) == "" or String(pair[1].get("profile_id", "")) == ""):
				failures.append("Mata-mata descartou a identidade dos perfis classificados")

func _validate_scene_runtimes(failures: Array[String]) -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(scene):
		failures.append("Cena principal não pôde ser carregada")
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var seasons := instance.get_node_or_null("CompetitiveSeasonRuntime") as CompetitiveSeasonRuntime
	var profiles := instance.get_node_or_null("ProfileComparisonRuntime") as ProfileComparisonRuntime
	var groups := instance.get_node_or_null("GroupStageRuntime") as GroupStageRuntime
	var statistics := instance.get_node_or_null("SeriesStatisticsRuntime") as SeriesStatisticsRuntime
	if not is_instance_valid(seasons): failures.append("CompetitiveSeasonRuntime ausente")
	if not is_instance_valid(profiles): failures.append("ProfileComparisonRuntime ausente")
	if not is_instance_valid(groups): failures.append("GroupStageRuntime ausente")
	if not is_instance_valid(statistics): failures.append("SeriesStatisticsRuntime ausente")
	if is_instance_valid(statistics):
		statistics.history.data = {
			"version": MatchHistoryLedger.VERSION,
			"matches": [
				_record("scene_1", "season_scene", "Temporada Cena", "profile_alpha", "Alpha", "profile_beta", "Beta", 1),
				_record("scene_2", "season_scene", "Temporada Cena", "profile_beta", "Beta", "profile_alpha", "Alpha", 2),
				_record("scene_3", "season_other", "Outra", "profile_alpha", "Alpha", "profile_gamma", "Gamma", 1)
			]
		}
		statistics.begin_series(
			{"arena_id": &"triple_ruins", "series_id": &"best_of_3", "time_id": &"sixty", "modifier_id": &"classic"},
			BattleLoadoutCatalog.loadout_from_preset(&"adaptive_staff"),
			BattleLoadoutCatalog.loadout_from_preset(&"rock_guardian"),
			{"profile_id": "profile_alpha", "profile_name": "Alpha"},
			{"profile_id": "profile_beta", "profile_name": "Beta"},
			{"season_id": "season_scene", "season_name": "Temporada Cena"}
		)
		var snapshot := statistics.current_series_snapshot()
		if String(snapshot.get("season_id", "")) != "season_scene":
			failures.append("Série atual não preservou a temporada")
	if is_instance_valid(profiles) and is_instance_valid(statistics):
		var entries := profiles.profile_entries("season_scene")
		if entries.size() != 2:
			failures.append("Comparação sazonal não encontrou dois perfis")
		var direct := profiles.head_to_head("profile_alpha", "profile_beta", "season_scene")
		if int(direct.get("series", 0)) != 2:
			failures.append("Confronto direto não encontrou as duas séries")
		var report := profiles.build_comparison_report("profile_alpha", "profile_beta", "season_scene")
		if not report.contains("CONFRONTO DIRETO") or not report.contains("TEMPORADA ATIVA"):
			failures.append("Relatório de comparação entre perfis está incompleto")
	if is_instance_valid(seasons) and is_instance_valid(statistics):
		seasons.ledger.data = {
			"version": CompetitiveSeasonLedger.VERSION,
			"active_season_id": "season_scene",
			"seasons": [{"season_id": "season_scene", "name": "Temporada Cena", "created_unix": 1, "closed_unix": 0, "status": "active"}]
		}
		var seasonal_entries := seasons.season_profile_entries("season_scene")
		if seasonal_entries.size() != 2:
			failures.append("Ranking sazonal não encontrou dois perfis")
		elif int(seasonal_entries[0].get("wins", 0)) < int(seasonal_entries[1].get("wins", 0)):
			failures.append("Ranking sazonal não foi ordenado por desempenho")
	instance.queue_free()
	await process_frame

func _participants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var presets: Array[StringName] = [&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger", &"aerial_flow", &"foundation_breaker", &"adaptive_staff", &"rock_guardian"]
	for index in range(8):
		result.append({
			"participant_id": "group_p%d" % (index + 1),
			"name": "COMPETIDOR %d" % (index + 1),
			"profile_id": "profile_%d" % (index + 1),
			"profile_name": "JOGADOR %d" % (index + 1),
			"loadout": BattleLoadoutCatalog.loadout_from_preset(presets[index]),
			"source": "ci"
		})
	return result

func _record(match_id: String, season_id: String, season_name: String, p1_id: String, p1_name: String, p2_id: String, p2_name: String, winner_index: int) -> Dictionary:
	return {
		"match_id": match_id,
		"started_unix": 10,
		"completed_unix": 20,
		"season_id": season_id,
		"season_name": season_name,
		"winner_index": winner_index,
		"score_p1": 2 if winner_index == 1 else 1,
		"score_p2": 2 if winner_index == 2 else 1,
		"config": {"arena_id": &"triple_ruins", "series_id": &"best_of_3", "time_id": &"sixty", "modifier_id": &"classic"},
		"players": [
			{"player_index": 1, "profile_id": p1_id, "profile_name": p1_name, "character_id": "kael", "character_name": "Kael", "build_name": "Build A", "loadout": BattleLoadoutCatalog.loadout_from_preset(&"adaptive_staff")},
			{"player_index": 2, "profile_id": p2_id, "profile_name": p2_name, "character_id": "nara", "character_name": "Nara", "build_name": "Build B", "loadout": BattleLoadoutCatalog.loadout_from_preset(&"rock_guardian")}
		],
		"rounds": [
			{"round_number": 1, "winner_index": winner_index, "reason": "KO", "duration_seconds": 35.0, "stats": [{"damage_dealt": 80.0, "parries": 2.0}, {"damage_dealt": 55.0, "parries": 1.0}], "highlights": [], "resources": [{}, {}]},
			{"round_number": 2, "winner_index": winner_index, "reason": "KO", "duration_seconds": 32.0, "stats": [{"damage_dealt": 70.0, "posture_breaks": 1.0}, {"damage_dealt": 45.0, "disarms": 1.0}], "highlights": [], "resources": [{}, {}]}
		],
		"totals": [
			{"damage_dealt": 150.0, "parries": 2.0, "posture_breaks": 1.0, "disarms": 0.0},
			{"damage_dealt": 100.0, "parries": 1.0, "posture_breaks": 0.0, "disarms": 1.0}
		],
		"favorite": false,
		"tags": []
	}

func _legacy_record() -> Dictionary:
	var record := _record("legacy", "", "", "legacy_a", "Legado A", "legacy_b", "Legado B", 1)
	record.erase("season_id")
	record.erase("season_name")
	return record
