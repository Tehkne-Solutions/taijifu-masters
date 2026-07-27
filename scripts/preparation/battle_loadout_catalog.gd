class_name BattleLoadoutCatalog
extends RefCounted

const CHARACTER_ORDER: Array[StringName] = [&"kael", &"nara", &"lyra", &"rin"]
const ELEMENT_ORDER: Array[StringName] = [&"fire", &"water", &"earth", &"air"]
const WEAPON_ORDER: Array[StringName] = [
	&"training_staff",
	&"wind_wraps",
	&"seismic_gauntlets",
	&"breaker_gauntlets",
	&"unarmed"
]
const FIELD_ORDER: Array[StringName] = [
	&"character", &"build", &"element", &"primary_weapon", &"secondary_weapon",
	&"variant", &"head", &"back", &"chest", &"pet"
]

const CHARACTER_PRESETS := {
	&"kael": [&"adaptive_staff", &"aerial_flow"],
	&"nara": [&"rock_guardian", &"foundation_breaker"],
	&"lyra": [&"lyra_elementalist"],
	&"rin": [&"rin_challenger"]
}
const ELEMENT_LABELS := {&"fire": "FOGO", &"water": "ÁGUA", &"earth": "TERRA", &"air": "AR"}
const FIELD_LABELS := {
	&"character": "PERSONAGEM", &"build": "BUILD", &"element": "ELEMENTO",
	&"primary_weapon": "ARMA PRINCIPAL", &"secondary_weapon": "ARMA SECUNDÁRIA",
	&"variant": "VARIANTE DE MESTRE", &"head": "ACESSÓRIO", &"back": "COSTAS",
	&"chest": "AMULETO", &"pet": "PET"
}

static func default_loadout(player_index: int) -> Dictionary:
	return loadout_from_preset(&"adaptive_staff" if player_index == 1 else &"rock_guardian")

static func loadout_from_preset(preset_id: StringName) -> Dictionary:
	var build := BuildProfile.prototype_preset(preset_id)
	var cosmetics := CosmeticSocketCatalog.default_loadout(build.character_id)
	return {
		"character_id": build.character_id,
		"preset_id": preset_id,
		"element_id": build.element_id,
		"primary_weapon_id": build.weapon_id,
		"secondary_weapon_id": build.secondary_weapon_id,
		"variant_id": &"",
		"head": StringName(cosmetics.get("head", "none")),
		"back": StringName(cosmetics.get("back", "none")),
		"chest": StringName(cosmetics.get("chest", "none")),
		"pet": StringName(cosmetics.get("pet", "none"))
	}

static func sanitize(source: Dictionary, unlocked_variants: Array = []) -> Dictionary:
	var character_id := StringName(source.get("character_id", &"kael"))
	if character_id not in CHARACTER_ORDER:
		character_id = &"kael"
	var presets := presets_for_character(character_id)
	var preset_id := StringName(source.get("preset_id", presets[0]))
	if preset_id not in presets:
		preset_id = presets[0]
	var build := BuildProfile.prototype_preset(preset_id)
	var element_id := StringName(source.get("element_id", build.element_id))
	if element_id not in ELEMENT_ORDER:
		element_id = build.element_id
	var primary := StringName(source.get("primary_weapon_id", build.weapon_id))
	if primary not in WEAPON_ORDER:
		primary = build.weapon_id
	var secondary := StringName(source.get("secondary_weapon_id", build.secondary_weapon_id))
	if secondary not in WEAPON_ORDER:
		secondary = build.secondary_weapon_id
	if secondary == primary:
		secondary = &"unarmed" if primary != &"unarmed" else build.secondary_weapon_id
	var variant_options := variants_for_weapon(primary, unlocked_variants)
	var variant_id := StringName(source.get("variant_id", &""))
	if variant_id not in variant_options:
		variant_id = &""
	var result := {
		"character_id": character_id, "preset_id": preset_id, "element_id": element_id,
		"primary_weapon_id": primary, "secondary_weapon_id": secondary, "variant_id": variant_id
	}
	for socket_id in CosmeticSocketCatalog.SOCKET_IDS:
		var item_id := StringName(source.get(String(socket_id), "none"))
		if item_id not in CosmeticSocketCatalog.options_for(socket_id):
			item_id = &"none"
		result[String(socket_id)] = item_id
	return result

static func presets_for_character(character_id: StringName) -> Array[StringName]:
	var values: Array = CHARACTER_PRESETS.get(character_id, CHARACTER_PRESETS[&"kael"])
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result

static func variants_for_weapon(weapon_id: StringName, unlocked_variants: Array) -> Array[StringName]:
	var result: Array[StringName] = [&""]
	for value in unlocked_variants:
		var variant_id := StringName(value)
		var master := MasterTrainingCatalog.master_for_variant(variant_id)
		var weapon_ids: Array = master.get("weapon_ids", [])
		if weapon_id in weapon_ids and variant_id not in result:
			result.append(variant_id)
	return result

static func options_for(field_id: StringName, loadout: Dictionary, unlocked_variants: Array) -> Array[StringName]:
	match field_id:
		&"character": return CHARACTER_ORDER.duplicate()
		&"build": return presets_for_character(StringName(loadout.get("character_id", &"kael")))
		&"element": return ELEMENT_ORDER.duplicate()
		&"primary_weapon", &"secondary_weapon": return WEAPON_ORDER.duplicate()
		&"variant": return variants_for_weapon(StringName(loadout.get("primary_weapon_id", &"unarmed")), unlocked_variants)
		&"head", &"back", &"chest", &"pet": return CosmeticSocketCatalog.options_for(field_id)
		_: return []

static func value_for_field(field_id: StringName, loadout: Dictionary) -> StringName:
	match field_id:
		&"character": return StringName(loadout.get("character_id", &"kael"))
		&"build": return StringName(loadout.get("preset_id", &"adaptive_staff"))
		&"element": return StringName(loadout.get("element_id", &"air"))
		&"primary_weapon": return StringName(loadout.get("primary_weapon_id", &"training_staff"))
		&"secondary_weapon": return StringName(loadout.get("secondary_weapon_id", &"wind_wraps"))
		&"variant": return StringName(loadout.get("variant_id", &""))
		&"head", &"back", &"chest", &"pet": return StringName(loadout.get(String(field_id), &"none"))
		_: return &""

static func set_field(loadout: Dictionary, field_id: StringName, value_id: StringName, unlocked_variants: Array) -> Dictionary:
	var result := loadout.duplicate(true)
	match field_id:
		&"character": result = loadout_from_preset(presets_for_character(value_id)[0])
		&"build":
			var cosmetics := {}
			for socket_id in CosmeticSocketCatalog.SOCKET_IDS:
				cosmetics[String(socket_id)] = result.get(String(socket_id), &"none")
			result = loadout_from_preset(value_id)
			for socket_id in CosmeticSocketCatalog.SOCKET_IDS:
				result[String(socket_id)] = cosmetics[String(socket_id)]
		&"element": result["element_id"] = value_id
		&"primary_weapon": result["primary_weapon_id"] = value_id
		&"secondary_weapon": result["secondary_weapon_id"] = value_id
		&"variant": result["variant_id"] = value_id
		&"head", &"back", &"chest", &"pet": result[String(field_id)] = value_id
	return sanitize(result, unlocked_variants)

static func field_label(field_id: StringName) -> String:
	return String(FIELD_LABELS.get(field_id, String(field_id).to_upper()))

static func value_label(field_id: StringName, value_id: StringName) -> String:
	match field_id:
		&"character": return CharacterVisualCatalog.display_name(value_id).to_upper()
		&"build": return BuildProfile.prototype_preset(value_id).display_name.to_upper()
		&"element": return String(ELEMENT_LABELS.get(value_id, String(value_id).to_upper()))
		&"primary_weapon", &"secondary_weapon": return WeaponKitCatalog.label_for(value_id)
		&"variant": return MasterTrainingCatalog.variant_label(value_id)
		&"head", &"back", &"chest", &"pet": return CosmeticSocketCatalog.item_label(value_id)
		_: return String(value_id).to_upper()

static func validate() -> Array[String]:
	var failures: Array[String] = []
	for character_id in CHARACTER_ORDER:
		var presets := presets_for_character(character_id)
		if presets.is_empty():
			failures.append("Personagem sem builds: %s" % String(character_id))
		for preset_id in presets:
			if BuildProfile.prototype_preset(preset_id).character_id != character_id:
				failures.append("Build %s pertence a personagem incorreto" % String(preset_id))
	for field_id in FIELD_ORDER:
		if field_label(field_id) == "":
			failures.append("Campo sem rótulo: %s" % String(field_id))
	return failures
