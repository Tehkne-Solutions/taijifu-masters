class_name FirstPlayableSession
extends RefCounted

const VALID_DIFFICULTIES: Array[StringName] = [&"apprentice", &"disciple", &"master"]
const PILOT_ID := "pilot-09-r2"
const PARTICIPANT_PREFIX := "TJFP-"
const CREATOR_VISUAL_BLOCKER := "shared_modular_animation_runtime"

static var selected_difficulty_id: StringName = &"disciple"
static var participant_code := ""
static var selected_creator_preset_id: StringName = &""

static func set_difficulty(difficulty_id: StringName) -> void:
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
	participant_code = normalized
	return normalized != ""

static func clear_participant_code() -> void:
	participant_code = ""

static func has_valid_participant_code() -> bool:
	return normalize_participant_code(participant_code) != ""

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
		"session_handoff": true,
		"visual_activation": false,
		"visual_blocker": CREATOR_VISUAL_BLOCKER,
		"combat_build_fallback": "lian_wu_first_playable",
		"static_sprite_regression_allowed": false,
		"signature": "Tehkné Solutions",
	}

static func reset() -> void:
	selected_difficulty_id = &"disciple"
	participant_code = ""
	selected_creator_preset_id = &""
