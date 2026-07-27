extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	_validate_profile_ledger(failures)
	_validate_search_and_ranking(failures)
	_validate_comparison(failures)
	_validate_png_export(failures)
	await _validate_scene(failures)
	if failures.is_empty():
		print("TAIJIFU CI: perfis, busca, comparação e PNG válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

func _validate_profile_ledger(failures: Array[String]) -> void:
	var ledger := PlayerProfileLedger.new()
	ledger.data = PlayerProfileLedger.default_state()
	var alpha := ledger.create_profile("  Alpha   Mestre  ")
	var beta := ledger.create_profile("Beta")
	if String(alpha.get("name", "")) != "Alpha Mestre":
		failures.append("Nome de perfil não foi sanitizado")
	if alpha.is_empty() or beta.is_empty():
		failures.append("Perfis adicionais não foram criados")
	elif not ledger.set_active(1, String(alpha.get("profile_id", ""))):
		failures.append("Perfil Alpha não pôde ser ativado no P1")
	elif String(ledger.active_profile(1).get("name", "")) != "Alpha Mestre":
		failures.append("Perfil ativo do P1 está incorreto")
	if ledger.delete_profile("profile_p1"):
		failures.append("Perfil padrão protegido foi removido")

func _validate_search_and_ranking(failures: Array[String]) -> void:
	var history := MatchHistoryLedger.new()
	history.clear()
	var first := _record("search_a", "alpha_profile", "Alpha Mestre", "kael", "Kael", "nara", "Nara", &"ember_crucible", 1, "Aparo técnico no Crisol")
	var second := _record("search_b", "alpha_profile", "Alpha Mestre", "lyra", "Lyra", "rin", "Rin", &"silent_sanctuary", 2, "Interação elemental de água")
	history.append_series(first)
	history.append_series(second)
	if history.filtered({"text_query": "alpha mestre"}, 0).size() != 2:
		failures.append("Busca por perfil não encontrou as duas séries")
	if history.filtered({"text_query": "crisol"}, 0).size() != 1:
		failures.append("Busca por arena não encontrou a série correta")
	if history.filtered({"text_query": "aparo"}, 0).size() != 1:
		failures.append("Busca por destaque técnico falhou")
	if history.filtered({"text_query": "alpha", "arena_id": &"silent_sanctuary"}, 0).size() != 1:
		failures.append("Busca textual não combinou com filtro de arena")

func _validate_comparison(failures: Array[String]) -> void:
	var comparison := SeriesComparisonRuntime.new()
	var left := _record("compare_a", "profile_a", "Jogador A", "kael", "Kael", "nara", "Nara", &"triple_ruins", 1, "Quebra de postura")
	var right := _record("compare_b", "profile_b", "Jogador B", "lyra", "Lyra", "rin", "Rin", &"silent_sanctuary", 2, "Desarme decisivo")
	var summary_left := comparison.summarize(left)
	var report := comparison.build_report(left, right)
	if String(summary_left.get("profile_p1", "")) != "Jogador A":
		failures.append("Comparador não preservou o perfil")
	if not report.contains("COMPARAÇÃO ENTRE SÉRIES") or not report.contains("SÉRIE A"):
		failures.append("Relatório comparativo não foi construído")

func _validate_png_export(failures: Array[String]) -> void:
	var ledger := TournamentLedger.new()
	ledger.reset(4)
	var participants: Array[Dictionary] = []
	for index in range(4):
		participants.append({
			"participant_id": "png_%d" % index,
			"name": "PNG %d" % (index + 1),
			"seed": index + 1,
			"loadout": BattleLoadoutCatalog.loadout_from_preset([&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger"][index]),
			"source": "ci"
		})
	if not ledger.set_participants(participants) or not ledger.start():
		failures.append("Chaveamento para PNG não foi criado")
		return
	var result := TournamentBracketExporter.export_snapshot(ledger.bracket_snapshot())
	if not bool(result.get("ok", false)):
		failures.append("Exportação PNG falhou: %s" % String(result.get("error", "erro")))
		return
	var png_path := String(result.get("png_path", ""))
	if png_path == "" or not FileAccess.file_exists(png_path):
		failures.append("Arquivo PNG não foi criado")
		return
	var bytes := FileAccess.get_file_as_bytes(png_path)
	if bytes.size() < 8 or bytes[0] != 137 or bytes[1] != 80 or bytes[2] != 78 or bytes[3] != 71:
		failures.append("Arquivo exportado não possui assinatura PNG")
	if int(result.get("png_width", 0)) <= 0 or int(result.get("png_height", 0)) <= 0:
		failures.append("Dimensões do PNG são inválidas")

func _validate_scene(failures: Array[String]) -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(scene):
		failures.append("Cena principal não pôde ser carregada")
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var profiles := instance.get_node_or_null("PlayerProfileRuntime") as PlayerProfileRuntime
	var comparison := instance.get_node_or_null("SeriesComparisonRuntime") as SeriesComparisonRuntime
	var ranking := instance.get_node_or_null("LocalRankingRuntime") as LocalRankingRuntime
	var history_runtime := instance.get_node_or_null("MatchHistoryRuntime") as MatchHistoryRuntime
	if not is_instance_valid(profiles): failures.append("PlayerProfileRuntime ausente")
	if not is_instance_valid(comparison): failures.append("SeriesComparisonRuntime ausente")
	if not is_instance_valid(ranking): failures.append("LocalRankingRuntime ausente")
	if not is_instance_valid(history_runtime): failures.append("MatchHistoryRuntime ausente")
	if is_instance_valid(profiles):
		var gamma := profiles.create_profile_for_test("Gamma")
		if gamma.is_empty() or not profiles.set_active_for_test(2, String(gamma.get("profile_id", ""))):
			failures.append("Runtime de perfil não ativou Gamma")
	if is_instance_valid(history_runtime):
		history_runtime.set_filters_for_test({"text_query": "alpha"})
		if String(history_runtime.current_filters().get("text_query", "")) != "alpha":
			failures.append("Runtime do histórico não preservou a busca")
	instance.queue_free()
	await process_frame

func _record(
	match_id: String,
	profile_id: String,
	profile_name: String,
	p1_character_id: String,
	p1_character_name: String,
	p2_character_id: String,
	p2_character_name: String,
	arena_id: StringName,
	winner_index: int,
	highlight_label: String
) -> Dictionary:
	return {
		"match_id": match_id,
		"started_unix": 10,
		"completed_unix": 20,
		"winner_index": winner_index,
		"score_p1": 2 if winner_index == 1 else 1,
		"score_p2": 2 if winner_index == 2 else 1,
		"config": {"arena_id": arena_id, "series_id": &"best_of_3", "time_id": &"sixty", "modifier_id": &"classic"},
		"players": [
			{"player_index": 1, "profile_id": profile_id, "profile_name": profile_name, "character_id": p1_character_id, "character_name": p1_character_name, "build_name": "Build A", "loadout": BattleLoadoutCatalog.loadout_from_preset(&"adaptive_staff")},
			{"player_index": 2, "profile_id": "%s_rival" % profile_id, "profile_name": "Rival", "character_id": p2_character_id, "character_name": p2_character_name, "build_name": "Build B", "loadout": BattleLoadoutCatalog.loadout_from_preset(&"rock_guardian")}
		],
		"rounds": [
			{"round_number": 1, "winner_index": winner_index, "reason": "KO", "duration_seconds": 42.5, "stats": [{"damage_dealt": 80.0, "parries": 2.0}, {"damage_dealt": 55.0, "parries": 1.0}], "highlights": [{"time_seconds": 12.0, "player_index": winner_index, "event_id": "technical", "label": highlight_label, "value": 1.0}], "resources": [{}, {}]}
		],
		"totals": [
			{"damage_dealt": 80.0, "parries": 2.0, "posture_breaks": 1.0, "disarms": 0.0},
			{"damage_dealt": 55.0, "parries": 1.0, "posture_breaks": 0.0, "disarms": 1.0}
		],
		"favorite": false,
		"tags": []
	}
