class_name FirstPlayableSession
extends RefCounted

const VALID_DIFFICULTIES: Array[StringName] = [&"apprentice", &"disciple", &"master"]
const PILOT_ID := "pilot-09-r1"
const PARTICIPANT_PREFIX := "TJFP-"

static var selected_difficulty_id: StringName = &"disciple"
static var participant_code := ""

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

static func reset() -> void:
	selected_difficulty_id = &"disciple"
	participant_code = ""
