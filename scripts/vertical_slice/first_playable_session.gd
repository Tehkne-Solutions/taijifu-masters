class_name FirstPlayableSession
extends RefCounted

const VALID_DIFFICULTIES: Array[StringName] = [&"apprentice", &"disciple", &"master"]

static var selected_difficulty_id: StringName = &"disciple"

static func set_difficulty(difficulty_id: StringName) -> void:
	if difficulty_id in VALID_DIFFICULTIES:
		selected_difficulty_id = difficulty_id

static func difficulty_label() -> String:
	return BotBehaviorCatalog.difficulty_label(selected_difficulty_id)

static func reset() -> void:
	selected_difficulty_id = &"disciple"
