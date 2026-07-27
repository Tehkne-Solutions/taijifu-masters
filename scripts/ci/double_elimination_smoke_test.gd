extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	_validate_four_player_direct_final(failures)
	_validate_four_player_reset(failures)
	_validate_eight_player_bracket(failures)
	_validate_persistence_contract(failures)
	await _validate_scene_runtime(failures)
	if failures.is_empty():
		print("TAIJIFU CI: dupla eliminação, chave inferior e reset da final válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

func _validate_four_player_direct_final(failures: Array[String]) -> void:
	var ledger := DoubleEliminationLedger.new()
	ledger.data = DoubleEliminationLedger.default_state(4)
	if not ledger.set_participants(_participants(4)) or not ledger.start():
		failures.append("Dupla eliminação de quatro competidores não iniciou")
		return
	if String(ledger.current_match().get("match_id", "")) != "U1":
		failures.append("Primeiro confronto de quatro competidores não é U1")
		return
	for result in [[1, 2, 0], [1, 2, 0], [1, 2, 0], [1, 2, 1], [2, 1, 2]]:
		var recorded := ledger.record_result(int(result[0]), int(result[1]), int(result[2]))
		if not bool(recorded.get("ok", false)):
			failures.append("Resultado intermediário da chave de quatro foi rejeitado")
			return
	if String(ledger.current_match().get("match_id", "")) != "GF":
		failures.append("Grande Final não foi alcançada após cinco séries")
		return
	var final_result := ledger.record_result(1, 2, 0)
	if not bool(final_result.get("finished", false)):
		failures.append("Vitória do invicto na Grande Final não concluiu o torneio")
	if bool(final_result.get("reset_required", false)):
		failures.append("Reset foi exigido mesmo com vitória do invicto")
	if int(ledger.champion().get("seed", 0)) != 1:
		failures.append("Seed 1 não foi reconhecida como campeã direta")
	if ledger.loss_count(String(ledger.runner_up().get("participant_id", ""))) != 2:
		failures.append("Vice-campeão não acumulou duas derrotas")

func _validate_four_player_reset(failures: Array[String]) -> void:
	var ledger := DoubleEliminationLedger.new()
	ledger.data = DoubleEliminationLedger.default_state(4)
	ledger.set_participants(_participants(4))
	ledger.start()
	for result in [[1, 2, 0], [1, 2, 0], [1, 2, 0], [1, 2, 1], [2, 1, 2]]:
		ledger.record_result(int(result[0]), int(result[1]), int(result[2]))
	var first_final := ledger.record_result(2, 0, 2)
	if not bool(first_final.get("reset_required", false)):
		failures.append("Vitória da chave inferior não exigiu reset")
		return
	if String(ledger.current_match().get("match_id", "")) != "RESET":
		failures.append("Confronto RESET não foi habilitado")
		return
	var pair := ledger.current_pair()
	if pair.size() != 2 or int(pair[0].get("seed", 0)) != 1:
		failures.append("Reset não preservou o campeão da chave superior")
	var reset_result := ledger.record_result(2, 1, 2)
	if not bool(reset_result.get("finished", false)):
		failures.append("Reset da Grande Final não concluiu o torneio")
	if int(ledger.champion().get("seed", 0)) != 2:
		failures.append("Vencedor do reset não foi reconhecido como campeão")
	if ledger.loss_count(String(ledger.runner_up().get("participant_id", ""))) != 2:
		failures.append("Perdedor do reset não recebeu a segunda derrota")

func _validate_eight_player_bracket(failures: Array[String]) -> void:
	var ledger := DoubleEliminationLedger.new()
	ledger.data = DoubleEliminationLedger.default_state(8)
	if not ledger.set_participants(_participants(8)) or not ledger.start():
		failures.append("Dupla eliminação de oito competidores não iniciou")
		return
	if ledger.all_matches().size() != 15:
		failures.append("Chave de oito não criou 14 séries mais reset opcional")
		return
	var first_pair := ledger.current_pair()
	if first_pair.size() != 2 or int(first_pair[0].get("seed", 0)) != 1 or int(first_pair[1].get("seed", 0)) != 8:
		failures.append("Pareamento inicial 1×8 está incorreto")
		return
	for index in range(14):
		var current := ledger.current_match()
		if current.is_empty():
			failures.append("Chave de oito ficou sem confronto na série %d" % (index + 1))
			return
		var result := ledger.record_result(1, 2, 0)
		if not bool(result.get("ok", false)):
			failures.append("Série %d da chave de oito foi rejeitada" % (index + 1))
			return
	if not ledger.is_finished():
		failures.append("Chave de oito não terminou após 14 vitórias diretas")
	if int(ledger.champion().get("seed", 0)) != 1:
		failures.append("Seed 1 não venceu a simulação da chave de oito")

func _validate_persistence_contract(failures: Array[String]) -> void:
	var ledger := DoubleEliminationLedger.new()
	ledger.data = DoubleEliminationLedger.default_state(4)
	ledger.set_participants(_participants(4))
	ledger.start()
	ledger.record_result(1, 2, 0)
	var snapshot := ledger.bracket_snapshot()
	var restored := DoubleEliminationLedger.new()
	restored.data = restored.sanitize_state(snapshot)
	var pair := restored.current_pair()
	if pair.size() != 2:
		failures.append("Snapshot restaurado não resolveu o próximo confronto")
		return
	if String(pair[0].get("profile_id", "")) == "" or String(pair[1].get("profile_id", "")) == "":
		failures.append("Perfis foram perdidos na restauração do chaveamento")
	if String(restored.match_by_id("U1").get("loser", {}).get("profile_id", "")) != "double_profile_4":
		failures.append("Perfil do perdedor não foi preservado no snapshot")
	if restored.loss_count("double_p4") != 1:
		failures.append("Contagem de derrotas não foi preservada pelo participant_id")

func _validate_scene_runtime(failures: Array[String]) -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(scene):
		failures.append("Cena principal não pôde ser carregada")
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var runtime := instance.get_node_or_null("DoubleEliminationRuntime") as DoubleEliminationRuntime
	if not is_instance_valid(runtime):
		failures.append("DoubleEliminationRuntime ausente da cena principal")
	else:
		if runtime.set_format_for_test(4) != 4:
			failures.append("Runtime não aceitou formato de quatro")
		elif not runtime.set_participants_for_test(_participants(4)) or not runtime.start_for_test():
			failures.append("Runtime não iniciou chave de teste")
		else:
			var context := runtime.current_profile_context(1)
			if String(context.get("profile_id", "")) != "double_profile_1":
				failures.append("Runtime não forneceu o perfil do confronto")
			var competition := runtime.competition_context()
			if String(competition.get("competition_mode", "")) != "double_elimination":
				failures.append("Contexto competitivo da dupla eliminação está incorreto")
		runtime.reset_double_elimination()
	instance.queue_free()
	await process_frame

func _participants(size: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var presets: Array[StringName] = [
		&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger",
		&"aerial_flow", &"foundation_breaker", &"adaptive_staff", &"rock_guardian"
	]
	for index in range(size):
		result.append({
			"participant_id": "double_p%d" % (index + 1),
			"name": "DUPLO %d" % (index + 1),
			"profile_id": "double_profile_%d" % (index + 1),
			"profile_name": "JOGADOR DUPLO %d" % (index + 1),
			"seed": index + 1,
			"loadout": BattleLoadoutCatalog.loadout_from_preset(presets[index]),
			"source": "ci"
		})
	return result
