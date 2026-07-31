extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	assert(FirstPlayableSession.set_participant_code("tjfp-007"), "O código anônimo válido deve ser aceito")
	assert(FirstPlayableSession.participant_code == "TJFP-007")

	var telemetry := MatchTelemetry.new()
	telemetry.begin_session({
		"experience": "first_playable",
		"build_version": "test",
		"platform": "headless",
		"privacy": "local_only",
		"signature": "Tehkné Solutions"
	})
	assert(telemetry.session_id() != "", "A sessão deve receber um ID")

	telemetry.set_round_metadata({
		"match_generation": 1,
		"difficulty_id": "disciple",
		"difficulty_label": "DISCÍPULO",
		"time_limit_seconds": 90.0
	})
	telemetry.record_event(&"p1", &"match_started", &"disciple")
	telemetry.record_event(&"p1", &"pause")
	telemetry.record_event(&"p1", &"resume")
	telemetry.record_event(&"p1", &"match_won", &"ko")

	var saved_path := telemetry.finish_round(&"p1", {
		"result_reason": "ko",
		"player_won": true,
		"difficulty_id": "disciple",
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
	assert(round_metadata.get("difficulty_id", "") == "disciple")
	assert(round_metadata.get("result_reason", "") == "ko")
	assert(round_metadata.get("balance_feedback", "") == "balanced")
	assert(bool(round_metadata.get("player_won", false)))

	var events: Array = round_data.get("events", [])
	assert(events.size() == 4, "Os eventos essenciais devem ser preservados")
	assert(telemetry.session_json().contains("balance_feedback"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
	FirstPlayableSession.reset()
	print("FIRST_PLAYABLE_PLAYTEST_TELEMETRY_OK")
	quit()
