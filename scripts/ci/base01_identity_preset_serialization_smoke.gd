extends SceneTree

const USER_PRESET_ID := "c62_5_roundtrip_identity"
const LIAN_WU := "res://config/fighter-presets/preset_lian_wu.json"
const TRAINING_RIVAL := "res://config/fighter-presets/preset_training_rival.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := PackedStringArray()
	ModularFighterPresetStore.delete_user_preset(StringName(USER_PRESET_ID))

	var profile := ModularFighterProfile.new()
	profile.profile_id = &"creator_identity_roundtrip"
	profile.display_name = "Creator Identity Roundtrip"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.combat_loadout_id = &"combat_creator_test"
	profile.set_skin_palette_id(&"skin_tone_07_deep")
	failures.append_array(profile.set_base01_identity_module(&"face", &"face_04_broad"))
	failures.append_array(profile.set_base01_identity_module(&"eyes", &"eyes_03_fierce"))
	failures.append_array(profile.set_base01_identity_module(&"brows", &"brows_06_sharp"))
	if not failures.is_empty():
		_fail(failures)
		return

	var encoded := ModularFighterPresetStore.encode(profile, StringName(USER_PRESET_ID))
	if String(encoded.get("schema", "")) != ModularFighterPresetStore.SCHEMA_V2:
		failures.append("encoded_schema")
	if String(encoded.get("signature", "")) != "Tehkné Solutions":
		failures.append("encoded_signature")
	if String(encoded.get("preset_id", "")) != USER_PRESET_ID:
		failures.append("encoded_preset_id")
	if String(encoded.get("palette", {}).get("skin", "")) != "skin_tone_07_deep":
		failures.append("encoded_skin")
	var encoded_modules = encoded.get("modules", {})
	if typeof(encoded_modules) != TYPE_DICTIONARY:
		failures.append("encoded_modules_type")
	else:
		if String(encoded_modules.get("face", "")) != "face_04_broad": failures.append("encoded_face")
		if String(encoded_modules.get("eyes", "")) != "eyes_03_fierce": failures.append("encoded_eyes")
		if String(encoded_modules.get("brows", "")) != "brows_06_sharp": failures.append("encoded_brows")

	var decoded := ModularFighterPresetStore.decode(encoded)
	if not bool(decoded.get("ok", false)):
		failures.append("memory_decode:%s" % ",".join(decoded.get("failures", PackedStringArray())))
	else:
		_validate_identity(decoded.get("profile"), "memory", failures)

	var save_failures := ModularFighterPresetStore.save_user_preset(profile, StringName(USER_PRESET_ID))
	if not save_failures.is_empty():
		failures.append("save:%s" % ",".join(save_failures))
	var expected_path := ModularFighterPresetStore.user_preset_path(StringName(USER_PRESET_ID))
	if not FileAccess.file_exists(expected_path):
		failures.append("saved_file_missing")

	var loaded := ModularFighterPresetStore.load_user_preset(StringName(USER_PRESET_ID))
	if not bool(loaded.get("ok", false)):
		failures.append("file_load:%s" % ",".join(loaded.get("failures", PackedStringArray())))
	else:
		_validate_identity(loaded.get("profile"), "file", failures)

	var listed := ModularFighterPresetStore.list_user_preset_ids()
	if not listed.has(USER_PRESET_ID):
		failures.append("list_missing_roundtrip")

	for legacy_path in [LIAN_WU, TRAINING_RIVAL]:
		var legacy := ModularFighterPresetStore.load_path(legacy_path)
		if not bool(legacy.get("ok", false)):
			failures.append("legacy_decode:%s:%s" % [legacy_path.get_file(), ",".join(legacy.get("failures", PackedStringArray()))])
			continue
		var legacy_profile = legacy.get("profile")
		if not (legacy_profile is ModularFighterProfile):
			failures.append("legacy_profile_type:%s" % legacy_path.get_file())
			continue
		if legacy_profile.profile_id == &"":
			failures.append("legacy_profile_id:%s" % legacy_path.get_file())
		print("C62_5_LEGACY_V1=PASS file=%s profile=%s" % [legacy_path.get_file(), String(legacy_profile.profile_id)])

	var bad_schema := encoded.duplicate(true)
	bad_schema["schema"] = "tehkne/unsupported/v99"
	var bad_schema_result := ModularFighterPresetStore.decode(bad_schema)
	if bool(bad_schema_result.get("ok", true)):
		failures.append("unsupported_schema_not_blocked")

	var bad_signature := encoded.duplicate(true)
	bad_signature["signature"] = "Other"
	var bad_signature_result := ModularFighterPresetStore.decode(bad_signature)
	if bool(bad_signature_result.get("ok", true)):
		failures.append("invalid_signature_not_blocked")

	var bad_skin := encoded.duplicate(true)
	bad_skin["palette"] = {"skin": "skin_tone_99_invalid"}
	var bad_skin_result := ModularFighterPresetStore.decode(bad_skin)
	if bool(bad_skin_result.get("ok", true)):
		failures.append("invalid_skin_not_blocked")

	for bad_id in ["../escape", "bad/id", "", " space"]:
		var bad_save := ModularFighterPresetStore.save_user_preset(profile, StringName(bad_id))
		if bad_save.is_empty():
			failures.append("unsafe_id_not_blocked:%s" % bad_id)

	var delete_failures := ModularFighterPresetStore.delete_user_preset(StringName(USER_PRESET_ID))
	if not delete_failures.is_empty():
		failures.append("delete:%s" % ",".join(delete_failures))
	if FileAccess.file_exists(expected_path):
		failures.append("delete_file_still_exists")

	if not failures.is_empty():
		_fail(failures)
		return
	print("C62_5_PRESET_V2_ROUNDTRIP=PASS skin=deep face=broad eyes=fierce brows=sharp")
	print("C62_5_USER_PERSISTENCE=PASS save=load=list=delete")
	print("C62_5_V1_COMPATIBILITY=PASS presets=2")
	print("C62_5_INVALID_PRESET=BLOCKED schema=signature=skin=path")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _validate_identity(value, label: String, failures: PackedStringArray) -> void:
	if not (value is ModularFighterProfile):
		failures.append("%s_profile_type" % label)
		return
	var restored := value as ModularFighterProfile
	if restored.profile_id != &"creator_identity_roundtrip": failures.append("%s_profile_id" % label)
	if restored.display_name != "Creator Identity Roundtrip": failures.append("%s_display_name" % label)
	if restored.skin_palette_id() != &"skin_tone_07_deep": failures.append("%s_skin" % label)
	if restored.module_id(&"face") != &"face_04_broad": failures.append("%s_face" % label)
	if restored.module_id(&"eyes") != &"eyes_03_fierce": failures.append("%s_eyes" % label)
	if restored.module_id(&"brows") != &"brows_06_sharp": failures.append("%s_brows" % label)
	if restored.combat_loadout_id != &"combat_creator_test": failures.append("%s_combat" % label)

func _fail(failures: PackedStringArray) -> void:
	ModularFighterPresetStore.delete_user_preset(StringName(USER_PRESET_ID))
	for failure in failures:
		push_error("C62_5_IDENTITY_PRESET_SERIALIZATION=BLOCKED %s" % failure)
	quit(2)
