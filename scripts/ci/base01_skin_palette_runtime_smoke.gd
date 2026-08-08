extends SceneTree

const BASE := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const PLATE := "res://assets/modular_fighters/base_01/face_plate/neutral_face_plate_v1.png"
const FACE := "res://assets/modular_fighters/base_01/face/face_02_angular.png"
const EYES := "res://assets/modular_fighters/base_01/eyes/eyes_01_focused.png"
const BROWS := "res://assets/modular_fighters/base_01/brows/brows_01_focused.png"
const PALETTE_ROOT := "res://assets/modular_fighters/base_01/palettes"
const DEFAULT_ID := "skin_tone_03_warm"
const PALETTE_IDS := [
	"skin_tone_01_porcelain",
	"skin_tone_02_light_neutral",
	"skin_tone_03_warm",
	"skin_tone_04_olive",
	"skin_tone_05_tan",
	"skin_tone_06_brown",
	"skin_tone_07_deep",
	"skin_tone_08_ebony",
]
const CHANNELS := ["skin_base", "skin_shadow", "skin_highlight", "cheek_tint"]

class SkinProfile:
	extends RefCounted
	var profile_id: StringName = &"c62_1_skin_runtime_smoke"
	func validate_against_standard() -> PackedStringArray:
		return PackedStringArray()

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _sprite(path: String, z: int) -> Sprite2D:
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.z_index = z
	return sprite

func _material_matches(sprite: Sprite2D, palette: Dictionary) -> bool:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return false
	var channels = palette.get("channels", {})
	for channel in CHANNELS:
		var expected := Color.from_string(String(channels.get(channel, "")), Color.MAGENTA)
		var actual = material.get_shader_parameter(channel)
		if typeof(actual) != TYPE_COLOR or not (actual as Color).is_equal_approx(expected):
			return false
	return true

func _init() -> void:
	var failures := PackedStringArray()
	for resource_path in [BASE, PLATE, FACE, EYES, BROWS]:
		if not ResourceLoader.exists(resource_path):
			failures.append("resource_missing:%s" % resource_path)

	for palette_id in PALETTE_IDS:
		if not failures.is_empty():
			break
		var palette := _load_json("%s/%s.json" % [PALETTE_ROOT, palette_id])
		if palette.is_empty():
			failures.append("palette_missing:%s" % palette_id)
			continue

		var assembler := ModularFighterAssembler.new()
		get_root().add_child(assembler)
		var configure_failures := assembler.configure(SkinProfile.new())
		if not configure_failures.is_empty():
			failures.append("configure_failed:%s:%s" % [palette_id, ",".join(configure_failures)])
			assembler.queue_free()
			continue

		var body := _sprite(BASE, 0)
		var plate := _sprite(PLATE, 15)
		var face := _sprite(FACE, 20)
		var eyes := _sprite(EYES, 30)
		var brows := _sprite(BROWS, 40)
		if body == null or plate == null or face == null or eyes == null or brows == null:
			failures.append("sprite_invalid:%s" % palette_id)
			assembler.queue_free()
			continue
		if not assembler.attach_visual_module(&"body_base", body): failures.append("body_attach:%s" % palette_id)
		if not assembler.attach_visual_module(&"face_plate", plate): failures.append("plate_attach:%s" % palette_id)
		if not assembler.attach_visual_module(&"face", face): failures.append("face_attach:%s" % palette_id)
		if not assembler.attach_visual_module(&"eyes", eyes): failures.append("eyes_attach:%s" % palette_id)
		if not assembler.attach_visual_module(&"brows", brows): failures.append("brows_attach:%s" % palette_id)

		var palette_failures := assembler.set_skin_palette(StringName(palette_id))
		if not palette_failures.is_empty():
			failures.append("palette_apply:%s:%s" % [palette_id, ",".join(palette_failures)])
		else:
			if String(assembler.active_skin_palette_id()) != palette_id:
				failures.append("active_palette:%s" % palette_id)
			if palette_id == DEFAULT_ID:
				if body.material != null or plate.material != null or face.material != null:
					failures.append("default_identity_materialized:%s" % palette_id)
			else:
				for pair in [["body", body], ["plate", plate], ["face", face]]:
					if not _material_matches(pair[1], palette):
						failures.append("skin_material_mismatch:%s:%s" % [palette_id, pair[0]])
			if eyes.material != null or brows.material != null:
				failures.append("non_skin_slot_tinted:%s" % palette_id)

		print("C62_1_SKIN_RUNTIME=PASS palette=%s" % palette_id)
		assembler.queue_free()

	if not failures.is_empty():
		for failure in failures:
			push_error("C62_1_SKIN_RUNTIME=BLOCKED %s" % failure)
		quit(2)
		return

	print("C62_1_SKIN_RUNTIME=PASS palettes=8")
	print("C62_1_DEFAULT_WARM_IDENTITY=PASS material=none")
	print("C62_1_SKIN_SLOTS=PASS body_base,face_plate,face")
	print("C62_1_NON_SKIN_SLOTS=PASS eyes,brows")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)
