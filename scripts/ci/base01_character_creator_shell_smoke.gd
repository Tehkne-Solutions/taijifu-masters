extends SceneTree

const SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const PRESET_ID := "c62_6_creator_shell_roundtrip"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := PackedStringArray()
	ModularFighterPresetStore.delete_user_preset(StringName(PRESET_ID))
	var packed := load(SCENE) as PackedScene
	if packed == null:
		_fail(["scene_missing"])
		return
	var shell := packed.instantiate() as ModularFighterCreatorShell
	if shell == null:
		_fail(["scene_root_type"])
		return
	get_root().add_child(shell)
	await process_frame
	await process_frame

	var signature := shell.flow_signature()
	if String(signature.get("scene", "")) != "BASE01_CHARACTER_CREATOR_SHELL": failures.append("flow_scene")
	if int(signature.get("identity_options", 0)) != 24: failures.append("flow_options")
	if not bool(signature.get("live_preview", false)): failures.append("flow_preview")
	if String(signature.get("preset_schema", "")) != ModularFighterPresetStore.SCHEMA_V2: failures.append("flow_schema")
	if String(signature.get("signature", "")) != "Tehkné Solutions": failures.append("flow_signature")

	var selector := shell.identity_selector()
	if selector == null:
		failures.append("selector_missing")
	else:
		if selector.option_count(&"skin") != 8: failures.append("skin_count")
		if selector.option_count(&"face") != 4: failures.append("face_count")
		if selector.option_count(&"eyes") != 6: failures.append("eyes_count")
		if selector.option_count(&"brows") != 6: failures.append("brows_count")

	var profile := shell.current_profile()
	if profile == null:
		failures.append("profile_missing")
	else:
		if profile.skin_palette_id() != &"skin_tone_03_warm": failures.append("default_skin")
		if profile.module_id(&"face") != &"face_01_balanced": failures.append("default_face")
		if profile.module_id(&"eyes") != &"eyes_01_focused": failures.append("default_eyes")
		if profile.module_id(&"brows") != &"brows_01_focused": failures.append("default_brows")

	var assembler := shell.current_assembler()
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("assembler_not_ready")
	elif assembler.get_node_or_null("Module_body_base") == null:
		failures.append("preview_body_missing")

	for pair in [
		["skin", "skin_tone_07_deep"],
		["face", "face_04_broad"],
		["eyes", "eyes_03_fierce"],
		["brows", "brows_06_sharp"],
	]:
		var result := shell.set_identity(StringName(pair[0]), StringName(pair[1]))
		if not result.is_empty():
			failures.append("select_%s:%s" % [pair[0], ",".join(result)])

	shell.set_display_name("Mestre C62")
	shell.set_preset_id(PRESET_ID)
	var save_failures := shell.save_current_preset()
	if not save_failures.is_empty():
		failures.append("save:%s" % ",".join(save_failures))
	if not ModularFighterPresetStore.list_user_preset_ids().has(PRESET_ID):
		failures.append("saved_not_listed")

	# Mutate every creator category after saving.
	for pair in [
		["skin", "skin_tone_01_porcelain"],
		["face", "face_01_balanced"],
		["eyes", "eyes_06_heavy"],
		["brows", "brows_02_neutral"],
	]:
		var result := shell.set_identity(StringName(pair[0]), StringName(pair[1]))
		if not result.is_empty(): failures.append("mutate_%s" % pair[0])
	shell.set_display_name("Alterado")

	var load_failures := shell.load_user_preset(StringName(PRESET_ID))
	if not load_failures.is_empty():
		failures.append("load:%s" % ",".join(load_failures))
	profile = shell.current_profile()
	assembler = shell.current_assembler()
	if profile == null or assembler == null:
		failures.append("roundtrip_runtime_missing")
	else:
		if profile.display_name != "Mestre C62": failures.append("roundtrip_name")
		if profile.skin_palette_id() != &"skin_tone_07_deep": failures.append("roundtrip_skin")
		if profile.module_id(&"face") != &"face_04_broad": failures.append("roundtrip_face")
		if profile.module_id(&"eyes") != &"eyes_03_fierce": failures.append("roundtrip_eyes")
		if profile.module_id(&"brows") != &"brows_06_sharp": failures.append("roundtrip_brows")
		if assembler.active_skin_palette_id() != &"skin_tone_07_deep": failures.append("runtime_skin")
		if assembler.active_identity_module_id(&"face") != &"face_04_broad": failures.append("runtime_face")
		if assembler.active_identity_module_id(&"eyes") != &"eyes_03_fierce": failures.append("runtime_eyes")
		if assembler.active_identity_module_id(&"brows") != &"brows_06_sharp": failures.append("runtime_brows")
		if assembler.active_identity_module_id(&"face_plate") != &"neutral_face_plate_v1": failures.append("runtime_face_plate")

	var missing := shell.load_user_preset(&"c62_6_missing_preset")
	if missing.is_empty():
		failures.append("missing_preset_not_blocked")

	var delete_failures := ModularFighterPresetStore.delete_user_preset(StringName(PRESET_ID))
	if not delete_failures.is_empty(): failures.append("cleanup_delete")
	if ModularFighterPresetStore.list_user_preset_ids().has(PRESET_ID): failures.append("cleanup_list")

	if not failures.is_empty():
		_fail(failures)
		return
	print("C62_6_CREATOR_SHELL=PASS options=24 preview=live")
	print("C62_6_CREATOR_PRESET_ROUNDTRIP=PASS name=skin=face=eyes=brows")
	print("C62_6_CREATOR_RUNTIME_SYNC=PASS face_plate=auto")
	print("C62_6_MISSING_PRESET=BLOCKED")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _fail(failures: Array) -> void:
	ModularFighterPresetStore.delete_user_preset(StringName(PRESET_ID))
	for failure in failures:
		push_error("C62_6_CHARACTER_CREATOR_SHELL=BLOCKED %s" % String(failure))
	quit(2)
