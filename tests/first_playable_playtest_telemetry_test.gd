extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	assert(FirstPlayableSession.set_participant_code("tjfp-007"), "O código anônimo válido deve ser aceito")
	assert(FirstPlayableSession.participant_code == "TJFP-007")
	assert(FirstPlayableSession.pilot_required_difficulty() == &"apprentice")

	var telemetry := MatchTelemetry.new()
	telemetry.begin_session({
		"experience": "first_playable",
		"build_version": "test",
		"platform": "headless",
		"privacy": "local_only",
		"signature": "Tehkné Solutions"
	})
	assert(telemetry.session_id() != "", "A sessão deve receber um ID")
	assert(MatchTelemetry.TELEMETRY_VERSION == 4)
	assert(MatchTelemetry.TELEMETRY_SCHEMA == "tehkne/taijifu-match-telemetry/v4")

	telemetry.set_round_metadata({
		"match_generation": 1,
		"difficulty_id": "apprentice",
		"difficulty_label": "APRENDIZ",
		"time_limit_seconds": 90.0,
		"arena": "Ruínas do Caminho Triplo"
	})
	telemetry.record_event(&"p1", &"match_started", &"apprentice")
	telemetry.record_event(&"p1", &"pause")
	telemetry.record_event(&"p1", &"resume")
	telemetry.record_event(&"p1", &"match_won", &"ko")
	telemetry.record_route(&"p1", &"tai", 0.45)
	telemetry.record_route(&"p1", &"ji", 0.30)
	telemetry.record_combat_metric(&"p1", &"techniques_started", 3.0)
	telemetry.record_combat_metric(&"p1", &"confirmed_hits", 2.0)
	telemetry.record_combat_metric(&"p1", &"damage_dealt", 18.5)
	telemetry.record_combat_metric(&"p1", &"climax_started", 1.0)
	telemetry.record_combat_peak(&"p1", &"max_combo", 3.0)
	telemetry.record_combat_peak(&"p1", &"max_flow", 76.0)

	var saved_path := telemetry.finish_round(&"p1", {
		"result_reason": "ko",
		"player_won": true,
		"difficulty_id": "apprentice",
		"elapsed_seconds": 32.5,
		"p1_final": {"health": 42.0, "posture": 18.0},
		"p2_final": {"health": 0.0, "posture": 0.0}
	})
	assert(saved_path != "", "A sessão deve ser gravada")
	assert(FileAccess.file_exists(saved_path), "O JSON deve existir em user://telemetry")
	assert(saved_path == telemetry.last_written_path(), "O último caminho deve ser rastreável")
	assert(
		saved_path.get_file().begins_with("TJFP-007__taijifu_"),
		"O arquivo deve nascer com o prefixo anônimo esperado pelo intake"
	)
	assert(FirstPlayableSession.pilot_completed_matches == 1)
	assert(FirstPlayableSession.pilot_required_difficulty() == &"apprentice")

	var annotated_path := telemetry.annotate_last_round({
		"balance_feedback": "balanced",
		"feedback_submitted_unix": 123456789
	})
	assert(annotated_path == saved_path, "A anotação deve atualizar o mesmo arquivo")

	var parsed_variant := JSON.parse_string(FileAccess.get_file_as_string(saved_path))
	assert(parsed_variant is Dictionary, "O relatório deve ser um objeto JSON")
	var parsed: Dictionary = parsed_variant
	assert(parsed.get("schema", "") == MatchTelemetry.TELEMETRY_SCHEMA)
	assert(int(parsed.get("version", 0)) == MatchTelemetry.TELEMETRY_VERSION)
	assert(parsed.get("session_id", "") == telemetry.session_id())

	var session_metadata: Dictionary = parsed.get("metadata", {})
	assert(session_metadata.get("experience", "") == "first_playable")
	assert(session_metadata.get("privacy", "") == "local_only")
	assert(session_metadata.get("signature", "") == "Tehkné Solutions")
	assert(session_metadata.get("participant_code", "") == "TJFP-007")
	assert(session_metadata.get("pilot_id", "") == FirstPlayableSession.PILOT_ID)

	var rounds: Array = parsed.get("rounds", [])
	assert(rounds.size() == 1, "A sessão deve conter uma rodada")
	var round_data: Dictionary = rounds[0]
	assert(round_data.get("winner_profile_id", "") == "p1")
	var round_metadata: Dictionary = round_data.get("metadata", {})
	assert(round_metadata.get("difficulty_id", "") == "apprentice")
	assert(round_metadata.get("result_reason", "") == "ko")
	assert(round_metadata.get("balance_feedback", "") == "balanced")
	assert(bool(round_metadata.get("player_won", false)))
	assert(round_metadata.get("arena", "") == "Mountain Dojo Night")
	assert(round_metadata.get("participant_code", "") == "TJFP-007")
	assert(round_metadata.get("pilot_id", "") == FirstPlayableSession.PILOT_ID)
	assert(int(round_metadata.get("pilot_round_number", 0)) == 1)
	assert(int(round_metadata.get("pilot_expected_matches", 0)) == 6)
	assert(round_metadata.get("pilot_expected_difficulty", "") == "apprentice")
	assert(bool(round_metadata.get("pilot_sequence_valid", false)))
	assert(int(round_metadata.get("pilot_completed_matches_before_round", -1)) == 0)
	assert(int(round_metadata.get("pilot_completed_matches_after_round", -1)) == 1)
	assert(round_metadata.get("pilot_next_difficulty", "") == "apprentice")

	var players: Dictionary = round_data.get("players", {})
	var p1: Dictionary = players.get("p1", {})
	var routes: Dictionary = p1.get("route_seconds", {})
	assert(float(routes.get("tai", 0.0)) > 0.0)
	assert(float(routes.get("ji", 0.0)) > 0.0)
	var combat: Dictionary = p1.get("combat", {})
	assert(float(combat.get("techniques_started", 0.0)) == 3.0)
	assert(float(combat.get("confirmed_hits", 0.0)) == 2.0)
	assert(float(combat.get("damage_dealt", 0.0)) == 18.5)
	assert(float(combat.get("max_combo", 0.0)) == 3.0)
	assert(float(combat.get("max_flow", 0.0)) == 76.0)
	assert(float(combat.get("climax_started", 0.0)) == 1.0)

	var events: Array = round_data.get("events", [])
	assert(events.size() == 4, "Os eventos essenciais devem ser preservados")
	var report_json := telemetry.session_json()
	assert(report_json.contains("balance_feedback"))
	assert(report_json.contains("\"combat\""))
	assert(report_json.contains("max_combo"))
	assert(report_json.contains("max_flow"))
	assert(report_json.contains("Mountain Dojo Night"))
	assert(report_json.contains("pilot_sequence_valid"))

	var sanitized := PlaytestReportExporter.sanitize_file_name(
		"../../TJFP-007__taijifu_<script>.json"
	)
	assert(sanitized == "TJFP-007__taijifu__script_.json")
	var web_script := PlaytestReportExporter.build_web_download_script(
		report_json,
		saved_path.get_file()
	)
	assert(web_script.contains("new Blob"))
	assert(web_script.contains("URL.createObjectURL"))
	assert(web_script.contains("URL.revokeObjectURL"))
	assert(web_script.contains("atob("))
	assert(web_script.contains(saved_path.get_file()))
	assert(not web_script.contains("balance_feedback"), "O JSON cru não deve ser interpolado no JavaScript")
	var export_contract := PlaytestReportExporter.contract_signature()
	assert(bool(export_contract.get("web_blob_download", false)))
	assert(export_contract.get("web_payload_encoding", "") == "base64")
	assert(bool(export_contract.get("native_file_reveal", false)))
	assert(not bool(export_contract.get("automatic_upload", true)))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
	FirstPlayableSession.reset()
	print("FIRST_PLAYABLE_PLAYTEST_TELEMETRY_OK")
	quit()

# Tehkné Solutions
