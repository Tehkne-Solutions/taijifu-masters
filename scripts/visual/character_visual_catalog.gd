class_name CharacterVisualCatalog
extends RefCounted

const FRAME_SIZE := Vector2(128.0, 128.0)
const STATE_ORDER: Array[StringName] = [&"idle", &"move", &"attack", &"guard"]

const CHARACTERS := {
	&"kael": {
		"display_name": "Kael",
		"role": "Discípulo do Fluxo",
		"sheet": "res://assets/characters/kael/kael_animated_sheet.svg",
		"columns": 4,
		"rows": 4,
		"scale": 0.78,
		"fps": {&"idle": 5.0, &"move": 10.0, &"attack": 13.0, &"guard": 6.0}
	},
	&"nara": {
		"display_name": "Nara",
		"role": "Guardiã da Rocha",
		"sheet": "res://assets/characters/nara/nara_animated_sheet.svg",
		"columns": 4,
		"rows": 4,
		"scale": 0.80,
		"fps": {&"idle": 4.0, &"move": 7.0, &"attack": 10.0, &"guard": 5.0}
	},
	&"lyra": {
		"display_name": "Lyra",
		"role": "Tecelã Elemental",
		"sheet": "res://assets/characters/lyra/lyra_animated_sheet.svg",
		"columns": 4,
		"rows": 4,
		"scale": 0.78,
		"fps": {&"idle": 6.0, &"move": 9.0, &"attack": 12.0, &"guard": 6.0}
	},
	&"rin": {
		"display_name": "Rin",
		"role": "Rival da Chama",
		"sheet": "res://assets/characters/rin/rin_animated_sheet.svg",
		"columns": 4,
		"rows": 4,
		"scale": 0.79,
		"fps": {&"idle": 5.0, &"move": 11.0, &"attack": 14.0, &"guard": 6.0}
	}
}

static func character_ids() -> Array[StringName]:
	return [&"kael", &"nara", &"lyra", &"rin"]

static func has_character(character_id: StringName) -> bool:
	return CHARACTERS.has(character_id)

static func profile(character_id: StringName) -> Dictionary:
	var data: Dictionary = CHARACTERS.get(character_id, CHARACTERS[&"kael"])
	return data.duplicate(true)

static func display_name(character_id: StringName) -> String:
	return String(profile(character_id).get("display_name", String(character_id).capitalize()))

static func role(character_id: StringName) -> String:
	return String(profile(character_id).get("role", "Praticante Taijifu"))

static func sheet_path(character_id: StringName) -> String:
	return String(profile(character_id).get("sheet", ""))

static func columns(character_id: StringName) -> int:
	return int(profile(character_id).get("columns", 4))

static func rows(character_id: StringName) -> int:
	return int(profile(character_id).get("rows", 4))

static func scale_for(character_id: StringName) -> float:
	return float(profile(character_id).get("scale", 0.78))

static func fps_for(character_id: StringName, state_id: StringName) -> float:
	var data := profile(character_id)
	var fps_map: Dictionary = data.get("fps", {})
	return maxf(1.0, float(fps_map.get(state_id, 6.0)))

static func state_row(state_id: StringName) -> int:
	var index := STATE_ORDER.find(state_id)
	return maxi(0, index)

static func state_label(state_id: StringName) -> String:
	match state_id:
		&"idle": return "REPOUSO"
		&"move": return "MOVIMENTO"
		&"attack": return "ATAQUE"
		&"guard": return "GUARDA / DANO"
		_: return String(state_id).to_upper()

static func validate_character(character_id: StringName) -> Array[String]:
	var failures: Array[String] = []
	var data := profile(character_id)
	var path := String(data.get("sheet", ""))
	var column_count := int(data.get("columns", 0))
	var row_count := int(data.get("rows", 0))
	if path == "":
		failures.append("%s não possui caminho de atlas" % String(character_id))
	elif not ResourceLoader.exists(path):
		failures.append("Atlas ausente ou não importável: %s" % path)
	else:
		var texture := load(path) as Texture2D
		if not is_instance_valid(texture):
			failures.append("Falha ao carregar atlas: %s" % path)
		else:
			var expected_width := int(FRAME_SIZE.x) * column_count
			var expected_height := int(FRAME_SIZE.y) * row_count
			if texture.get_width() != expected_width or texture.get_height() != expected_height:
				failures.append("Atlas %s possui %dx%d, esperado %dx%d" % [
					String(character_id), texture.get_width(), texture.get_height(), expected_width, expected_height
				])
	if column_count <= 0 or row_count < STATE_ORDER.size():
		failures.append("Grade inválida para %s" % String(character_id))
	return failures
