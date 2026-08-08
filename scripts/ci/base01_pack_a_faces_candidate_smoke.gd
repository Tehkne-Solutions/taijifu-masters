extends SceneTree

const CANDIDATES := [
	"res://assets/modular_fighters/base_01/_ci_candidates/face_02_angular.png",
	"res://assets/modular_fighters/base_01/_ci_candidates/face_03_soft.png",
	"res://assets/modular_fighters/base_01/_ci_candidates/face_04_broad.png",
]
const EXPECTED_SIZE := Vector2(1024, 1024)
const EXPECTED_PIVOT := Vector2(0.5, 0.92)
const EXPECTED_POSITION := Vector2(0.0, -430.08)
const POSITION_EPSILON := 0.001

class CandidateProfile:
	extends RefCounted
	var profile_id: StringName = &"c59_pack_a_candidate"
	func validate_against_standard() -> PackedStringArray:
		return PackedStringArray()

func _init() -> void:
	var failures := PackedStringArray()
	for path in CANDIDATES:
		if not ResourceLoader.exists(path):
			failures.append("resource_missing:%s" % path)
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			failures.append("texture_invalid:%s" % path)
			continue
		if texture.get_size() != EXPECTED_SIZE:
			failures.append("texture_size_invalid:%s:%s" % [path, texture.get_size()])
			continue

		var assembler := ModularFighterAssembler.new()
		get_root().add_child(assembler)
		var configure_failures := assembler.configure(CandidateProfile.new())
		if not configure_failures.is_empty():
			failures.append("assembler_configure_failed:%s:%s" % [path, ",".join(configure_failures)])
			assembler.queue_free()
			continue

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.position = Vector2(
			EXPECTED_SIZE.x * (0.5 - EXPECTED_PIVOT.x),
			EXPECTED_SIZE.y * (0.5 - EXPECTED_PIVOT.y)
		)
		sprite.z_index = 20
		if not assembler.attach_visual_module(&"face", sprite):
			failures.append("assembler_face_attach_failed:%s" % path)
			assembler.queue_free()
			continue
		if sprite.position.distance_to(EXPECTED_POSITION) > POSITION_EPSILON:
			failures.append("pivot_position_invalid:%s:%s expected=%s" % [path, sprite.position, EXPECTED_POSITION])
		if sprite.z_index != 20:
			failures.append("face_z_index_invalid:%s:%s" % [path, sprite.z_index])
		print("C59_1_GODOT_CANDIDATE=PASS path=%s size=%s pivot=%s position=%s" % [path, texture.get_size(), EXPECTED_PIVOT, sprite.position])
		assembler.queue_free()

	if not failures.is_empty():
		for failure in failures:
			push_error("C59_1_GODOT_CANDIDATE=BLOCKED %s" % failure)
		quit(2)
		return

	print("C59_1_GODOT_IMPORT_AND_SLOT_ATTACH=PASS candidates=3")
	print("OWNER_REVIEW=PENDING")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)
