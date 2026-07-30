class_name CharacterVisualCatalog
extends RefCounted

const FRAME_SIZE := Vector2(128.0, 128.0)
const STATE_ORDER: Array[StringName] = [&"idle", &"move", &"attack", &"guard"]
const ATLAS_CHARACTER_IDS: Array[StringName] = [&"kael", &"nara", &"lyra", &"rin"]
const FIRST_PLAYABLE_CHARACTER_IDS: Array[StringName] = [&"lian_wu", &"training_rival"]

const CHARACTERS := {
	&"kael": {
		"display_name": "Kael",
		"role": "Discípulo do Fluxo",
		"render_mode": &"atlas",
		"sheet": "res://assets/characters/kael/kael_animated_sheet.svg",
		"columns": 4,
		"rows": 4,
		"scale": 0.78,
		"fps": {&"idle": 5.0, &"move": 10.0, &"attack": 13.0, &"guard": 6.0}
	},
	&"nara": {
		"display_name": "Nara",
		"role": "Guardiã da Rocha",
		"render_mode": &"atlas",
		"sheet": "res://assets/characters/nara/nara_animated_sheet.svg",
		"columns": 4,
		"rows": 4,
		"scale": 0.80,
		"fps": {&"idle": 4.0, &"move": 7.0, &"attack": 10.0, &"guard": 5.0}
	},
	&"lyra": {
		"display_name": "Lyra",
		"role": "Tecelã Elemental",
		"render_mode": &"atlas",
		"sheet": "res://assets/characters/lyra/lyra_animated_sheet.svg",
		"columns": 4,
		"rows": 4,
		"scale": 0.78,
		"fps": {&"idle": 6.0, &"move": 9.0, &"attack": 12.0, &"guard": 6.0}
	},
	&"rin": {
		"display_name": "Rin",
		"role": "Rival da Chama",
		"render_mode": &"atlas",
		"sheet": "res://assets/characters/rin/rin_animated_sheet.svg",
		"columns": 4,
		"rows": 4,
		"scale": 0.79,
		"fps": {&"idle": 5.0, &"move": 11.0, &"attack": 14.0, &"guard": 6.0}
	},
	&"lian_wu": {
		"display_name": "Lian Wu",
		"role": "Discípulo da Lâmina Serena",
		"render_mode": &"procedural",
		"sheet": "",
		"columns": 4,
		"rows": 4,
		"scale": 1.0,
		"fps": {&"idle": 5.0, &"move": 10.0, &"attack": 13.0, &"guard": 6.0}
	},
	&"training_rival": {
		"display_name": "Rival de Treino",
		"role": "Punho da Fornalha",
		"render_mode": &"procedural",
		"sheet": "",
		"columns": 4,
		"rows": 4,
		"scale": 1.0,
		"fps": {&"idle": 4.0, &"move": 8.0, &"attack": 11.0, &"guard": 5.0}
	}
}

static func character_ids() -> Array[StringName]:
	# Mantém a lista histórica de personagens com atlas para não ampliar menus,
	# inspeções e preparação do protótipo completo nesta sprint.
	return ATLAS_CHARACTER_IDS.duplicate()

static func first_playable_character_ids() -> Array[StringName]:
	return FIRST_PLAYABLE_CHARACTER_IDS.duplicate()

static func all_character_ids() -> Array[StringName]:
	var ids := character_ids()
	ids.append_array(first_playable_character_ids())
	return ids

static func has_character(character_id: StringName) -> bool:
	return CHARACTERS.has(character_id)

static func profile(character_id: StringName) -> Dictionary:
	var data: Dictionary = CHARACTERS.get(character_id, CHARACTERS[&"kael"])
	return data.duplicate(true)

static func display_name(character_id: StringName) -> String:
	return String(profile(character_id).get("display_name", String(character_id).capitalize()))

static func role(character_id: StringName) -> String:
	return String(profile(character_id).get("role", "Praticante Taijifu"))

static func render_mode(character_id: StringName) -> StringName:
	return StringName(profile(character_id).get("render_mode", &"atlas"))

static func uses_procedural_fallback(character_id: StringName) -> bool:
	return render_mode(character_id) == &"procedural"

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
	if uses_procedural_fallback(character_id):
		if path != "":
			failures.append("Personagem procedural %s não deve declarar atlas" % String(character_id))
		return failures
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
