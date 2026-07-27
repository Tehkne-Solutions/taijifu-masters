extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	_validate_share_codes(failures)
	_validate_tournament_ledger(failures)
	await _validate_scene_runtime(failures)
	if failures.is_empty():
		print("TAIJIFU CI: arenas, códigos compactos e torneio válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

func _validate_share_codes(failures: Array[String]) -> void:
	var loadout := BattleLoadoutCatalog.loadout_from_preset(&"lyra_elementalist")
	loadout["element_id"] = &"water"
	var preset := {
		"name": "LYRA TESTE",
		"loadout": loadout,
		"match_config": {
			"arena_id": &"silent_sanctuary",
			"series_id": &"best_of_3",
			"time_id": &"sixty",
			"modifier_id": &"classic"
		}
	}
	var code := LoadoutShareCode.encode_preset(preset)
	if not code.begins_with("TJF1."):
		failures.append("Código compacto não possui prefixo TJF1")
	var decoded := LoadoutShareCode.decode_code(code)
	if not bool(decoded.get("ok", false)):
		failures.append("Código compacto não completou round-trip: %s" % String(decoded.get("error", "erro")))
	else:
		var decoded_preset: Dictionary = decoded.get("preset", {})
		var decoded_loadout: Dictionary = decoded_preset.get("loadout", {})
		var decoded_config: Dictionary = decoded_preset.get("match_config", {})
		if StringName(decoded_loadout.get("preset_id", &"")) != &"lyra_elementalist":
			failures.append("Código não preservou o personagem/build")
		if StringName(decoded_config.get("arena_id", &"")) != &"silent_sanctuary":
			failures.append("Código não preservou a arena")
	var corrupted := code.left(maxi(0, code.length() - 1)) + ("a" if code.right(1) != "a" else "b")
	if bool(LoadoutShareCode.decode_code(corrupted).get("ok", false)):
		failures.append("Código corrompido foi aceito")

func _validate_tournament_ledger(failures: Array[String]) -> void:
	var ledger := TournamentLedger.new()
	ledger.reset()
	var participants: Array[Dictionary] = []
	var presets: Array[StringName] = [&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger"]
	for index in range(4):
		participants.append({
			"participant_id": "p%d" % (index + 1),
			"name": "COMPETIDOR %d" % (index + 1),
			"loadout": BattleLoadoutCatalog.loadout_from_preset(presets[index]),
			"source": "ci"
		})
	if not ledger.set_participants(participants) or not ledger.start():
		failures.append("Torneio não iniciou com quatro participantes")
		return
	var first_pair := ledger.current_pair()
	if first_pair.size() != 2 or String(first_pair[0].get("name", "")) != "COMPETIDOR 1":
		failures.append("Semifinal A inválida")
	var result_a := ledger.record_winner(1)
	if not bool(result_a.get("ok", false)) or ledger.stage_label() != "SEMIFINAL B":
		failures.append("Avanço da semifinal A falhou")
	var result_b := ledger.record_winner(2)
	if not bool(result_b.get("ok", false)) or ledger.stage_label() != "FINAL":
		failures.append("Avanço da semifinal B falhou")
	var final_pair := ledger.current_pair()
	if final_pair.size() != 2:
		failures.append("Final não foi formada")
	var final_result := ledger.record_winner(2)
	if not bool(final_result.get("finished", false)):
		failures.append("Final não encerrou o torneio")
	if String(ledger.champion().get("name", "")) != "COMPETIDOR 4":
		failures.append("Campeão do torneio incorreto")

func _validate_scene_runtime(failures: Array[String]) -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(scene):
		failures.append("Cena principal não pôde ser carregada")
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var arena_runtime := instance.get_node_or_null("CompetitiveArenaRuntime") as CompetitiveArenaRuntime
	var share_runtime := instance.get_node_or_null("LoadoutShareCodeRuntime") as LoadoutShareCodeRuntime
	var tournament_runtime := instance.get_node_or_null("TournamentRuntime") as TournamentRuntime
	if not is_instance_valid(arena_runtime):
		failures.append("CompetitiveArenaRuntime ausente")
	if not is_instance_valid(share_runtime):
		failures.append("LoadoutShareCodeRuntime ausente")
	if not is_instance_valid(tournament_runtime):
		failures.append("TournamentRuntime ausente")
	if is_instance_valid(arena_runtime):
		var signatures := arena_runtime.environment_signatures()
		var ids: Array[StringName] = []
		for signature in signatures:
			ids.append(StringName(signature.get("arena_id", &"")))
			if bool(signature.get("competitive_collision_changes", true)):
				failures.append("Arte de arena declarou mudança competitiva")
		for expected in [&"triple_ruins", &"silent_sanctuary", &"ember_crucible"]:
			if expected not in ids:
				failures.append("Assinatura de arena ausente: %s" % String(expected))
		arena_runtime.configure(CompetitiveMatchCatalog.resolved_arena_rules({"arena_id": &"silent_sanctuary"}))
		await process_frame
		var sanctuary := instance.get_node_or_null("SanctuaryEnvironmentArt")
		if not is_instance_valid(sanctuary) or not sanctuary.visible:
			failures.append("Arte do Santuário não foi ativada")
		arena_runtime.configure(CompetitiveMatchCatalog.resolved_arena_rules({"arena_id": &"ember_crucible"}))
		await process_frame
		var crucible := instance.get_node_or_null("CrucibleEnvironmentArt")
		if not is_instance_valid(crucible) or not crucible.visible:
			failures.append("Arte do Crisol não foi ativada")
	if is_instance_valid(share_runtime):
		var code := share_runtime.code_for_player(1)
		if code == "" or not share_runtime.apply_code_for_test(2, code):
			failures.append("Runtime de código compacto não aplicou o loadout")
	instance.queue_free()
	await process_frame
