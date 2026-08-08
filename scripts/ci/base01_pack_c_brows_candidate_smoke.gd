extends SceneTree

const ROOT := "res://assets/modular_fighters/base_01/_ci_brow_candidates"
const BROWS := [
	ROOT + "/brows_02_neutral.png",
	ROOT + "/brows_03_arched.png",
	ROOT + "/brows_04_straight.png",
	ROOT + "/brows_05_heavy.png",
	ROOT + "/brows_06_sharp.png",
]
const PLATE := "res://assets/modular_fighters/base_01/face_plate/neutral_face_plate_v1.png"
const FACE := "res://assets/modular_fighters/base_01/face/face_01_balanced.png"
const EYES := "res://assets/modular_fighters/base_01/eyes/eyes_01_focused.png"
const PIVOT := Vector2(0.5, 0.92)
const EXPECTED_POSITION := Vector2(0.0, -430.08)

class CandidateProfile:
	extends RefCounted
	var profile_id: StringName = &"c61_pack_c_brow_candidate"
	func validate_against_standard() -> PackedStringArray:
		return PackedStringArray()

func _sprite(path: String, z: int) -> Sprite2D:
	var texture := load(path) as Texture2D
	if texture == null or texture.get_size() != Vector2(1024, 1024): return null
	var sprite := Sprite2D.new(); sprite.texture = texture; sprite.centered = true
	var size := texture.get_size(); sprite.position = Vector2(size.x*(0.5-PIVOT.x),size.y*(0.5-PIVOT.y)); sprite.z_index = z
	return sprite

func _init() -> void:
	var failures := PackedStringArray()
	for path in [PLATE, FACE, EYES]:
		if not ResourceLoader.exists(path): failures.append("resource_missing:%s" % path)
	for path in BROWS:
		if not ResourceLoader.exists(path): failures.append("candidate_missing:%s" % path)

	for brows_path in BROWS:
		if not failures.is_empty(): break
		var assembler := ModularFighterAssembler.new(); get_root().add_child(assembler)
		var config_failures := assembler.configure(CandidateProfile.new())
		if not config_failures.is_empty():
			failures.append("configure_failed:%s" % ",".join(config_failures)); assembler.queue_free(); continue
		var plate := _sprite(PLATE,15); var face := _sprite(FACE,20); var eyes := _sprite(EYES,30); var brows := _sprite(brows_path,40)
		if plate == null or face == null or eyes == null or brows == null:
			failures.append("sprite_contract_invalid:%s" % brows_path); assembler.queue_free(); continue
		if not assembler.attach_visual_module(&"face_plate",plate): failures.append("plate_attach_failed:%s" % brows_path)
		if not assembler.attach_visual_module(&"face",face): failures.append("face_attach_failed:%s" % brows_path)
		if not assembler.attach_visual_module(&"eyes",eyes): failures.append("eyes_attach_failed:%s" % brows_path)
		if not assembler.attach_visual_module(&"brows",brows): failures.append("brows_attach_failed:%s" % brows_path)
		if brows.position.distance_to(EXPECTED_POSITION) > 0.02: failures.append("brows_pivot_invalid:%s:%s" % [brows_path,brows.position])
		if not (plate.z_index==15 and face.z_index==20 and eyes.z_index==30 and brows.z_index==40): failures.append("z_order_invalid:%s" % brows_path)
		print("C61_GODOT_BROW_CANDIDATE=PASS brow=%s" % brows_path.get_file()); assembler.queue_free()

	if not failures.is_empty():
		for failure in failures: push_error("C61_PACK_C_BROWS_RUNTIME=BLOCKED %s" % failure)
		quit(2); return
	print("C61_PACK_C_BROWS_RUNTIME=PASS candidates=5")
	print("OWNER_REVIEW=PENDING")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)
