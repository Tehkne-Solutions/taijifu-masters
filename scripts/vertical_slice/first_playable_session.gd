class_name FirstPlayableSession
extends RefCounted

const VALID_DIFFICULTIES: Array[StringName] = [&"apprentice", &"disciple", &"master"]
const PILOT_ID := "pilot-09-r2"
const PARTICIPANT_PREFIX := "TJFP-"
const CREATOR_VISUAL_BLOCKER := "shared_modular_animation_runtime"
const PRODUCTION_DEFAULT_PRESET_ID := &"production_default_base01"
const PRODUCTION_DEFAULT_PROFILE_ID := &"production_default_base01"
const PRODUCTION_DEFAULT_DISPLAY_NAME := "LIAN WU • BASE-01"
const PILOT_MATCHES_PER_DIFFICULTY := 2
const PILOT_ASSIGNMENTS := {
	"TJFP-001": [&"apprentice", &"disciple", &"master"],
	"TJFP-002": [&"disciple", &"master", &"apprentice"],
	"TJFP-003": [&"master", &"apprentice", &"disciple"],
	"TJFP-004": [&"apprentice", &"master", &"disciple"],
	"TJFP-005": [&"master", &"disciple", &"apprentice"],
	"TJFP-006": [&"disciple", &"apprentice", &"master"],
	"TJFP-007": [&"apprentice", &"disciple", &"master"],
	"TJFP-008": [&"disciple", &"master", &"apprentice"],
	"TJFP-009": [&"master", &"apprentice", &"disciple"],
}

static var selected_difficulty_id: StringName = &"disciple"
static var participant_code := ""
static var selected_creator_preset_id: StringName = &""
static var pilot_completed_matches := 0
static var pilot_enforcement_enabled := false

static func set_difficulty(difficulty_id: StringName) -> void:
	if pilot_sequence_locked():
		selected_difficulty_id = pilot_required_difficulty()
		return
	if difficulty_id in VALID_DIFFICULTIES:
		selected_difficulty_id = difficulty_id

static func difficulty_label() -> String:
	return BotBehaviorCatalog.difficulty_label(selected_difficulty_id)

static func normalize_participant_code(raw_value: String) -> String:
	var candidate := raw_value.strip_edges().to_upper()
	if candidate.length() == 3 and candidate.is_valid_int():
		candidate = "%s%s" % [PARTICIPANT_PREFIX, candidate]
	if candidate.length() != 8 or not candidate.begins_with(PARTICIPANT_PREFIX):
		return ""
	var digits := candidate.substr(PARTICIPANT_PREFIX.length(), 3)
	if not digits.is_valid_int():
		return ""
	var participant_number := int(digits)
	if participant_number < 1 or participant_number > 999:
		return ""
	return "%s%03d" % [PARTICIPANT_PREFIX, participant_number]

static func set_participant_code(raw_value: String) -> bool:
	var normalized := normalize_participant_code(raw_value)
	if normalized == "" or not PILOT_ASSIGNMENTS.has(normalized):
		participant_code = ""
		pilot_completed_matches = 0
		pilot_enforcement_enabled = false
		return false
	var changed := participant_code != normalized
	participant_code = normalized
	if changed:
		pilot_completed_matches = 0
	return true

static func begin_pilot_session(raw_value: String) -> bool:
	if not set_participant_code(raw_value):
		pilot_enforcement_enabled = false
		return false
	pilot_enforcement_enabled = true
	pilot_completed_matches = 0
	selected_difficulty_id = pilot_required_difficulty()
	return true

static func end_pilot_session() -> void:
	pilot_enforcement_enabled = false

static func clear_participant_code() -> void:
	participant_code = ""
	pilot_completed_matches = 0
	pilot_enforcement_enabled = false

static func has_valid_participant_code() -> bool:
	var normalized := normalize_participant_code(participant_code)
	return normalized != "" and PILOT_ASSIGNMENTS.has(normalized)

static func pilot_sequence() -> Array[StringName]:
	if not has_valid_participant_code():
		return []
	var source: Array = PILOT_ASSIGNMENTS.get(participant_code, [])
	var result: Array[StringName] = []
	for difficulty_id in source:
		result.append(StringName(difficulty_id))
	return result

static func pilot_expected_matches() -> int:
	return pilot_sequence().size() * PILOT_MATCHES_PER_DIFFICULTY

static func pilot_complete() -> bool:
	var expected := pilot_expected_matches()
	return expected > 0 and pilot_completed_matches >= expected

static func pilot_sequence_locked() -> bool:
	return pilot_enforcement_enabled and has_valid_participant_code() and not pilot_complete()

static func pilot_required_difficulty() -> StringName:
	var sequence := pilot_sequence()
	if sequence.is_empty():
		return selected_difficulty_id
	var difficulty_index := mini(
		floori(float(pilot_completed_matches) / float(PILOT_MATCHES_PER_DIFFICULTY)),
		sequence.size() - 1
	)
	return sequence[difficulty_index]

static func pilot_round_number() -> int:
	var expected := pilot_expected_matches()
	if expected <= 0:
		return 0
	return mini(pilot_completed_matches + 1, expected)

static func pilot_progress_signature() -> Dictionary:
	return {
		"pilot_id": PILOT_ID,
		"participant_code": participant_code,
		"sequence": pilot_sequence(),
		"matches_per_difficulty": PILOT_MATCHES_PER_DIFFICULTY,
		"completed_matches": pilot_completed_matches,
		"expected_matches": pilot_expected_matches(),
		"round_number": pilot_round_number(),
		"required_difficulty": String(pilot_required_difficulty()),
		"enforcement_enabled": pilot_enforcement_enabled,
		"sequence_locked": pilot_sequence_locked(),
		"complete": pilot_complete(),
		"signature": "Tehkné Solutions",
	}

static func mark_pilot_round_complete(actual_difficulty: StringName) -> bool:
	if not pilot_sequence_locked():
		return false
	var expected := pilot_required_difficulty()
	if actual_difficulty != expected:
		return false
	pilot_completed_matches += 1
	if not pilot_complete():
		selected_difficulty_id = pilot_required_difficulty()
	return true

static func set_creator_preset(preset_id: StringName) -> bool:
	var id_text := String(preset_id)
	if id_text.is_empty():
		clear_creator_preset()
		return true
	var result := ModularFighterPresetStore.load_user_preset(preset_id)
	if not bool(result.get("ok", false)):
		return false
	var profile = result.get("profile")
	if not (profile is ModularFighterProfile):
		return false
	# Battle handoff accepts only canonical BASE-01 identity presets. Legacy v1
	# remains readable at the persistence boundary but cannot silently become an
	# active player-created fighter.
	for slot_name in ["face", "eyes", "brows"]:
		var module_id := (profile as ModularFighterProfile).module_id(StringName(slot_name))
		if module_id == &"":
			return false
		var validation := (profile as ModularFighterProfile).set_base01_identity_module(StringName(slot_name), module_id)
		if not validation.is_empty():
			return false
	selected_creator_preset_id = preset_id
	return true

static func clear_creator_preset() -> void:
	selected_creator_preset_id = &""

static func has_creator_preset() -> bool:
	if selected_creator_preset_id == &"":
		return false
	var result := ModularFighterPresetStore.load_user_preset(selected_creator_preset_id)
	return bool(result.get("ok", false))

static func ensure_battle_visual_preset() -> bool:
	# P0.2: entering combat directly must resolve to the production modular graph.
	# A user-selected Creator preset always wins; the deterministic BASE-01 default
	# is materialized only when no valid user preset is active.
	if has_creator_preset():
		return true

	var profile := ModularFighterProfile.new()
	profile.profile_id = PRODUCTION_DEFAULT_PROFILE_ID
	profile.display_name = PRODUCTION_DEFAULT_DISPLAY_NAME
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_skin_palette_id(&"skin_tone_03_warm")
	for slot_name in ["face", "eyes", "brows"]:
		var slot := StringName(slot_name)
		var default_id := profile.base01_default_identity_id(slot)
		if default_id == &"":
			return false
		var failures := profile.set_base01_identity_module(slot, default_id)
		if not failures.is_empty():
			return false
	var validation := profile.validate_against_standard()
	if not validation.is_empty():
		return false
	var save_failures := ModularFighterPresetStore.save_user_preset(profile, PRODUCTION_DEFAULT_PRESET_ID)
	if not save_failures.is_empty():
		return false
	selected_creator_preset_id = PRODUCTION_DEFAULT_PRESET_ID
	return has_creator_preset()

static func using_production_default_preset() -> bool:
	return has_creator_preset() and selected_creator_preset_id == PRODUCTION_DEFAULT_PRESET_ID

static func battle_visual_source() -> String:
	if not has_creator_preset():
		return "unresolved"
	return "production_default" if using_production_default_preset() else "creator_preset"

static func creator_preset_id() -> StringName:
	return selected_creator_preset_id if has_creator_preset() else &""

static func creator_profile_result() -> Dictionary:
	if not has_creator_preset():
		return {
			"ok": false,
			"profile": ModularFighterProfile.new(),
			"failures": PackedStringArray(["creator_battle_preset_unavailable"]),
		}
	return ModularFighterPresetStore.load_user_preset(selected_creator_preset_id)

static func creator_battle_handoff_signature() -> Dictionary:
	return {
		"preset_selected": has_creator_preset(),
		"preset_id": String(creator_preset_id()),
		"visual_source": battle_visual_source(),
		"production_default_preset_id": String(PRODUCTION_DEFAULT_PRESET_ID),
		"production_default_active": using_production_default_preset(),
		"session_handoff": true,
		"visual_activation": false,
		"visual_blocker": CREATOR_VISUAL_BLOCKER,
		"combat_build_fallback": "lian_wu_first_playable",
		"unintended_lot01_fallback_allowed": false,
		"static_sprite_regression_allowed": false,
		"signature": "Tehkné Solutions",
	}

static func reset() -> void:
	selected_difficulty_id = &"disciple"
	participant_code = ""
	selected_creator_preset_id = &""
	pilot_completed_matches = 0
	pilot_enforcement_enabled = false

# Tehkné Solutions
