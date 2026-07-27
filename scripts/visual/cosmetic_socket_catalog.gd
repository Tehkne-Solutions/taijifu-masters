class_name CosmeticSocketCatalog
extends RefCounted

const SOCKET_IDS: Array[StringName] = [&"head", &"back", &"chest", &"pet"]
const FRAME_COUNT := 4

const SOCKET_LABELS := {
	&"head": "ACESSÓRIO",
	&"back": "COSTAS",
	&"chest": "AMULETO",
	&"pet": "PET"
}

const OPTIONS := {
	&"head": [&"none", &"wind_circlet", &"stone_crown", &"ember_horns", &"moon_halo"],
	&"back": [&"none", &"flow_scarf", &"guardian_banner", &"ember_mantle", &"tide_ribbons"],
	&"chest": [&"none", &"jade_amulet", &"ember_amulet", &"tide_amulet", &"earth_amulet"],
	&"pet": [&"none", &"cloud_wisp", &"fox_spirit", &"stone_sprite", &"flame_salamander"]
}

const ITEM_LABELS := {
	&"none": "NENHUM",
	&"wind_circlet": "DIADEMA DO VENTO",
	&"stone_crown": "COROA DE PEDRA",
	&"ember_horns": "CHIFRES DE BRASA",
	&"moon_halo": "HALO LUNAR",
	&"flow_scarf": "CACHECOL DO FLUXO",
	&"guardian_banner": "ESTANDARTE GUARDIÃO",
	&"ember_mantle": "MANTO DE BRASA",
	&"tide_ribbons": "FITAS DA MARÉ",
	&"jade_amulet": "AMULETO DE JADE",
	&"ember_amulet": "AMULETO DE BRASA",
	&"tide_amulet": "AMULETO DA MARÉ",
	&"earth_amulet": "AMULETO DA TERRA",
	&"cloud_wisp": "NIMBO",
	&"fox_spirit": "RAPOSA ESPIRITUAL",
	&"stone_sprite": "ESPÍRITO DE PEDRA",
	&"flame_salamander": "SALAMANDRA DE FOGO"
}

const CHARACTER_BASE := {
	&"kael": {&"head": Vector2(0.0, -58.0), &"back": Vector2(-13.0, -29.0), &"chest": Vector2(0.0, -24.0), &"pet": Vector2(-46.0, 10.0)},
	&"nara": {&"head": Vector2(0.0, -59.0), &"back": Vector2(-15.0, -25.0), &"chest": Vector2(0.0, -22.0), &"pet": Vector2(-49.0, 12.0)},
	&"lyra": {&"head": Vector2(0.0, -60.0), &"back": Vector2(-14.0, -31.0), &"chest": Vector2(0.0, -25.0), &"pet": Vector2(-45.0, 7.0)},
	&"rin": {&"head": Vector2(0.0, -58.0), &"back": Vector2(-14.0, -28.0), &"chest": Vector2(0.0, -23.0), &"pet": Vector2(-47.0, 11.0)}
}

const STATE_OFFSETS := {
	&"idle": [Vector2.ZERO, Vector2(0.0, -1.0), Vector2.ZERO, Vector2(0.0, 1.0)],
	&"move": [Vector2(-1.0, 1.0), Vector2(1.0, -2.0), Vector2(3.0, -1.0), Vector2.ZERO],
	&"attack": [Vector2(-2.0, -1.0), Vector2(2.0, -3.0), Vector2(5.0, -1.0), Vector2(1.0, 2.0)],
	&"guard": [Vector2(-1.0, 0.0), Vector2(0.0, -2.0), Vector2(1.0, 0.0), Vector2(-1.0, 1.0)]
}

static func socket_label(socket_id: StringName) -> String:
	return String(SOCKET_LABELS.get(socket_id, String(socket_id).to_upper()))

static func item_label(item_id: StringName) -> String:
	return String(ITEM_LABELS.get(item_id, String(item_id).to_upper()))

static func options_for(socket_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var values: Variant = OPTIONS.get(socket_id, [&"none"])
	if values is Array:
		for value in values:
			result.append(StringName(value))
	return result

static func default_loadout(character_id: StringName) -> Dictionary:
	match character_id:
		&"nara":
			return {"head": "stone_crown", "back": "guardian_banner", "chest": "earth_amulet", "pet": "stone_sprite"}
		&"lyra":
			return {"head": "moon_halo", "back": "tide_ribbons", "chest": "tide_amulet", "pet": "cloud_wisp"}
		&"rin":
			return {"head": "ember_horns", "back": "ember_mantle", "chest": "ember_amulet", "pet": "flame_salamander"}
		_:
			return {"head": "wind_circlet", "back": "flow_scarf", "chest": "jade_amulet", "pet": "fox_spirit"}

static func socket_position(
	character_id: StringName,
	socket_id: StringName,
	state_id: StringName,
	frame_index: int,
	facing: float
) -> Vector2:
	var character_data: Dictionary = CHARACTER_BASE.get(character_id, CHARACTER_BASE[&"kael"])
	var position: Vector2 = character_data.get(socket_id, Vector2.ZERO)
	var safe_state: StringName = state_id if STATE_OFFSETS.has(state_id) else &"idle"
	var offsets: Array = STATE_OFFSETS[safe_state]
	position += offsets[clampi(frame_index, 0, FRAME_COUNT - 1)] as Vector2
	position.x *= facing
	if socket_id == &"pet":
		position.x = absf(position.x) * -facing
	return position

static func validate() -> Array[String]:
	var failures: Array[String] = []
	for character_id in CharacterVisualCatalog.character_ids():
		if not CHARACTER_BASE.has(character_id):
			failures.append("Personagem sem sockets: %s" % String(character_id))
	for socket_id in SOCKET_IDS:
		var options := options_for(socket_id)
		if options.is_empty() or options[0] != &"none":
			failures.append("Socket %s precisa começar com none" % String(socket_id))
	for state_id in CharacterVisualCatalog.STATE_ORDER:
		if not STATE_OFFSETS.has(state_id):
			failures.append("Estado sem offset cosmético: %s" % String(state_id))
			continue
		var offsets: Array = STATE_OFFSETS[state_id]
		if offsets.size() != FRAME_COUNT:
			failures.append("Estado %s possui %d offsets cosméticos" % [String(state_id), offsets.size()])
	return failures
