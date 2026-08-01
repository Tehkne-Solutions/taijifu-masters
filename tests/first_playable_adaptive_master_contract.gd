extends SceneTree

const TELEMETRY_RUNTIME := preload("res://scripts/vertical_slice/first_playable_combat_telemetry_runtime.gd")
const ADAPTIVE_RUNTIME := preload("res://scripts/vertical_slice/first_playable_adaptive_master_runtime.gd")
const IDENTITY := preload("res://scripts/vertical_slice/first_playable_character_identity.gd")

func _init() -> void:
	var telemetry_runtime := TELEMETRY_RUNTIME.new() as FirstPlayableCombatTelemetryRuntime
	var telemetry_signature := telemetry_runtime.presentation_signature()
	assert(telemetry_signature.get("telemetry_schema") == "v4")
	assert(bool(telemetry_signature.get("route_seconds_from_techniques", false)))
	assert(bool(telemetry_signature.get("both_fighters_instrumented", false)))
	assert(bool(telemetry_signature.get("martial_flow_metrics", false)))
	assert(bool(telemetry_signature.get("impact_outcomes", false)))
	assert(bool(telemetry_signature.get("combo_peak", false)))
	assert(bool(telemetry_signature.get("flow_peak", false)))
	assert(bool(telemetry_signature.get("climax_events", false)))
	telemetry_runtime.free()

	var adaptive := ADAPTIVE_RUNTIME.new() as FirstPlayableAdaptiveMasterRuntime
	var adaptive_signature := adaptive.presentation_signature()
	assert(bool(adaptive_signature.get("master_pattern_memory", false)))
	assert(bool(adaptive_signature.get("anti_mash_is_counterplay", false)))
	assert(int(adaptive_signature.get("pattern_window", 0)) >= 4)
	assert(bool(adaptive_signature.get("dominant_family_detection", false)))
	assert(bool(adaptive_signature.get("counter_uses_real_technique", false)))
	assert(bool(adaptive_signature.get("dedicated_push_disabled", false)))
	assert(bool(adaptive_signature.get("bot_builds_martial_code", false)))
	assert(bool(adaptive_signature.get("bot_builds_flow", false)))
	assert(bool(adaptive_signature.get("bot_elemental_climax", false)))
	assert(bool(adaptive_signature.get("climax_telegraph_reaction", false)))
	assert(bool(adaptive_signature.get("climax_late_defense", false)))
	assert(float(adaptive_signature.get("climax_reaction_threshold", 1.0)) <= 0.08)
	assert(bool(adaptive_signature.get("no_hidden_input_reading", false)))
	assert(bool(adaptive_signature.get("defense_then_counter", false)))
	assert(bool(adaptive_signature.get("apprentice_unchanged", false)))
	assert(bool(adaptive_signature.get("disciple_unchanged", false)))
	adaptive.free()

	var identity := IDENTITY.new() as FirstPlayableCharacterIdentity
	var identity_signature := identity.presentation_signature()
	assert(bool(identity_signature.get("combat_telemetry_v4", false)))
	assert(bool(identity_signature.get("adaptive_master_runtime", false)))
	identity.free()

	assert(MatchTelemetry.TELEMETRY_VERSION == 4)
	assert(MatchTelemetry.TELEMETRY_SCHEMA.ends_with("/v4"))
	print("FIRST_PLAYABLE_ADAPTIVE_MASTER_CONTRACT_OK")
	quit()

# Tehkné Solutions
