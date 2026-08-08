extends SceneTree

const PLATE := "res://assets/modular_fighters/base_01/face_plate/neutral_face_plate_v1.png"
const FACES := [
	"res://assets/modular_fighters/base_01/face/face_02_angular.png",
	"res://assets/modular_fighters/base_01/face/face_03_soft.png",
	"res://assets/modular_fighters/base_01/face/face_04_broad.png",
]
const EYES := "res://assets/modular_fighters/base_01/eyes/eyes_01_focused.png"
const BROWS := "res://assets/modular_fighters/base_01/brows/brows_01_focused.png"
const CATALOG := "res://assets/modular_fighters/base_01/catalog.json"
const CANONICAL := "res://assets/modular_fighters/base_01/production/BASE01_PACK_A_FACES.canonical.json"
const PIVOT := Vector2(0.5, 0.92)
const EXPECTED_POSITION := Vector2(0.0, -430.08)

class CanonicalProfile:
	extends RefCounted
	var profile_id: StringName = &"c59_5_pack_a_canonical"
	func validate_against_standard() -> PackedStringArray:
		return PackedStringArray()

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

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
	var catalog := _load_json(CATALOG)
	var canonical := _load_json(CANONICAL)
	if catalog.is_empty():
		failures.append("catalog_missing")
	if canonical.is_empty():
		failures.append("canonical_manifest_missing")
	if String(canonical.get("status", "")) != "PASS":
		failures.append("canonical_status_not_pass")
	if String(canonical.get("owner_review", "")) != "PASS":
		failures.append("owner_review_not_pass")

	var face_states := {}
	for row in catalog.get("faces", []):
		if typeof(row) == TYPE_DICTIONARY:
			face_states[String(row.get("id", ""))] = String(row.get("status", ""))
	for face_id in ["face_02_angular", "face_03_soft", "face_04_broad"]:
		if face_states.get(face_id, "") != "produced":
			failures.append("catalog_face_not_produced:%s" % face_id)

	for path in [PLATE, EYES, BROWS]:
		if not ResourceLoader.exists(path):
			failures.append("resource_missing:%s" % path)
	for path in FACES:
		if not ResourceLoader.exists(path):
			failures.append("resource_missing:%s" % path)

	for face_path in FACES:
		if not failures.is_empty():
			break
		var assembler := ModularFighterAssembler.new()
		get_root().add_child(assembler)
		var config_failures := assembler.configure(CanonicalProfile.new())
		if not config_failures.is_empty():
			failures.append("configure_failed:%s" % ",".join(config_failures))
			assembler.queue_free()
			continue

		var plate := _sprite(PLATE, 15)
		var face := _sprite(face_path, 20)
		var eyes := _sprite(EYES, 30)
		var brows := _sprite(BROWS, 40)
		if plate == null or face == null or eyes == null or brows == null:
			failures.append("sprite_contract_invalid:%s" % face_path)
			assembler.queue_free()
			continue
		if not assembler.attach_visual_module(&"face_plate", plate): failures.append("plate_attach_failed:%s" % face_path)
		if not assembler.attach_visual_module(&"face", face): failures.append("face_attach_failed:%s" % face_path)
		if not assembler.attach_visual_module(&"eyes", eyes): failures.append("eyes_attach_failed:%s" % face_path)
		if not assembler.attach_visual_module(&"brows", brows): failures.append("brows_attach_failed:%s" % face_path)
		if plate.position.distance_to(EXPECTED_POSITION) > 0.02: failures.append("plate_pivot_invalid:%s" % face_path)
		if face.position.distance_to(EXPECTED_POSITION) > 0.02: failures.append("face_pivot_invalid:%s" % face_path)
		if not (plate.z_index == 15 and face.z_index == 20 and eyes.z_index == 30 and brows.z_index == 40):
			failures.append("z_order_invalid:%s" % face_path)
		print("C59_5_CANONICAL_VARIANT=PASS face=%s" % face_path.get_file())
		assembler.queue_free()

	if not failures.is_empty():
		for failure in failures:
			push_error("C59_5_PACK_A_CANONICAL=BLOCKED %s" % failure)
		quit(2)
		return

	print("C59_5_PACK_A_CANONICAL=PASS variants=3 plate=1")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)
