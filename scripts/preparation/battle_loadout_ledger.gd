class_name BattleLoadoutLedger
extends RefCounted

const SAVE_PATH := "user://battle_preparation.json"

var data: Dictionary = {
	"version": 1,
	"players": {}
}

func load_from_disk(unlocked_by_profile: Dictionary = {}) -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				data = parsed
	if not data.has("players") or not (data["players"] is Dictionary):
		data["players"] = {}
	for player_index in [1, 2]:
		var profile_id := "p%d" % player_index
		var unlocked: Array = unlocked_by_profile.get(profile_id, [])
		var players: Dictionary = data["players"]
		var current: Dictionary = players.get(profile_id, BattleLoadoutCatalog.default_loadout(player_index))
		players[profile_id] = BattleLoadoutCatalog.sanitize(current, unlocked)
		data["players"] = players

func save_to_disk() -> String:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	data["version"] = 1
	data["updated_unix"] = int(Time.get_unix_time_from_system())
	file.store_string(JSON.stringify(data, "\t"))
	return SAVE_PATH

func loadout_for(player_index: int, unlocked_variants: Array = []) -> Dictionary:
	var profile_id := "p%d" % clampi(player_index, 1, 2)
	var players: Dictionary = data.get("players", {})
	var current: Dictionary = players.get(profile_id, BattleLoadoutCatalog.default_loadout(player_index))
	return BattleLoadoutCatalog.sanitize(current, unlocked_variants)

func set_loadout(player_index: int, loadout: Dictionary, unlocked_variants: Array = []) -> Dictionary:
	var profile_id := "p%d" % clampi(player_index, 1, 2)
	var sanitized := BattleLoadoutCatalog.sanitize(loadout, unlocked_variants)
	var players: Dictionary = data.get("players", {})
	players[profile_id] = sanitized
	data["players"] = players
	return sanitized.duplicate(true)

func reset_player(player_index: int) -> Dictionary:
	return set_loadout(player_index, BattleLoadoutCatalog.default_loadout(player_index))
