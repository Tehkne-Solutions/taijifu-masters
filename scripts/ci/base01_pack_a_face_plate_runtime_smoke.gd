extends SceneTree

const ROOT := "res://assets/modular_fighters/base_01/_ci_candidates"
const PLATE := ROOT + "/neutral_face_plate_v1.png"
const FACES := [
	ROOT + "/face_02_angular.png",
	ROOT + "/face_03_soft.png",
	ROOT + "/face_04_broad.png",
]
const EYES := "res://assets/modular_fighters/base_01/eyes/eyes_01_focused.png"
const BROWS := "res://assets/modular_fighters/base_01/brows/brows_01_focused.png"
const PIVOT := Vector2(0.5, 0.92)

class BenchProfile:
	extends RefCounted
	var profile_id: StringName = &"c59_4_pack_a_face_plate_runtime"
	func validate_against_standard() -> PackedStringArray:
		return PackedStringArray()

func _sprite(path: String, z: int) -> Sprite2D:
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	var size := texture.get_size()
	sprite.position = Vector2(
		size.x * (0.5 - PIVOT.x),
		size.y * (0.5 - PIVOT.y)
	)
	sprite.z_index = z
	return sprite

func _init() -> void:
	var failures := PackedStringArray()
	for path in [PLATE, EYES, BROWS]:
		if not ResourceLoader.exists(path):
			failures.append("resource_missing:%s" % path)
	for path in FACES:
		if not ResourceLoader.exists(path):
			failures.append("resource_missing:%s" % path)

	if failures.is_empty():
		var plate_texture := load(PLATE) as Texture2D
		if plate_texture == null or plate_texture.get_size() != Vector2(1024, 1024):
			failures.append("plate_texture_contract_invalid")

	for face_path in FACES:
		if not failures.is_empty():
			break
		var assembler := ModularFighterAssembler.new()
		get_root().add_child(assembler)
		var config_failures := assembler.configure(BenchProfile.new())
		if not config_failures.is_empty():
			failures.append("configure_failed:%s" % ",".join(config_failures))
			assembler.queue_free()
			continue

		var plate := _sprite(PLATE, 15)
		var face := _sprite(face_path, 20)
		var eyes := _sprite(EYES, 30)
		var brows := _sprite(BROWS, 40)
		if plate == null or face == null or eyes == null or brows == null:
			failures.append("sprite_build_failed:%s" % face_path)
			assembler.queue_free()
			continue

		if not assembler.attach_visual_module(&"face_plate", plate):
			failures.append("plate_attach_failed:%s" % face_path)
		if not assembler.attach_visual_module(&"face", face):
			failures.append("face_attach_failed:%s" % face_path)
		if not assembler.attach_visual_module(&"eyes", eyes):
			failures.append("eyes_attach_failed:%s" % face_path)
		if not assembler.attach_visual_module(&"brows", brows):
			failures.append("brows_attach_failed:%s" % face_path)

		for required in ["Module_face_plate", "Module_face", "Module_eyes", "Module_brows"]:
			if assembler.get_node_or_null(required) == null:
				failures.append("module_missing:%s:%s" % [face_path, required])

		if not (plate.z_index < face.z_index and face.z_index < eyes.z_index and eyes.z_index < brows.z_index):
			failures.append("z_order_invalid:%s" % face_path)
		if plate.position.distance_to(Vector2(0.0, -430.08)) > 0.02:
			failures.append("plate_pivot_position_invalid:%s:%s" % [face_path, plate.position])
		if face.position.distance_to(Vector2(0.0, -430.08)) > 0.02:
			failures.append("face_pivot_position_invalid:%s:%s" % [face_path, face.position])

		print("C59_4_RUNTIME_VARIANT=PASS face=%s plate_z=%s face_z=%s eyes_z=%s brows_z=%s" % [face_path.get_file(), plate.z_index, face.z_index, eyes.z_index, brows.z_index])
		assembler.queue_free()

	if not failures.is_empty():
		for failure in failures:
			push_error("C59_4_PACK_A_FACE_PLATE_RUNTIME=BLOCKED %s" % failure)
		quit(2)
		return

	print("C59_4_PACK_A_FACE_PLATE_RUNTIME=PASS variants=3")
	print("OWNER_REVIEW=PENDING")
	print("PNG_PROMOTION=BLOCKED")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)
