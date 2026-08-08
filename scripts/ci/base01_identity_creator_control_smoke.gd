extends SceneTree

const BASE := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const SKINS := [
	"skin_tone_01_porcelain",
	"skin_tone_02_light_neutral",
	"skin_tone_03_warm",
	"skin_tone_04_olive",
	"skin_tone_05_tan",
	"skin_tone_06_brown",
	"skin_tone_07_deep",
	"skin_tone_08_ebony",
]
const FACES := ["face_01_balanced", "face_02_angular", "face_03_soft", "face_04_broad"]
const EYES := ["eyes_01_focused", "eyes_02_calm", "eyes_03_fierce", "eyes_04_narrow", "eyes_05_round", "eyes_06_heavy"]
const BROWS := ["brows_01_focused", "brows_02_neutral", "brows_03_arched", "brows_04_straight", "brows_05_heavy", "brows_06_sharp"]
const FACE_PLATE := "neutral_face_plate_v1"
const REVIEW_SKIN := "skin_tone_06_brown"

var _signal_count := 0
var _last_signal_slot: StringName = &""
var _last_signal_id: StringName = &""

func _init() -> void:
	call_deferred("_run")

func _on_identity_selected(slot: StringName, module_id: StringName) -> void:
	_signal_count += 1
	_last_signal_slot = slot
	_last_signal_id = module_id

func _run() -> void:
	var failures := PackedStringArray()
	var texture := load(BASE) as Texture2D
	if texture == null:
		_fail(["base_texture_missing"])
		return

	var profile := ModularFighterProfile.new()
	profile.profile_id = &"c62_4_identity_creator_profile"
	profile.set_skin_palette_id(StringName(REVIEW_SKIN))

	var assembler := ModularFighterAssembler.new()
	get_root().add_child(assembler)
	var configure_failures := assembler.configure(profile)
	if not configure_failures.is_empty():
		_fail(["assembler_configure:%s" % ",".join(configure_failures)])
		return

	var body := Sprite2D.new()
	body.texture = texture
	body.centered = true
	if not assembler.attach_visual_module(&"body_base", body):
		_fail(["body_attach_failed"])
		return

	var selector := ModularFighterIdentitySelector.new()
	get_root().add_child(selector)
	await process_frame
	await process_frame
	selector.identity_selected.connect(_on_identity_selected)

	var bind_failures := selector.bind(profile, assembler)
	if not bind_failures.is_empty():
		failures.append("bind:%s" % ",".join(bind_failures))

	if selector.option_count(&"skin") != 8:
		failures.append("skin_count:%d" % selector.option_count(&"skin"))
	if selector.option_count(&"face") != 4:
		failures.append("face_count:%d" % selector.option_count(&"face"))
	if selector.option_count(&"eyes") != 6:
		failures.append("eyes_count:%d" % selector.option_count(&"eyes"))
	if selector.option_count(&"brows") != 6:
		failures.append("brows_count:%d" % selector.option_count(&"brows"))

	if selector.selected_id(&"skin") != StringName(REVIEW_SKIN):
		failures.append("skin_default_sync")
	if selector.selected_id(&"face") != &"face_01_balanced":
		failures.append("face_default_sync")
	if selector.selected_id(&"eyes") != &"eyes_01_focused":
		failures.append("eyes_default_sync")
	if selector.selected_id(&"brows") != &"brows_01_focused":
		failures.append("brows_default_sync")
	if assembler.get_node_or_null("Module_face_plate") != null:
		failures.append("default_face_plate_should_be_absent")

	# Non-Warm profile skin must already apply to body and later propagate to
	# face and face_plate as the identity modules are changed.
	if not (body.material is ShaderMaterial):
		failures.append("review_skin_body_material_missing")

	var expected_signals := 0
	for face_id in FACES:
		var result := selector.select_identity(&"face", StringName(face_id))
		if not result.is_empty():
			failures.append("face_select:%s:%s" % [face_id, ",".join(result)])
			continue
		expected_signals += 1
		if profile.module_id(&"face") != StringName(face_id):
			failures.append("face_profile_desync:%s" % face_id)
		if assembler.active_identity_module_id(&"face") != StringName(face_id):
			failures.append("face_runtime_desync:%s" % face_id)
		var face_node := assembler.get_node_or_null("Module_face") as Sprite2D
		if face_node == null:
			failures.append("face_node_missing:%s" % face_id)
		elif not (face_node.material is ShaderMaterial):
			failures.append("face_skin_material_missing:%s" % face_id)
		var plate_node := assembler.get_node_or_null("Module_face_plate") as Sprite2D
		if face_id == "face_01_balanced":
			if plate_node != null:
				failures.append("default_face_plate_present")
		else:
			if plate_node == null:
				failures.append("variant_face_plate_missing:%s" % face_id)
			else:
				if assembler.active_identity_module_id(&"face_plate") != StringName(FACE_PLATE):
					failures.append("face_plate_id:%s" % face_id)
				if not (plate_node.material is ShaderMaterial):
					failures.append("face_plate_skin_material_missing:%s" % face_id)
				if face_node != null and not (plate_node.z_index < face_node.z_index):
					failures.append("face_plate_z_order:%s" % face_id)
		print("C62_4_FACE_OPTION=PASS id=%s plate=%s" % [face_id, "none" if face_id == "face_01_balanced" else FACE_PLATE])

	for eyes_id in EYES:
		var result := selector.select_identity(&"eyes", StringName(eyes_id))
		if not result.is_empty():
			failures.append("eyes_select:%s:%s" % [eyes_id, ",".join(result)])
			continue
		expected_signals += 1
		if profile.module_id(&"eyes") != StringName(eyes_id):
			failures.append("eyes_profile_desync:%s" % eyes_id)
		if assembler.active_identity_module_id(&"eyes") != StringName(eyes_id):
			failures.append("eyes_runtime_desync:%s" % eyes_id)
		print("C62_4_EYES_OPTION=PASS id=%s" % eyes_id)

	for brows_id in BROWS:
		var result := selector.select_identity(&"brows", StringName(brows_id))
		if not result.is_empty():
			failures.append("brows_select:%s:%s" % [brows_id, ",".join(result)])
			continue
		expected_signals += 1
		if profile.module_id(&"brows") != StringName(brows_id):
			failures.append("brows_profile_desync:%s" % brows_id)
		if assembler.active_identity_module_id(&"brows") != StringName(brows_id):
			failures.append("brows_runtime_desync:%s" % brows_id)
		print("C62_4_BROWS_OPTION=PASS id=%s" % brows_id)

	# Exercise all skin options through the embedded C62.3 selector to prove the
	# unified control delegates to the same skin runtime rather than a parallel path.
	for skin_id in SKINS:
		var result := selector.select_identity(&"skin", StringName(skin_id))
		if not result.is_empty():
			failures.append("skin_select:%s:%s" % [skin_id, ",".join(result)])
			continue
		expected_signals += 1
		if profile.skin_palette_id() != StringName(skin_id):
			failures.append("skin_profile_desync:%s" % skin_id)
		if assembler.active_skin_palette_id() != StringName(skin_id):
			failures.append("skin_runtime_desync:%s" % skin_id)
		print("C62_4_SKIN_OPTION=PASS id=%s" % skin_id)

	# Final deterministic identity for serialization and focus checks.
	for pair in [["skin", "skin_tone_07_deep"], ["face", "face_04_broad"], ["eyes", "eyes_03_fierce"], ["brows", "brows_06_sharp"]]:
		var result := selector.select_identity(StringName(pair[0]), StringName(pair[1]), false)
		if not result.is_empty():
			failures.append("final_state:%s:%s" % [pair[0], ",".join(result)])

	var face_node := assembler.get_node_or_null("Module_face") as Sprite2D
	var eyes_node := assembler.get_node_or_null("Module_eyes") as Sprite2D
	var brows_node := assembler.get_node_or_null("Module_brows") as Sprite2D
	var plate_node := assembler.get_node_or_null("Module_face_plate") as Sprite2D
	if plate_node == null or face_node == null or eyes_node == null or brows_node == null:
		failures.append("final_identity_nodes_missing")
	elif not (plate_node.z_index < face_node.z_index and face_node.z_index < eyes_node.z_index and eyes_node.z_index < brows_node.z_index):
		failures.append("final_z_order_invalid")

	var before_face := profile.module_id(&"face")
	var before_runtime_face := assembler.active_identity_module_id(&"face")
	var invalid_slot := selector.select_identity(&"weapon_main", &"face_02_angular")
	if not invalid_slot.has("identity_creator_slot_invalid:weapon_main"):
		failures.append("invalid_slot_not_blocked")
	var unknown_face := selector.select_identity(&"face", &"face_99_invalid")
	if not unknown_face.has("base01_identity_module_unknown:face:face_99_invalid"):
		failures.append("unknown_face_not_blocked")
	var mismatch := selector.select_identity(&"face", &"eyes_02_calm")
	if not mismatch.has("base01_identity_module_slot_mismatch:face:eyes_02_calm"):
		failures.append("slot_mismatch_not_blocked")
	if profile.module_id(&"face") != before_face or assembler.active_identity_module_id(&"face") != before_runtime_face:
		failures.append("invalid_selection_mutated_face")

	if not selector.show_category(&"face"):
		failures.append("face_category_not_available")
	selector.focus_selected()
	await process_frame
	var focus_owner := get_root().gui_get_focus_owner()
	if focus_owner == null:
		failures.append("focus_owner_missing")
	elif not focus_owner.has_meta("module_id"):
		failures.append("focus_owner_missing_module_id")
	elif StringName(String(focus_owner.get_meta("module_id"))) != &"face_04_broad":
		failures.append("focus_owner_wrong_face")

	if _signal_count != expected_signals:
		failures.append("signal_count:%d expected:%d" % [_signal_count, expected_signals])
	if _last_signal_slot != &"skin" or _last_signal_id != &"skin_tone_08_ebony":
		failures.append("last_signal:%s:%s" % [String(_last_signal_slot), String(_last_signal_id)])

	var runtime := profile.to_runtime_dictionary()
	if String(runtime.get("palette", {}).get("skin", "")) != "skin_tone_07_deep":
		failures.append("serialized_skin")
	var modules = runtime.get("modules", {})
	if String(modules.get("face", "")) != "face_04_broad": failures.append("serialized_face")
	if String(modules.get("eyes", "")) != "eyes_03_fierce": failures.append("serialized_eyes")
	if String(modules.get("brows", "")) != "brows_06_sharp": failures.append("serialized_brows")

	if not failures.is_empty():
		_fail(failures)
		return
	print("C62_4_IDENTITY_CREATOR_CONTROL=PASS skin=8 face=4 eyes=6 brows=6")
	print("C62_4_FACE_PLATE_POLICY=PASS default=none variants=plate")
	print("C62_4_PROFILE_ASSEMBLER_SYNC=PASS")
	print("C62_4_INVALID_SELECTIONS=BLOCKED")
	print("C62_4_KEYBOARD_GAMEPAD_FOCUS=PASS")
	print("C62_4_SERIALIZATION=PASS")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _fail(failures: PackedStringArray) -> void:
	for failure in failures:
		push_error("C62_4_IDENTITY_CREATOR_CONTROL=BLOCKED %s" % failure)
	quit(2)
