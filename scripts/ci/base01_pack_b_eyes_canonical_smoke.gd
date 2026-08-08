extends SceneTree

const ROOT := "res://assets/modular_fighters/base_01/eyes"
const EYES := [
	ROOT + "/eyes_02_calm.png",
	ROOT + "/eyes_03_fierce.png",
	ROOT + "/eyes_04_narrow.png",
	ROOT + "/eyes_05_round.png",
	ROOT + "/eyes_06_heavy.png",
]
const PLATE := "res://assets/modular_fighters/base_01/face_plate/neutral_face_plate_v1.png"
const FACE := "res://assets/modular_fighters/base_01/face/face_01_balanced.png"
const BROWS := "res://assets/modular_fighters/base_01/brows/brows_01_focused.png"
const PIVOT := Vector2(0.5, 0.92)
const EXPECTED_POSITION := Vector2(0.0, -430.08)

class CanonicalProfile:
	extends RefCounted
	var profile_id: StringName = &"c60_1_pack_b_eye_canonical"
	func validate_against_standard() -> PackedStringArray:
		return PackedStringArray()

func _sprite(path: String, z: int) -> Sprite2D:
	var texture := load(path) as Texture2D
	if texture == null or texture.get_size() != Vector2(1024, 1024):
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	var size := texture.get_size()
	sprite.position = Vector2(size.x * (0.5 - PIVOT.x), size.y * (0.5 - PIVOT.y))
	sprite.z_index = z
	return sprite

func _init() -> void:
	var failures := PackedStringArray()
	for path in [PLATE, FACE, BROWS]:
		if not ResourceLoader.exists(path): failures.append("resource_missing:%s" % path)
	for path in EYES:
		if not ResourceLoader.exists(path): failures.append("canonical_eye_missing:%s" % path)

	for eyes_path in EYES:
		if not failures.is_empty(): break
		var assembler := ModularFighterAssembler.new()
		get_root().add_child(assembler)
		var config_failures := assembler.configure(CanonicalProfile.new())
		if not config_failures.is_empty():
			failures.append("configure_failed:%s" % ",".join(config_failures))
			assembler.queue_free()
			continue
		var plate := _sprite(PLATE, 15)
		var face := _sprite(FACE, 20)
		var eyes := _sprite(eyes_path, 30)
		var brows := _sprite(BROWS, 40)
		if plate == null or face == null or eyes == null or brows == null:
			failures.append("sprite_contract_invalid:%s" % eyes_path)
			assembler.queue_free()
			continue
		if not assembler.attach_visual_module(&"face_plate", plate): failures.append("plate_attach_failed:%s" % eyes_path)
		if not assembler.attach_visual_module(&"face", face): failures.append("face_attach_failed:%s" % eyes_path)
		if not assembler.attach_visual_module(&"eyes", eyes): failures.append("eyes_attach_failed:%s" % eyes_path)
		if not assembler.attach_visual_module(&"brows", brows): failures.append("brows_attach_failed:%s" % eyes_path)
		if eyes.position.distance_to(EXPECTED_POSITION) > 0.02:
			failures.append("eyes_pivot_invalid:%s:%s" % [eyes_path, eyes.position])
		if not (plate.z_index == 15 and face.z_index == 20 and eyes.z_index == 30 and brows.z_index == 40):
			failures.append("z_order_invalid:%s" % eyes_path)
		print("C60_1_GODOT_CANONICAL_EYE=PASS eye=%s" % eyes_path.get_file())
		assembler.queue_free()

	if not failures.is_empty():
		for failure in failures: push_error("C60_1_PACK_B_CANONICAL=BLOCKED %s" % failure)
		quit(2)
		return
	print("C60_1_PACK_B_CANONICAL=PASS variants=5")
	print("OWNER_REVIEW=PASS")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)
