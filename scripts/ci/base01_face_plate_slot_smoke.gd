extends SceneTree

class ContractProfile:
	extends RefCounted
	var profile_id: StringName = &"c59_3_face_plate_contract"
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

func _init() -> void:
	var failures := PackedStringArray()
	var standard := _load_json("res://config/modular-fighter-standard-v1.json")
	var slots = standard.get("slots", [])
	var internal_slots = standard.get("internal_slots", [])
	var creator_slots = standard.get("creator_v1_editable_slots", [])
	if typeof(slots) != TYPE_ARRAY or not slots.has("face_plate"):
		failures.append("face_plate_missing_from_slots")
	if typeof(internal_slots) != TYPE_ARRAY or not internal_slots.has("face_plate"):
		failures.append("face_plate_missing_from_internal_slots")
	if typeof(creator_slots) != TYPE_ARRAY or creator_slots.has("face_plate"):
		failures.append("face_plate_must_not_be_creator_editable")

	var assembler := ModularFighterAssembler.new()
	get_root().add_child(assembler)
	var config_failures := assembler.configure(ContractProfile.new())
	if not config_failures.is_empty():
		failures.append("assembler_configure_failed:%s" % ",".join(config_failures))
	else:
		if assembler._slot_z_index("face_plate") != 15:
			failures.append("face_plate_z_invalid:%s" % assembler._slot_z_index("face_plate"))
		if assembler._slot_z_index("face") != 20:
			failures.append("face_z_invalid:%s" % assembler._slot_z_index("face"))
		if assembler._slot_z_index("eyes") != 30 or assembler._slot_z_index("brows") != 40:
			failures.append("identity_layer_order_regressed")

		var plate := Sprite2D.new()
		plate.z_index = 15
		if not assembler.attach_visual_module(&"face_plate", plate):
			failures.append("face_plate_attach_failed")
		var face := Sprite2D.new()
		face.z_index = 20
		if not assembler.attach_visual_module(&"face", face):
			failures.append("face_attach_failed")
		if assembler.get_node_or_null("Module_face_plate") == null:
			failures.append("face_plate_node_missing")
		if assembler.get_node_or_null("Module_face") == null:
			failures.append("face_node_missing")

	# Default identity must remain plate-free for exact approved reconstruction.
	var default_assembler := ModularFighterAssembler.new()
	get_root().add_child(default_assembler)
	var default_config := default_assembler.configure(ContractProfile.new())
	if not default_config.is_empty():
		failures.append("default_config_failed:%s" % ",".join(default_config))
	else:
		var default_failures := default_assembler.assemble_base01_default_identity()
		if not default_failures.is_empty():
			failures.append("default_identity_failed:%s" % ",".join(default_failures))
		if default_assembler.get_node_or_null("Module_face_plate") != null:
			failures.append("default_identity_must_not_attach_face_plate")
		for required in ["Module_face", "Module_eyes", "Module_brows"]:
			if default_assembler.get_node_or_null(required) == null:
				failures.append("default_identity_module_missing:%s" % required)

	if not failures.is_empty():
		for failure in failures:
			push_error("C59_3_FACE_PLATE_SLOT=BLOCKED %s" % failure)
		quit(2)
		return

	print("C59_3_FACE_PLATE_SLOT=PASS")
	print("FACE_PLATE_INTERNAL_SLOT=PASS")
	print("FACE_PLATE_Z_INDEX=15")
	print("DEFAULT_IDENTITY_PLATE_FREE=PASS")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)
